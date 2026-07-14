///|
pub(all) suberror WasmCompileError {
  UnsupportedRuntimeImport(function_id~ : Int)
  UnsupportedInstruction(function_id~ : Int, instruction~ : String)
  InvalidBlockTarget(function_id~ : Int, target~ : Int)
  InvalidEdgeArity(
    function_id~ : Int,
    target~ : Int,
    expected~ : Int,
    actual~ : Int
  )
  MissingStringLayout
  ValidationFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub fn compile(
  image : @bytecode.BytecodeImage,
) -> Result[@wasm_types.Module, WasmCompileError] {
  Ok(compile_or_raise(image, [])) catch {
    error => Err(error)
  }
}

///|
fn compile_or_raise(
  image : @bytecode.BytecodeImage,
  bindings : Array[@loisvm_runtime.RuntimeBinding],
) -> @wasm_types.Module raise WasmCompileError {
  let wasm_module = @wasm_types.Module::empty()
  let import_count = bindings.length()
  let runtime_functions = runtime_function_indices(
    import_count + image.functions.length(),
  )
  let helper_functions = helper_function_indices(
    image.functions.length(),
    image.object_shapes.length(),
    runtime_functions.allocate,
  )
  let static_image = build_static_image(image, helper_functions, import_count)
  for binding in bindings {
    append_physical_runtime_import(wasm_module, binding)
  }
  let mut import_index = 0
  for index, entry in image.functions {
    match entry {
      BytecodeBody(body) => {
        let type_index = intern_function_type(
          wasm_module,
          wasm_function_parameters(body),
          wasm_function_results(body.result),
        )
        wasm_module.funcs.push(type_index)
        wasm_module.codes.push(
          compile_body(
            index + 1,
            body,
            wasm_module,
            static_image,
            runtime_functions,
          ),
        )
      }
      RuntimeImport(_) => {
        if import_index >= bindings.length() {
          raise UnsupportedRuntimeImport(function_id=index + 1)
        }
        append_runtime_import_adapter(
          wasm_module,
          bindings[import_index],
          import_index,
          runtime_functions,
        )
        import_index += 1
      }
    }
  }
  append_runtime_functions(wasm_module, static_image, runtime_functions)
  append_helper_functions(
    wasm_module, static_image, runtime_functions, helper_functions,
  )
  let fatal_tag_type = intern_function_type(wasm_module, [], [])
  wasm_module.tags.push({ type_idx: fatal_tag_type })
  let entry_wrapper_type = intern_function_type(wasm_module, [], [])
  wasm_module.funcs.push(entry_wrapper_type)
  wasm_module.codes.push({
    locals: [],
    body: [
      I32Const(0),
      Call(static_image.wasm_function_offset + image.entry.value - 1),
    ],
  })
  let entry_wrapper_index = import_count + wasm_module.funcs.length() - 1
  let initial_pages = (static_image.heap_base + 65535) / 65536
  wasm_module.memories.push({
    limits: { min: initial_pages.to_int64(), max: None },
    is_memory64: false,
    page_size_log2: 16,
  })
  append_runtime_globals(wasm_module, static_image)
  wasm_module.datas.push({
    memory_idx: 0,
    offset: [I32Const(0)],
    init: static_image.bytes,
  })
  let table_size = image.functions.length() + helper_functions.count + 1
  wasm_module.tables.push({
    type_: {
      elem_type: FuncRef,
      limits: { min: table_size.to_int64(), max: Some(table_size.to_int64()) },
      is_table64: false,
    },
    init: Some([RefNull(FuncRef)]),
  })
  let element_initializers : Array[Array[@wasm_types.Instruction]] = []
  for index in 0..<image.functions.length() {
    element_initializers.push([RefFunc(import_count + index)])
  }
  for wasm_index in helper_functions.wasm_indices() {
    element_initializers.push([RefFunc(wasm_index)])
  }
  wasm_module.elems.push({
    mode: Active(0, [I32Const(1)]),
    type_: FuncRef,
    init: element_initializers,
  })
  wasm_module.exports.push({
    name: "lane.entry",
    desc: Func(entry_wrapper_index),
  })
  wasm_module.exports.push({ name: "lane.memory", desc: Memory(0) })
  wasm_module.exports.push({
    name: "lane.runtime.string.new",
    desc: Func(runtime_functions.string_new),
  })
  @validator.validate_module(wasm_module) catch {
    error =>
      raise ValidationFailure(detail=@validator.format_validation_error(error))
  }
  wasm_module
}

///|
fn wasm_function_parameters(
  body : @bytecode.FunctionBody,
) -> Array[@wasm_types.ValueType] {
  let parameters : Array[@wasm_types.ValueType] = [I32]
  for slot in body.inputs.witnesses {
    parameters.push(wasm_representation(body.slots[slot.value].representation))
  }
  for slot in body.inputs.user_parameters {
    parameters.push(wasm_representation(body.slots[slot.value].representation))
  }
  parameters
}

///|
fn wasm_function_results(
  result : @bytecode.ResultRepresentation,
) -> Array[@wasm_types.ValueType] {
  match result {
    Unit => []
    I32 => [I32]
    I64 => [I64]
    F64 => [F64]
  }
}

///|
fn wasm_representation(
  representation : @bytecode.Representation,
) -> @wasm_types.ValueType {
  match representation {
    I32 => I32
    I64 => I64
    F64 => F64
  }
}

///|
fn intern_function_type(
  wasm_module : @wasm_types.Module,
  parameters : Array[@wasm_types.ValueType],
  results : Array[@wasm_types.ValueType],
) -> Int {
  let candidate = @wasm_types.SubType::func(parameters, results)
  for index, existing in wasm_module.types {
    if existing == candidate {
      return index
    }
  }
  let index = wasm_module.types.length()
  wasm_module.types.push(candidate)
  index
}

///|
fn compile_body(
  function_id : Int,
  body : @bytecode.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
) -> @wasm_types.FunctionCode raise WasmCompileError {
  let parameter_count = 1 +
    body.inputs.witnesses.length() +
    body.inputs.user_parameters.length()
  let uses_cfg = body.blocks.length() != 1 ||
    terminator_transfers_control(body.blocks[0].terminator)
  let structured = if uses_cfg { structure_cfg(body) } else { None }
  let use_dispatcher = uses_cfg && structured is None
  let live_base = frame_live_base(
    parameter_count,
    body.slots.length(),
    uses_cfg,
    use_dispatcher,
  )
  let context : FunctionCompilationContext = {
    function_id,
    parameter_count,
    live_base,
    body,
    wasm_module,
    static_image,
    runtime_functions,
  }
  let instructions : Array[@wasm_types.Instruction] = []
  let mut parameter_index = 1
  if body.inputs.environment is Some(slot) {
    instructions.push(LocalGet(0))
    instructions.push(LocalSet(parameter_count + slot.value))
    instructions.append(context.mark_slot_live(slot))
  }
  for slot in body.inputs.witnesses {
    instructions.push(LocalGet(parameter_index))
    instructions.push(LocalSet(parameter_count + slot.value))
    instructions.append(context.mark_slot_live(slot))
    parameter_index += 1
  }
  for slot in body.inputs.user_parameters {
    instructions.push(LocalGet(parameter_index))
    instructions.push(LocalSet(parameter_count + slot.value))
    instructions.append(context.mark_slot_live(slot))
    parameter_index += 1
  }
  let guarded_body : Array[@wasm_types.Instruction] = call_depth_prologue()
  if structured is Some(sequence) {
    guarded_body.append(compile_structured_cfg(context, sequence))
  } else if use_dispatcher {
    guarded_body.push(compile_dispatcher(context))
  } else {
    for instruction in body.blocks[0].instructions {
      guarded_body.append(context.compile_instruction(instruction))
    }
    guarded_body.append(context.compile_terminator(body.blocks[0].terminator))
  }
  instructions.push(
    Block(Empty, [TryTable(Empty, [Catch(0, 0)], guarded_body), Unreachable]),
  )
  instructions.append(
    compile_frame_cleanup(
      parameter_count,
      live_base,
      body.slots,
      wasm_module,
      runtime_functions,
    ),
  )
  instructions.append([
    GlobalGet(call_depth_global_index),
    I32Const(1),
    I32Sub,
    GlobalSet(call_depth_global_index),
    Throw(0),
  ])
  let locals = body.slots.map(fn(slot) {
    wasm_representation(slot.representation)
  })
  if uses_cfg {
    locals.append(
      body.slots.map(fn(slot) { wasm_representation(slot.representation) }),
    )
  }
  if use_dispatcher {
    locals.push(I32)
  }
  for _ in body.slots {
    locals.push(I32)
  }
  { locals, body: instructions }
}

///|
fn call_depth_prologue() -> Array[@wasm_types.Instruction] {
  [
    GlobalGet(call_depth_global_index),
    I32Const(1),
    I32Add,
    GlobalSet(call_depth_global_index),
    GlobalGet(call_depth_global_index),
    GlobalGet(max_call_depth_global_index),
    I32GtU,
    If(Empty, [I32Const(1), GlobalSet(failure_code_global_index), Throw(0)], []),
  ]
}

///|
fn slot_local(parameter_count : Int, slot : @bytecode.SlotId) -> Int {
  parameter_count + slot.value
}

///|
fn frame_live_base(
  parameter_count : Int,
  slot_count : Int,
  uses_transfer_locals : Bool,
  use_dispatcher : Bool,
) -> Int {
  let transfer_local_count = if uses_transfer_locals { slot_count } else { 0 }
  let dispatcher_local_count = if use_dispatcher { 1 } else { 0 }
  parameter_count + slot_count + transfer_local_count + dispatcher_local_count
}

///|
fn live_local(live_base : Int, slot : @bytecode.SlotId) -> Int {
  live_base + slot.value
}

///|
fn mark_slot_live(
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  slot : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  if slots[slot.value].cleanup is Trivial {
    []
  } else {
    [I32Const(1), LocalSet(live_local(live_base, slot))]
  }
}

///|
fn mark_slot_dead(
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  slot : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  if slots[slot.value].cleanup is Trivial {
    []
  } else {
    [I32Const(0), LocalSet(live_local(live_base, slot))]
  }
}
