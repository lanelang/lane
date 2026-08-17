///|
priv struct ImageLowerer {
  metadata : @buslane.MetadataRegistry
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  instance_globals : Array[@bytecode.GlobalMetadata]
  plans : FunctionPlanTable
  constants : Array[Bytes]
  data_families : Array[@buslane.TypeId]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  representation_specializations : Array[RepresentationSpecializationPlan]
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
  mut substitutions : @buslane.TypeSubstitution
  specialized_parameters : Array[@buslane.TypeParameterId]
}

///|
/// Lowers a program whose entry has already been admitted and whose effect
/// pipeline has already completed. This package does not choose target policy.
pub fn lower_executable_program_to_bytecode(
  executable : @executable.ExecutableProgram,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  lower_executable_program_to_bytecode_observed(executable, _ => ())
}

///|
pub(all) enum LoisvmLoweringStage {
  Anf(@anf.AnfProgram)
  InitialVmcfg(@vmcfg.Image, Array[LoisvmFunctionProvenance])
  FinalBytecode(@bytecode.BytecodeImage, Array[LoisvmFunctionProvenance])
}

///|
pub fn lower_executable_program_to_bytecode_observed(
  executable : @executable.ExecutableProgram,
  observe : (LoisvmLoweringStage) -> Unit,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  Ok(lower_executable_program_to_bytecode_or_raise(executable, observe)) catch {
    error => Err(error)
  }
}

///|
fn lower_executable_program_to_bytecode_or_raise(
  executable : @executable.ExecutableProgram,
  observe : (LoisvmLoweringStage) -> Unit,
) -> @bytecode.BytecodeImage raise LoisvmLoweringError {
  let program = executable.program
  let externals = executable.externals
  let entry = executable.entry
  let runtime_anf = @anf.lower_cps_core_to_runtime_anf(program)
  let anf = runtime_anf.anf()
  observe(Anf(anf))
  let occurrence = @occurrence.analyze({
    program,
    entry: entry.value,
    roots: executable.initializer_roots,
  })
  let lowerer : ImageLowerer = {
    metadata: anf.metadata,
    externals,
    globals: [],
    instance_globals: [],
    plans: FunctionPlanTable::new(),
    constants: [],
    data_families: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    callable_adapters: [],
    representation_specializations: [],
    next_synthetic_parameter: -1,
  }
  let initializer = lowerer.plan(anf, occurrence)
  lowerer.plan_representation_specializations(anf)
  let entry_function = match lowerer.find_global(entry.value) {
    Some(Function(function, _)) => function
    _ => raise MissingEntry(value=entry.value)
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  let mut plan_index = 0
  while plan_index < lowerer.plans.length() {
    let planned = lowerer.plans.get(plan_index)
    match planned.entry {
      Function(value, function) =>
        functions.push(Body(lowerer.lower_function(value, function)))
      InitializerStep(step) =>
        functions.push(Body(lowerer.lower_initializer_step(step)))
      InitializerOrchestrator(steps) =>
        functions.push(Body(lowerer.lower_initializer_orchestrator(steps)))
      LiftedFunction(plan) =>
        functions.push(Body(lowerer.lower_lifted_function(plan)))
      IntrinsicWrapper(plan) =>
        functions.push(Body(lowerer.lower_intrinsic_wrapper(plan)))
      CallableAdapter(plan) =>
        functions.push(Body(lowerer.lower_callable_adapter(plan)))
      RepresentationWorker(plan) =>
        functions.push(Body(lowerer.lower_representation_worker(plan)))
      LayoutConstructor(plan) =>
        functions.push(Body(lowerer.lower_layout_constructor(plan)))
      RuntimeImport(import_) => functions.push(RuntimeImport(import_))
    }
    plan_index += 1
  }
  let canonical = canonicalize_function_table(
    {
      entry: entry_function,
      initializer,
      functions,
      data_family_count: lowerer.data_families.length(),
      globals: lowerer.instance_globals,
      layouts: lowerer.layouts,
      object_shapes: lowerer.object_shapes,
      constants: lowerer.constants,
    },
    lowerer.plans.origins(),
  ) catch {
    error => raise FunctionTableCanonicalizationCompilerDefect(error)
  }
  observe(InitialVmcfg(canonical.image, canonical.provenance))
  match @vmcfg.finalize(canonical.image) {
    Ok(image) => {
      if image.functions.length() != canonical.provenance.length() {
        raise FunctionTableCanonicalizationCompilerDefect(
          FinalizedFunctionCountMismatch(
            functions=image.functions.length(),
            origins=canonical.provenance.length(),
          ),
        )
      }
      observe(FinalBytecode(image, canonical.provenance))
      image
    }
    Err(error) => raise VmcfgFinalizeError(error)
  }
}
