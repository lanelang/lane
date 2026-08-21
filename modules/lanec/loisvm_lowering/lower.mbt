///|
priv struct ImageLowerer {
  metadata : @anf.RuntimeMetadata
  callable_catalog : @anf.AnfCallableCatalog
  mut callable_instances : CallableInstancePlan
  mut representation_demands : PhysicalRepresentationDemandPlan
  runtime_types : RuntimeTypeArena
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  instance_globals : Array[@bytecode.GlobalMetadata]
  plans : FunctionPlanTable
  constants : Array[Bytes]
  data_families : Array[DataRepresentationFamilyPlan]
  materialized_data_families : Array[DataRepresentationFamilyPlan]
  finalized_data_families : Array[DataRepresentationFamilyId]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  lifted_functions : Array[LiftedFunctionPlan]
  synthetic_parameters : Array[@anf.RuntimeEvidenceParameter]
  generic_invocations_in_progress : Array[@bytecode.FunctionId]
  mut physical_representations : PhysicalRepresentationPlan?
}

///|
priv struct FunctionLowerer {
  image : ImageLowerer
  function : @bytecode.FunctionId?
  values : Array[@vmcfg.ValueMetadata]
  blocks : Array[LowerBlock]
  mut current_block : Int
  bindings : Array[ValueBinding]
  temps : Array[TempBinding]
  mut environment : @vmcfg.ValueId?
  witnesses : Array[WitnessBinding]
  mut substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  physical : PhysicalFunctionPlan?
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
    representation_demands: PhysicalRepresentationDemandPlan::empty(),
    runtime_types: RuntimeTypeArena::from_metadata(metadata),
    externals,
    globals: [],
    instance_globals: [],
    plans: FunctionPlanTable::new(),
    constants: [],
    data_families: [],
    materialized_data_families: [],
    finalized_data_families: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    callable_adapters: [],
    lifted_functions: [],
    synthetic_parameters: [],
    generic_invocations_in_progress: [],
    physical_representations: None,
  }
  lowerer.plan_declaration_data_families()
  let (callable_instances, representation_demands) = lowerer.plan_callable_instances(
    anf,
  )
  lowerer.callable_instances = callable_instances
  lowerer.representation_demands = representation_demands
  lowerer.plan_specialized_data_families(
    representation_demands.data_representations,
  )
  let initializer = lowerer.plan(anf)
  lowerer.plan_lifted_callable_instances()
  let represented = lowerer.plan_physical_representations(anf)
  lowerer.verify_materialized_data_family_contracts()
  lowerer.emit_represented_runtime_anf(
    represented,
    entry.value,
    initializer,
    observe,
  )
}

///|
/// VM CFG construction is reachable only through the represented phase
/// boundary. Subsequent slices replace the legacy family-aware emission
/// helpers with direct consumers of `represented.physical`.
fn ImageLowerer::emit_represented_runtime_anf(
  self : ImageLowerer,
  represented : RepresentedRuntimeAnfProgram,
  entry : @buslane.ValueId,
  initializer : @bytecode.FunctionId?,
  observe : (LoisvmLoweringStage) -> Unit,
) -> @bytecode.BytecodeImage raise LoisvmLoweringError {
  ignore(represented.anf)
  self.verify_physical_representations(represented.physical)
  self.physical_representations = Some(represented.physical)
  let entry_function = match self.find_global(entry) {
    Some(Function(function, _)) => function
    _ => raise MissingEntry(value=entry)
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  let planned_function_count = self.plans.length()
  let mut plan_index = 0
  while plan_index < planned_function_count {
    let planned = self.plans.get(plan_index)
    match planned.entry {
      Function(value, function) =>
        functions.push(
          Body(self.lower_function(planned.function, value, function)),
        )
      InitializerStep(step) =>
        functions.push(Body(self.lower_initializer_step(step)))
      InitializerOrchestrator(steps) =>
        functions.push(Body(self.lower_initializer_orchestrator(steps)))
      LiftedFunction(plan) =>
        functions.push(Body(self.lower_lifted_function(planned.function, plan)))
      IntrinsicWrapper(plan) =>
        functions.push(Body(self.lower_intrinsic_wrapper(plan)))
      CallableAdapter(plan) =>
        functions.push(Body(self.lower_callable_adapter(plan)))
      RepresentationWorker(plan) =>
        functions.push(
          Body(self.lower_representation_worker(planned.function, plan)),
        )
      LayoutConstructor(plan) =>
        functions.push(Body(self.lower_layout_constructor(plan)))
      RuntimeImport(import_) => functions.push(RuntimeImport(import_))
    }
    if self.plans.length() != planned_function_count {
      let appended = self.plans.entries[planned_function_count:].map(planned => {
        planned.origin
      })
      raise RepresentationSpecializationInvariant(
        detail="VM CFG emission of \{Repr(planned.origin)} appended unplanned functions \{Repr(appended)}",
      )
    }
    plan_index += 1
  }
  let origins = self.plans.origins()
  if functions.length() != origins.length() {
    raise FunctionProvenanceCompilerDefect(
      OriginCountMismatch(
        functions=functions.length(),
        origins=origins.length(),
      ),
    )
  }
  let finalized = match
    @vmcfg.finalize_observed({
      entry: entry_function,
      initializer,
      functions,
      data_family_count: self.materialized_data_family_count(),
      globals: self.instance_globals,
      layouts: self.layouts,
      object_shapes: self.object_shapes,
      constants: self.constants,
    }) {
    Ok(finalized) => finalized
    Err(error) => raise VmcfgFinalizeError(error)
  }
  let provenance = finalized
    .source_functions()
    .mapi((index, sources) => {
      let canonical_function : @bytecode.FunctionId = { value: index + 1 }
      {
        function: canonical_function,
        origins: sources.map(source => {
          if source.value <= 0 || source.value > origins.length() {
            raise FunctionProvenanceCompilerDefect(
              InvalidSourceFunction(function=source),
            )
          }
          origins[source.value - 1]
        }),
      }
    })
  let image = finalized.bytecode_image()
  if image.functions.length() != provenance.length() {
    raise FunctionProvenanceCompilerDefect(
      FinalizedFunctionCountMismatch(
        functions=image.functions.length(),
        origins=provenance.length(),
      ),
    )
  }
  observe(InitialVmcfg(finalized.pre_arc_image(), provenance))
  observe(FinalBytecode(image, provenance))
  image
}
