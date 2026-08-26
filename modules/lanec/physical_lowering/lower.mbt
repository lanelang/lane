///|
priv struct ImageLowerer {
  metadata : @anf.RuntimeMetadata
  runtime_types : RuntimeTypeArena
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  instance_globals : Array[@physical.GlobalMetadata]
  plans : FunctionPlanTable
  constants : Array[Bytes]
  data_families : Array[@buslane.TypeId]
  layouts : Array[@physical.LayoutRecipe]
  object_shapes : Array[@physical.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  synthetic_parameters : Array[@anf.RuntimeEvidenceParameter]
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
  mut substitutions : RuntimeSubstitution
}

///|
/// Lowers a program whose entry has already been admitted and whose effect
/// pipeline has already completed. This package does not choose target policy.
pub fn lower_executable_program_to_physical(
  executable : @executable.ExecutableProgram,
) -> Result[@physical.PhysicalProgram, PhysicalLoweringError] {
  lower_executable_program_to_physical_observed(executable, _ => ())
}

///|
pub(all) enum PhysicalLoweringStage {
  Anf(@anf.AnfProgram)
  InitialVmcfg(@vmcfg.Image, PhysicalLoweringProvenance)
  FinalPhysicalProgram(@physical.PhysicalProgram, PhysicalLoweringProvenance)
}

///|
pub fn lower_executable_program_to_physical_observed(
  executable : @executable.ExecutableProgram,
  observe : (PhysicalLoweringStage) -> Unit,
) -> Result[@physical.PhysicalProgram, PhysicalLoweringError] {
  Ok(lower_executable_program_to_physical_or_raise(executable, observe)) catch {
    error => Err(error)
  }
}

///|
fn lower_executable_program_to_physical_or_raise(
  executable : @executable.ExecutableProgram,
  observe : (PhysicalLoweringStage) -> Unit,
) -> @physical.PhysicalProgram raise PhysicalLoweringError {
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
    synthetic_parameters: [],
  }
  let initializer = lowerer.plan(anf)
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
      LayoutConstructor(plan) =>
        functions.push(Body(lowerer.lower_layout_constructor(plan)))
      RuntimeImport(import_) => functions.push(RuntimeImport(import_))
    }
    plan_index += 1
  }
  let origins = lowerer.plans.origins()
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
      data_family_count: lowerer.data_families.length(),
      globals: lowerer.instance_globals,
      layouts: lowerer.layouts,
      object_shapes: lowerer.object_shapes,
      constants: lowerer.constants,
    }) {
    Ok(finalized) => finalized
    Err(error) => raise VmcfgFinalizeError(error)
  }
  let function_provenance = finalized
    .source_functions()
    .mapi((index, sources) => {
      let function : @physical.FunctionId = { value: index + 1, }
      {
        function,
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
  let image = finalized.physical_program()
  if image.functions.length() != function_provenance.length() {
    raise FunctionProvenanceCompilerDefect(
      FinalizedFunctionCountMismatch(
        functions=image.functions.length(),
        origins=function_provenance.length(),
      ),
    )
  }
  let provenance : PhysicalLoweringProvenance = {
    functions: function_provenance,
  }
  observe(InitialVmcfg(finalized.pre_arc_image(), provenance))
  observe(FinalPhysicalProgram(image, provenance))
  image
}
