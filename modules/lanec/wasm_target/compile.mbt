///|
pub(all) suberror WasmCompileError {
  InvalidPhysicalProgram(@physical.PhysicalProgramVerificationError)
  UnsupportedInstruction(function_id~ : Int, instruction~ : String)
  InvalidBlockTarget(function_id~ : Int, target~ : Int)
  InvalidEdgeArity(
    function_id~ : Int,
    target~ : Int,
    expected~ : Int,
    actual~ : Int
  )
  MissingByteSequenceLayout
  InvalidFunctionCatalog(detail~ : String)
  ValidationFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub fn compile(
  image : @physical.PhysicalProgram,
) -> Result[@wasm_types.Module, WasmCompileError] {
  Ok(compile_or_raise(image, None)) catch {
    error => Err(error)
  }
}

///|
pub fn compile_observed(
  image : @physical.PhysicalProgram,
) -> Result[WasmCompileObservation, WasmCompileError] {
  Ok(compile_observed_or_raise(image)) catch {
    error => Err(error)
  }
}

///|
fn compile_observed_or_raise(
  image : @physical.PhysicalProgram,
) -> WasmCompileObservation raise WasmCompileError {
  let mut functions = []
  let mut scale : WasmModuleScale? = None
  let module_ = compile_or_raise(
    image,
    Some((observed_functions, observed_scale) => {
      functions = observed_functions
      scale = Some(observed_scale)
    }),
  )
  { module_, functions, scale: scale.unwrap(), }
}

///|
fn compile_or_raise(
  image : @physical.PhysicalProgram,
  observe : ((Array[WasmFunctionProvenance], WasmModuleScale) -> Unit)?,
) -> @wasm_types.Module raise WasmCompileError {
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => raise InvalidPhysicalProgram(error)
  }
  let image = verified.image
  let wasm_module = @wasm_types.Module::empty()
  let imports = image.functions.filter_map(fn(entry) {
    match entry {
      RuntimeImport(import_) => Some(import_)
      PhysicalBody(_) => None
    }
  })
  let host_objects_enabled = imports.any(runtime_import_uses_host_objects)
  if host_objects_enabled && !image.layouts.any(layout => layout is Reference) {
    raise ValidationFailure(
      detail="Opaque runtime imports require a Reference layout",
    )
  }
  let function_catalog = plan_wasm_function_catalog(
    image,
    verified.global_lifecycle,
    host_objects_enabled,
    wasm_module,
  )
  let emitter = WasmFunctionEmitter::new(wasm_module, observe is Some(_))
  let static_image = build_static_image(
    image,
    verified.global_lifecycle,
    function_catalog,
    host_objects_enabled,
  )
  let fatal_tag_type = intern_function_type(wasm_module, [], [])
  wasm_module.tags.push({ type_idx: fatal_tag_type, })
  for catalog_entry in function_catalog.entries {
    match catalog_entry.declaration {
      Import(_) => emitter.append_import(catalog_entry)
      Defined => {
        let code = match catalog_entry.origin {
          PhysicalFunction(function~) => {
            guard image.functions[function.value - 1] is PhysicalBody(body) else {
              raise InvalidFunctionCatalog(
                detail="physical function role does not name a physical body",
              )
            }
            compile_body(
              function.value,
              body,
              wasm_module,
              static_image,
              function_catalog,
            )
          }
          RuntimeImportAdapter(function~, symbol=_) => {
            guard image.functions[function.value - 1] is RuntimeImport(import_) else {
              raise InvalidFunctionCatalog(
                detail="runtime adapter role does not name a runtime import",
              )
            }
            compile_runtime_import_adapter(
              import_,
              @physical.runtime_import_callable_abi(import_),
              function_catalog.physical_import(function),
              function_catalog,
            )
          }
          RuntimeFunction(role) =>
            compile_runtime_function(role, function_catalog, static_image)
          HelperFunction(role) =>
            compile_helper_function(role, static_image, function_catalog)
          EntryWrapper =>
            {
              locals: [],
              body: compile_entry_lifecycle(image, function_catalog),
            }
          InternalRuntimeImport(_) | PhysicalRuntimeImport(_) =>
            raise InvalidFunctionCatalog(
              detail="catalog import was classified as a definition",
            )
        }
        emitter.append_defined(catalog_entry, code)
      }
    }
  }
  let initial_pages = (static_image.heap_base + 65535) / 65536
  wasm_module.memories.push({
    limits: { min: initial_pages.to_int64(), max: None, },
    is_memory64: false,
    page_size_log2: 16,
  })
  append_runtime_globals(wasm_module, static_image)
  wasm_module.datas.push({
    memory_idx: 0,
    offset: [I32Const(0)],
    init: static_image.bytes,
  })
  let table_size = function_catalog.table_entries.length() + 1
  wasm_module.tables.push({
    type_: {
      elem_type: FuncRef,
      limits: { min: table_size.to_int64(), max: Some(table_size.to_int64()), },
      is_table64: false,
    },
    init: Some([RefNull(FuncRef)]),
  })
  let element_initializers : Array[Array[@wasm_types.Instruction]] = []
  for handle in function_catalog.table_entries {
    element_initializers.push([handle.ref_func()])
  }
  wasm_module.elems.push({
    mode: Active(0, [I32Const(1)]),
    type_: FuncRef,
    init: element_initializers,
  })
  wasm_module.exports.push({
    name: "lane.entry",
    desc: Func(function_catalog.require(EntryWrapper).index),
  })
  wasm_module.exports.push({ name: "lane.memory", desc: Memory(0), })
  wasm_module.exports.push({
    name: "lane.runtime.string.new",
    desc: Func(function_catalog.runtime(ByteSequenceNew).index),
  })
  wasm_module.exports.push({
    name: "lane.runtime.host_object.new",
    desc: Func(function_catalog.runtime(HostObjectNew).index),
  })
  if observe is Some(emit) {
    emit(function_catalog.provenance(), emitter.scale())
  }
  wasm_module
}

///|
fn wasm_callable_parameters(
  abi : @physical.CallableAbi,
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
  result : @physical.ResultAbi,
) -> Array[@wasm_types.ValueType] {
  match result {
    Unit => []
    Value(representation, _, _) => [wasm_representation(representation)]
  }
}

///|
fn wasm_representation(
  representation : @physical.Representation,
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
  body : @physical.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
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
    function_catalog,
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
      compile_frame_cleanup(locals, body.slots, wasm_module, function_catalog),
    )
  }
  instructions.append([
    GlobalGet(call_depth_global_index),
    I32Const(1),
    I32Sub,
    GlobalSet(call_depth_global_index),
    Throw(0),
  ])
  { locals: locals.locals, body: instructions, }
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
