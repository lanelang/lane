///|
priv struct ImageLowerer {
  metadata : @buslane.MetadataRegistry
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  plans : Array[PlannedEntry]
  constants : Array[Bytes]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  mut next_synthetic_parameter : Int
}

///|
priv struct FunctionLowerer {
  image : ImageLowerer
  values : Array[@vmcfg.ValueMetadata]
  blocks : Array[LowerBlock]
  mut current_block : Int
  bindings : Array[ValueBinding]
  temps : Array[TempBinding]
  mut environment : @vmcfg.ValueId?
  witnesses : Array[WitnessBinding]
}

///|
pub fn lower_linked_program_to_bytecode(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  lower_linked_program_to_bytecode_with_runtime_effects(
    program,
    externals,
    entry,
    [],
  )
}

///|
pub fn lower_linked_program_to_bytecode_with_runtime_effects(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  runtime_effect_operations : Array[@artifact_core.LinkedRuntimeEffectOperation],
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  Ok(
    lower_linked_program_to_bytecode_or_raise(
      program, externals, entry, runtime_effect_operations,
    ),
  ) catch {
    error => Err(error)
  }
}

///|
fn lower_linked_program_to_bytecode_or_raise(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  runtime_effect_operations : Array[@artifact_core.LinkedRuntimeEffectOperation],
) -> @bytecode.BytecodeImage raise LoisvmLoweringError {
  let (program, externals, entry) = lower_effects_before_anf(
    program, externals, entry, runtime_effect_operations,
  )
  let anf = @anf.lower_buslane_program_to_anf(program)
  let lowerer : ImageLowerer = {
    metadata: program.metadata,
    externals,
    globals: [],
    plans: [],
    constants: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    callable_adapters: [],
    next_synthetic_parameter: -1,
  }
  lowerer.plan(anf)
  let entry_function = match lowerer.find_global(entry.value) {
    Some(Function(function, _)) => function
    _ => raise MissingEntry(value=entry.value)
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  let mut plan_index = 0
  while plan_index < lowerer.plans.length() {
    let plan = lowerer.plans[plan_index]
    match plan {
      Function(value, function) =>
        functions.push(Body(lowerer.lower_function(value, function)))
      LiftedFunction(plan) =>
        functions.push(Body(lowerer.lower_lifted_function(plan)))
      IntrinsicWrapper(plan) =>
        functions.push(Body(lowerer.lower_intrinsic_wrapper(plan)))
      CallableAdapter(plan) =>
        functions.push(Body(lowerer.lower_callable_adapter(plan)))
      RuntimeImport(value, external) => {
        let (parameters, _) = lowerer.function_signature(value, external.type_)
        functions.push(
          RuntimeImport({
            abi_major: 1,
            user_arity: parameters.length(),
            symbol: external.name,
          }),
        )
      }
    }
    plan_index += 1
  }
  let virtual_image = canonicalize_function_table({
    entry: entry_function,
    functions,
    layouts: lowerer.layouts,
    object_shapes: lowerer.object_shapes,
    constants: lowerer.constants,
  })
  match @vmcfg.finalize(virtual_image) {
    Ok(image) => image
    Err(error) => raise VmcfgFinalizeError(error)
  }
}

///|
