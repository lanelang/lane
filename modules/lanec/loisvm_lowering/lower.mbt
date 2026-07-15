///|
priv struct ImageLowerer {
  metadata : @buslane.MetadataRegistry
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  instance_globals : Array[@bytecode.GlobalMetadata]
  plans : Array[PlannedEntry]
  constants : Array[Bytes]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  effect_companions : Array[@effect_lowering_cps.EffectCompanionBinding]
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
  substitutions : Array[TypeArgumentBinding]
}

///|
pub fn lower_linked_program_to_bytecode(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  let linked : @module_link.LinkedProgram = {
    module_path_texts: [],
    program,
    externals,
    entries: [entry],
  }
  match @executable.elaborate(linked, entry) {
    Ok(executable) => lower_executable_program_to_bytecode(executable)
    Err(error) => Err(executable_elaboration_error(error))
  }
}

///|
pub fn lower_executable_program_to_bytecode(
  executable : @executable.ExecutableProgram,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  Ok(lower_executable_program_to_bytecode_or_raise(executable)) catch {
    error => Err(error)
  }
}

///|
fn lower_executable_program_to_bytecode_or_raise(
  executable : @executable.ExecutableProgram,
) -> @bytecode.BytecodeImage raise LoisvmLoweringError {
  let program = executable.program
  let externals = executable.externals
  let entry = executable.entry
  let anf = @anf.lower_buslane_program_to_anf(program)
  let occurrence = @occurrence.analyze({
    program,
    entry: entry.value,
    roots: executable_initializer_roots(executable),
  })
  let lowerer : ImageLowerer = {
    metadata: program.metadata,
    externals,
    globals: [],
    instance_globals: [],
    plans: [],
    constants: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    callable_adapters: [],
    effect_companions: executable.effect_companions,
    next_synthetic_parameter: -1,
  }
  let initializer = lowerer.plan(anf, occurrence)
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
      Initializer(bindings) =>
        functions.push(Body(lowerer.lower_initializer(bindings)))
      LiftedFunction(plan) =>
        functions.push(Body(lowerer.lower_lifted_function(plan)))
      IntrinsicWrapper(plan) =>
        functions.push(Body(lowerer.lower_intrinsic_wrapper(plan)))
      CallableAdapter(plan) =>
        functions.push(Body(lowerer.lower_callable_adapter(plan)))
      RuntimeImport(external, user_arity) =>
        functions.push(
          RuntimeImport({ abi_major: 1, user_arity, symbol: external.symbol }),
        )
    }
    plan_index += 1
  }
  let virtual_image = canonicalize_function_table({
    entry: entry_function,
    initializer,
    functions,
    globals: lowerer.instance_globals,
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
fn executable_initializer_roots(
  executable : @executable.ExecutableProgram,
) -> Array[@buslane.ValueId] {
  let roots = []
  for root in executable.execution_roots {
    guard root is Initializer(index) else { continue }
    match executable.initializers[index] {
      Value(value, _) => roots.push(value)
      Recursive(bindings) =>
        for binding in bindings {
          roots.push(binding.id)
        }
    }
  }
  roots
}

///|
fn executable_elaboration_error(
  error : @executable.ExecutableElaborationError,
) -> LoisvmLoweringError {
  match error {
    EntryNotLinked(value) => MissingEntry(value~)
    InvalidEntryFunction(value~, type_~) => InvalidFunctionType(value~, type_~)
    UnsupportedEffectSpecialization(detail~) => UnsupportedExpression(detail~)
    EffectLoweringError(error) => EffectLoweringError(error)
  }
}

///|
