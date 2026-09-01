///|
pub(all) suberror WasmCompileError {
  UnsupportedInstruction(function_id~ : Int, instruction~ : String)
  InvalidBlockTarget(function_id~ : Int, target~ : Int)
  InvalidEdgeArity(
    function_id~ : Int,
    target~ : Int,
    expected~ : Int,
    actual~ : Int
  )
  MissingByteSequenceLayout
  MissingByteBufferLayout
  InvalidFunctionCatalog(detail~ : String)
  ValidationFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub fn compile(
  image : @physical.VerifiedPhysicalProgram,
) -> Result[@wasm_types.Module, WasmCompileError] {
  Ok(compile_or_raise(image, None)) catch {
    error => Err(error)
  }
}

///|
pub fn compile_observed(
  image : @physical.VerifiedPhysicalProgram,
) -> Result[WasmCompileObservation, WasmCompileError] {
  Ok(compile_observed_or_raise(image)) catch {
    error => Err(error)
  }
}

///|
fn compile_observed_or_raise(
  image : @physical.VerifiedPhysicalProgram,
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
  verified : @physical.VerifiedPhysicalProgram,
  observe : ((Array[WasmFunctionProvenance], WasmModuleScale) -> Unit)?,
) -> @wasm_types.Module raise WasmCompileError {
  let image = verified.image()
  let global_lifecycle = verified.global_lifecycle()
  let wasm_module = @wasm_types.Module::empty()
  let function_catalog = plan_wasm_function_catalog(
    image, global_lifecycle, wasm_module,
  )
  let emitter = WasmFunctionEmitter::new(wasm_module, observe is Some(_))
  let static_image = build_static_image(
    image, global_lifecycle, function_catalog,
  )
  for catalog_entry in function_catalog.entries {
    match catalog_entry.declaration {
      Import(_) => emitter.append_import(catalog_entry)
      Defined => {
        let compiled = match catalog_entry.origin {
          BuiltinFunction(role) =>
            account_whole_function(
              compile_builtin_function(role, function_catalog),
              RuntimeSupport,
            )
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
          RuntimeImportAdapter(function~, ..) => {
            guard image.functions[function.value - 1] is RuntimeImport(import_) else {
              raise InvalidFunctionCatalog(
                detail="runtime adapter role does not name a runtime import",
              )
            }
            account_whole_function(
              compile_runtime_import_adapter(
                import_,
                @physical.runtime_import_callable_abi(import_),
                function_catalog.physical_import(function),
              ),
              RuntimeImportAdapter,
            )
          }
          RuntimeFunction(role) =>
            account_whole_function(
              compile_runtime_function(
                role, function_catalog, static_image, wasm_module,
              ),
              RuntimeSupport,
            )
          HelperFunction(role) =>
            account_whole_function(
              compile_helper_function(
                role, static_image, function_catalog, wasm_module,
              ),
              match role {
                CallableAbiGuard | PackedCallableTargetGuard => RuntimeGuard
                _ => HelperSupport
              },
            )
          EntryWrapper =>
            account_whole_function(
              {
                locals: [],
                body: compile_entry_lifecycle(image, function_catalog),
              },
              EntryLifecycle,
            )
          WasiPreview1Import(_) | PhysicalRuntimeImport(_) =>
            raise InvalidFunctionCatalog(
              detail="catalog import was classified as a definition",
            )
        }
        emitter.append_defined(
          catalog_entry,
          compiled.code,
          compiled.expansions,
        )
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
    name: "_start",
    desc: Func(function_catalog.require(EntryWrapper).index),
  })
  wasm_module.exports.push({ name: "memory", desc: Memory(0), })
  if observe is Some(emit) {
    emit(
      function_catalog.provenance(),
      emitter.scale(function_catalog.unreachable_support_role_count()),
    )
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
) -> CompiledWasmFunction raise WasmCompileError {
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
  let expansions : Array[WasmExpansionScale] = []
  let context : FunctionCompilationContext = {
    function_id,
    locals,
    body,
    wasm_module,
    static_image,
    function_catalog,
    expansions,
  }
  let instructions : Array[@wasm_types.Instruction] = []
  let mut parameter_index = 1
  if body.inputs.environment is Some(slot) {
    instructions.push(LocalGet(0))
    instructions.push(LocalSet(locals.slot_local(slot)))
  }
  for slot in body.inputs.witnesses {
    instructions.push(LocalGet(parameter_index))
    instructions.push(LocalSet(locals.slot_local(slot)))
    parameter_index += 1
  }
  for slot in body.inputs.user_parameters {
    instructions.push(LocalGet(parameter_index))
    instructions.push(LocalSet(locals.slot_local(slot)))
    parameter_index += 1
  }
  add_expansion(
    expansions,
    FunctionAbi,
    wasm_instruction_array_size(instructions),
    0,
  )
  add_expansion(expansions, PhysicalStorage, 0, locals.slot_local_count)
  add_expansion(expansions, ControlFlow, 0, locals.control_local_count)
  let source_instruction_count_before = expansion_instruction_count(expansions)
  let compiled_control : Array[@wasm_types.Instruction] = []
  if structured is Some(sequence) {
    compiled_control.append(compile_structured_cfg(context, sequence))
  } else if use_balanced_dispatcher {
    compiled_control.push(compile_balanced_dispatcher(context))
    compiled_control.push(Unreachable)
  } else if use_dispatcher {
    compiled_control.push(compile_dispatcher(context))
    compiled_control.push(Unreachable)
  } else {
    for instruction in body.blocks[0].instructions {
      compiled_control.append(context.compile_instruction(instruction))
    }
    compiled_control.append(
      context.compile_terminator(body.blocks[0].terminator),
    )
  }
  let source_instruction_count = expansion_instruction_count(expansions) -
    source_instruction_count_before
  add_expansion(
    expansions,
    ControlFlow,
    wasm_instruction_array_size(compiled_control) - source_instruction_count,
    0,
  )
  instructions.append(compiled_control)
  { code: { locals: locals.locals, body: instructions, }, expansions, }
}

///|
