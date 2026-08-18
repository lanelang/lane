///|
priv struct ImageLowerer {
  metadata : @anf.RuntimeMetadata
  callable_catalog : @anf.AnfCallableCatalog
  mut callable_instances : CallableInstancePlan
  runtime_types : RuntimeTypeArena
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  instance_globals : Array[@bytecode.GlobalMetadata]
  plans : FunctionPlanTable
  constants : Array[Bytes]
  data_families : Array[DataRepresentationFamilyPlan]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  lifted_functions : Array[LiftedFunctionPlan]
  representation_specializations : Array[RepresentationSpecializationPlan]
  synthetic_parameters : Array[@anf.RuntimeEvidenceParameter]
}

///|
priv struct FunctionLowerer {
  image : ImageLowerer
  caller_instances : Array[Int]
  data_families : Array[DataRepresentationFamilyPlan]
  values : Array[@vmcfg.ValueMetadata]
  blocks : Array[LowerBlock]
  mut current_block : Int
  bindings : Array[ValueBinding]
  temps : Array[TempBinding]
  mut environment : @vmcfg.ValueId?
  witnesses : Array[WitnessBinding]
  mut substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  representation_worker : Bool
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
  let anf = match
    @anf.lower_cps_core_to_runtime_anf({
      program,
      retained_values: executable.retained_values,
    }) {
    Ok(anf) => anf
    Err(error) => raise RuntimeAnfCompilerDefect(error)
  }
  observe(Anf(anf))
  let metadata = anf.metadata()
  let lowerer : ImageLowerer = {
    metadata,
    callable_catalog: anf.callable_catalog(),
    callable_instances: CallableInstancePlan::empty(),
    runtime_types: RuntimeTypeArena::from_metadata(metadata),
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
    lifted_functions: [],
    representation_specializations: [],
    synthetic_parameters: [],
  }
  lowerer.plan_declaration_data_families()
  let callable_instances = lowerer.plan_callable_instances(anf)
  lowerer.plan_specialized_data_families(
    callable_instances.data_representations,
  )
  lowerer.callable_instances = callable_instances
  let initializer = lowerer.plan(anf)
  lowerer.plan_lifted_callable_instances()
  lowerer.plan_representation_specializations(lowerer.callable_instances)
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
      data_family_count: lowerer.materialized_data_family_count(),
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
