///|
pub(all) suberror WasmCompileError {
  InvalidBytecode(@bytecode.BytecodeVerificationError)
  UnsupportedInstruction(function_id~ : Int, instruction~ : String)
  InvalidBlockTarget(function_id~ : Int, target~ : Int)
  InvalidEdgeArity(
    function_id~ : Int,
    target~ : Int,
    expected~ : Int,
    actual~ : Int
  )
  MissingByteSequenceLayout
  ValidationFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub fn compile(
  image : @bytecode.BytecodeImage,
) -> Result[@wasm_types.Module, WasmCompileError] {
  match compile_observed(image) {
    Ok(observed) => Ok(observed.module_)
    Err(error) => Err(error)
  }
}

///|
pub fn compile_observed(
  image : @bytecode.BytecodeImage,
) -> Result[WasmCompileObservation, WasmCompileError] {
  Ok(compile_or_raise(image)) catch {
    error => Err(error)
  }
}

///|
fn compile_or_raise(
  image : @bytecode.BytecodeImage,
) -> WasmCompileObservation raise WasmCompileError {
  let verified = match @bytecode.verify_bytecode_image_for_execution(image) {
    Ok(verified) => verified
    Err(error) => raise InvalidBytecode(error)
  }
  let image = verified.image
  let wasm_module = @wasm_types.Module::empty()
  let emitter = WasmFunctionEmitter::new(wasm_module)
  let imports = image.functions.filter_map(fn(entry) {
    match entry {
      RuntimeImport(import_) => Some(import_)
      BytecodeBody(_) => None
    }
  })
  let host_objects_enabled = imports.any(runtime_import_uses_host_objects)
  if host_objects_enabled && !image.layouts.any(layout => layout is Reference) {
    raise ValidationFailure(
      detail="Opaque runtime imports require a Reference layout",
    )
  }
  let internal_import_plan = plan_internal_runtime_imports(
    image, host_objects_enabled,
  )
  let internal_import_count = internal_import_plan.entries.length()
  let import_count = internal_import_count + imports.length()
  let callable_table = plan_callable_table(image)
  let runtime_functions = runtime_function_indices(
    import_count + image.functions.length(),
  )
  let helper_functions = helper_function_indices(
    callable_table.functions.length(),
    image.object_shapes.length(),
    runtime_functions.allocate,
  )
  let static_image = build_static_image(
    image,
    verified.global_lifecycle,
    helper_functions,
    import_count,
    host_objects_enabled,
    callable_table.table_indices,
  )
  append_internal_runtime_imports(emitter, internal_import_plan)
  let physical_import_indices : Array[Int?] = Array::make(
    image.functions.length(),
    None,
  )
  for index, entry in image.functions {
    if entry is RuntimeImport(import_) {
      physical_import_indices[index] = Some(
        append_physical_runtime_import(emitter, import_, { value: index + 1 }),
      )
    }
  }
  for index, entry in image.functions {
    match entry {
      BytecodeBody(body) => {
        let abi = body.callable_abi().unwrap()
        let type_index = intern_function_type(
          wasm_module,
          wasm_callable_parameters(abi),
          wasm_function_results(abi.result),
        )
        ignore(
          emitter.append_defined(
            type_index,
            compile_body(
              index + 1,
              body,
              wasm_module,
              static_image,
              runtime_functions,
              internal_import_plan,
            ),
            BytecodeFunction(function={ value: index + 1 }),
          ),
        )
      }
      RuntimeImport(import_) =>
        append_runtime_import_adapter(
          emitter,
          import_,
          { value: index + 1 },
          import_.callable_abi(),
          physical_import_indices[index].unwrap(),
          runtime_functions,
        )
    }
  }
  append_runtime_functions(emitter, static_image, runtime_functions)
  append_helper_functions(
    emitter,
    static_image,
    runtime_functions,
    helper_functions,
    internal_import_plan.index(HostObjectRelease),
  )
  let cleanup_function = if verified.global_lifecycle.owned_roots.is_empty() {
    None
  } else {
    Some(
      append_global_cleanup_function(emitter, static_image, runtime_functions),
    )
  }
  let fatal_tag_type = intern_function_type(wasm_module, [], [])
  wasm_module.tags.push({ type_idx: fatal_tag_type })
  let entry_wrapper_type = intern_function_type(wasm_module, [], [])
  let entry_wrapper_index = emitter.append_defined(
    entry_wrapper_type,
    {
      locals: [],
      body: compile_entry_lifecycle(image, static_image, cleanup_function),
    },
    EntryWrapper,
  )
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
  let table_size = callable_table.functions.length() +
    helper_functions.count +
    1
  wasm_module.tables.push({
    type_: {
      elem_type: FuncRef,
      limits: { min: table_size.to_int64(), max: Some(table_size.to_int64()) },
      is_table64: false,
    },
    init: Some([RefNull(FuncRef)]),
  })
  let element_initializers : Array[Array[@wasm_types.Instruction]] = []
  for function in callable_table.functions {
    element_initializers.push([RefFunc(import_count + function.value - 1)])
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
    desc: Func(runtime_functions.byte_sequence_new),
  })
  wasm_module.exports.push({
    name: "lane.runtime.host_object.new",
    desc: Func(runtime_functions.host_object_new),
  })
  { module_: wasm_module, functions: emitter.functions }
}

///|
fn wasm_callable_parameters(
  abi : @bytecode.CallableAbi,
) -> Array[@wasm_types.ValueType] {
  let parameters : Array[@wasm_types.ValueType] = [I32]
  for witness in abi.witnesses {
    parameters.push(wasm_representation(witness.representation))
  }
  for parameter in abi.parameters {
    parameters.push(wasm_representation(parameter.representation))
  }
  parameters
}

///|
fn wasm_function_results(
  result : @bytecode.ResultAbi,
) -> Array[@wasm_types.ValueType] {
  match result {
    Unit => []
    Value(representation, _, _) => [wasm_representation(representation)]
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
    F32 => F32
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
  internal_import_plan : InternalRuntimeImportPlan,
) -> @wasm_types.FunctionCode raise WasmCompileError {
  let parameter_count = 1 +
    body.inputs.witnesses.length() +
    body.inputs.user_parameters.length()
  let uses_cfg = body.blocks.length() != 1 ||
    terminator_transfers_control(body.blocks[0].terminator)
  let use_balanced_dispatcher = uses_cfg &&
    body.blocks.length() > maximum_linear_control_blocks
  let structured = if uses_cfg && !use_balanced_dispatcher {
    structure_cfg(body)
  } else {
    None
  }
  let use_dispatcher = uses_cfg && structured is None
  let locals = plan_function_locals(
    body, parameter_count, uses_cfg, use_dispatcher,
  )
  let context : FunctionCompilationContext = {
    function_id,
    locals,
    body,
    wasm_module,
    static_image,
    runtime_functions,
    internal_import_plan,
  }
  let instructions : Array[@wasm_types.Instruction] = []
  let needs_frame_cleanup = body.slots.any(fn(slot) {
    !(slot.cleanup is Trivial)
  })
  let mut parameter_index = 1
  if body.inputs.environment is Some(slot) {
    instructions.push(LocalGet(0))
    instructions.push(LocalSet(locals.slot_local(slot)))
    instructions.append(context.mark_slot_live(slot))
  }
  for slot in body.inputs.witnesses {
    instructions.push(LocalGet(parameter_index))
    instructions.push(LocalSet(locals.slot_local(slot)))
    instructions.append(context.mark_slot_live(slot))
    parameter_index += 1
  }
  for slot in body.inputs.user_parameters {
    instructions.push(LocalGet(parameter_index))
    instructions.push(LocalSet(locals.slot_local(slot)))
    instructions.append(context.mark_slot_live(slot))
    parameter_index += 1
  }
  let guarded_body : Array[@wasm_types.Instruction] = call_depth_prologue()
  if structured is Some(sequence) {
    guarded_body.append(compile_structured_cfg(context, sequence))
  } else if use_balanced_dispatcher {
    guarded_body.push(compile_balanced_dispatcher(context))
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
  if needs_frame_cleanup {
    instructions.append(
      compile_frame_cleanup(locals, body.slots, wasm_module, runtime_functions),
    )
  }
  instructions.append([
    GlobalGet(call_depth_global_index),
    I32Const(1),
    I32Sub,
    GlobalSet(call_depth_global_index),
    Throw(0),
  ])
  { locals: locals.locals, body: instructions }
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
