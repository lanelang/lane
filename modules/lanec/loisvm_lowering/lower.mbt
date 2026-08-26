///|
priv struct ImageLowerer {
  metadata : @anf.RuntimeMetadata
  callable_catalog : @anf.AnfCallableCatalog
  mut callable_instances : CallableInstancePlan
  mut representation_solution : RepresentationSolution
  callable_contracts : PhysicalCallableContractCatalog
  representation_transitions : PhysicalRepresentationTransitionCatalog
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
}

///|
priv struct FunctionLowerer {
  physical_program : PhysicalAnfProgram
  function : @bytecode.FunctionId?
  values : Array[@vmcfg.ValueMetadata]
  blocks : Array[LowerBlock]
  mut current_block : Int
  bindings : Array[ValueBinding]
  temps : Array[TempBinding]
  mut environment : @vmcfg.ValueId?
  witnesses : Array[WitnessBinding]
  physical : PhysicalFunctionPlan?
  adapter_support : PhysicalCallableAdapterSupport?
  emitted_transition_events : Array[
    PhysicalEmittedRepresentationTransitionEvent,
  ]
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
  InitialVmcfg(@vmcfg.Image, LoisvmLoweringProvenance)
  FinalBytecode(@bytecode.BytecodeImage, LoisvmLoweringProvenance)
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
    representation_solution: RepresentationSolution::empty(),
    callable_contracts: PhysicalCallableContractCatalog::new(),
    representation_transitions: PhysicalRepresentationTransitionCatalog::new(),
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
  }
  lowerer.plan_declaration_data_families()
  let (callable_instances, representation_solution) = lowerer.plan_callable_instances(
    anf,
  )
  lowerer.callable_instances = callable_instances
  lowerer.representation_solution = representation_solution
  lowerer.plan_specialized_data_families(
    representation_solution.data_representations,
  )
  let initializer = lowerer.plan(anf)
  lowerer.plan_lifted_callable_instances()
  let physical = lowerer.elaborate_physical_anf()
  lowerer.verify_materialized_data_family_contracts()
  emit_physical_anf(physical, entry.value, initializer, observe)
}

///|
/// VM CFG construction is reachable only through verified Physical ANF.
fn emit_physical_anf(
  verified : VerifiedPhysicalAnfProgram,
  entry : @buslane.ValueId,
  initializer : @bytecode.FunctionId?,
  observe : (LoisvmLoweringStage) -> Unit,
) -> @bytecode.BytecodeImage raise LoisvmLoweringError {
  let physical = verified.program
  let entry_function = match physical.required_global(entry).producer {
    PhysicalFunction(function) => function
    _ => raise MissingEntry(value=entry)
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  let emitted_transition_events : Array[
    Array[PhysicalEmittedRepresentationTransitionEvent],
  ] = []
  for emission in physical.emissions {
    let function_transition_events = []
    match emission.body {
      Function =>
        functions.push(
          Body(
            lower_function_body(
              physical,
              emission.function,
              function_transition_events,
            ),
          ),
        )
      InitializerStep(step) =>
        functions.push(
          Body(
            lower_initializer_step(physical, step, function_transition_events),
          ),
        )
      InitializerOrchestrator(steps) =>
        functions.push(Body(lower_initializer_orchestrator(physical, steps)))
      Intrinsic(plan) =>
        functions.push(Body(lower_intrinsic_wrapper(physical, plan)))
      CallableAdapter =>
        functions.push(
          Body(
            lower_callable_adapter(
              physical,
              physical.required_callable_adapter(emission.function),
              function_transition_events,
            ),
          ),
        )
      LayoutConstructor(plan) =>
        functions.push(Body(lower_layout_constructor(physical, plan)))
      RuntimeImport(import_) => functions.push(RuntimeImport(import_))
    }
    emitted_transition_events.push(function_transition_events)
  }
  verify_emitted_transition_events(physical, emitted_transition_events)
  let origins = physical.emissions.map(emission => emission.origin)
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
      data_family_count: physical.data_family_count,
      globals: physical.instance_globals,
      layouts: physical.layouts,
      object_shapes: physical.object_shapes,
      constants: physical.constants,
    }) {
    Ok(finalized) => finalized
    Err(error) => raise VmcfgFinalizeError(error)
  }
  let function_provenance = finalized
    .source_functions()
    .mapi((index, sources) => {
      let canonical_function : @bytecode.FunctionId = { value: index + 1, }
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
  if image.functions.length() != function_provenance.length() {
    raise FunctionProvenanceCompilerDefect(
      FinalizedFunctionCountMismatch(
        functions=image.functions.length(),
        origins=function_provenance.length(),
      ),
    )
  }
  let initial_vmcfg = finalized.pre_arc_image()
  let transition_occurrences : Array[LoisvmRepresentationTransitionOccurrence] = []
  for final_index, sources in finalized.source_functions() {
    let function : @bytecode.FunctionId = { value: final_index + 1, }
    let canonical_origins : Array[LoisvmFunctionOrigin] = []
    for source in sources {
      if source.value <= 0 || source.value > origins.length() {
        raise FunctionProvenanceCompilerDefect(
          InvalidSourceFunction(function=source),
        )
      }
      let origin = origins[source.value - 1]
      if !canonical_origins.contains(origin) {
        canonical_origins.push(origin)
      }
    }
    let representative_events = canonical_transition_event_stream(
      function,
      sources,
      emitted_transition_events,
      initial_vmcfg.functions[final_index],
      physical.representation_transitions,
    )
    for entry in representative_events {
      let (event_index, emitted) = entry
      transition_occurrences.push({
        event: event_index,
        function,
        origins: canonical_origins.copy(),
        transition: emitted.transition,
        boundary: emitted.boundary,
        binding: emitted.binding,
        ordinal: emitted.ordinal,
      })
    }
  }
  let provenance : LoisvmLoweringProvenance = {
    functions: function_provenance,
    callable_contracts: physical.callable_contracts.observations(),
    representation_transitions: physical.representation_transitions.observations(
      physical.callable_contracts,
    ),
    transition_occurrences,
  }
  verify_representation_transition_emission(initial_vmcfg, provenance)
  observe(InitialVmcfg(initial_vmcfg, provenance))
  observe(FinalBytecode(image, provenance))
  image
}

///|
fn canonical_transition_event_stream(
  function : @bytecode.FunctionId,
  sources : Array[@bytecode.FunctionId],
  emitted_by_function : Array[
    Array[PhysicalEmittedRepresentationTransitionEvent],
  ],
  final_entry : @vmcfg.FunctionEntry,
  transitions : PhysicalRepresentationTransitionCatalog,
) -> Array[(Int, PhysicalEmittedRepresentationTransitionEvent)] raise LoisvmLoweringError {
  guard sources.get(0) is Some(representative) &&
    emitted_by_function.get(representative.value - 1)
    is Some(representative_events) else {
    raise FunctionProvenanceCompilerDefect(InvalidSourceFunction(function~))
  }
  let representative_events = retained_transition_event_stream(
    function, representative_events, final_entry, transitions,
  )
  let representative_transitions = representative_events.map(entry => {
    (entry.1.transition, entry.1.operation)
  })
  for source_index, source in sources {
    guard source_index > 0 else { continue }
    guard emitted_by_function.get(source.value - 1) is Some(source_events) else {
      raise FunctionProvenanceCompilerDefect(
        TransitionEventStreamMismatch(function~, source~),
      )
    }
    let source_events = retained_transition_event_stream(
      function, source_events, final_entry, transitions,
    )
    guard source_events.map(entry => (entry.1.transition, entry.1.operation)) ==
      representative_transitions else {
      raise FunctionProvenanceCompilerDefect(
        TransitionEventStreamMismatch(function~, source~),
      )
    }
  }
  representative_events
}

///|
fn retained_transition_event_stream(
  function : @bytecode.FunctionId,
  events : Array[PhysicalEmittedRepresentationTransitionEvent],
  final_entry : @vmcfg.FunctionEntry,
  transitions : PhysicalRepresentationTransitionCatalog,
) -> Array[(Int, PhysicalEmittedRepresentationTransitionEvent)] raise LoisvmLoweringError {
  let retained = []
  for event_index, event in events {
    let transition = transitions.transition(event.transition)
    guard final_entry is Body(body) else { continue }
    if transition.kind is CallableAdapter {
      if callable_adapter_operation_survives(body, event.operation) {
        retained.push((event_index, event))
      }
      continue
    }
    guard anchored_representation_operation(
        body,
        event.operation,
        transition.kind,
      )
      is Some(operation) else {
      continue
    }
    if !physical_transition_matches_operation(transition, operation) {
      raise FunctionProvenanceCompilerDefect(
        TransitionEventMismatch(
          function~,
          event=event_index,
          transition=event.transition,
        ),
      )
    }
    retained.push((event_index, event))
  }
  retained
}

///|
fn callable_adapter_operation_survives(
  body : @vmcfg.FunctionBody,
  operation : PhysicalRepresentationTransitionOperation,
) -> Bool {
  guard operation is Produced(value) else { return false }
  for block in body.blocks {
    for instruction in block.instructions {
      if instruction is MakeClosure(destination, _, _) && value == destination {
        return true
      }
    }
  }
  false
}

///|
fn anchored_representation_operation(
  body : @vmcfg.FunctionBody,
  anchor : PhysicalRepresentationTransitionOperation,
  kind : PhysicalRepresentationTransitionKind,
) -> EmittedRepresentationOperation? {
  for block in body.blocks {
    for instruction in block.instructions {
      let matches = match (kind, anchor, instruction) {
        (Erase, Produced(value), EraseUnit(destination))
        | (Erase, Produced(value), EraseI32(destination, _))
        | (Erase, Produced(value), EraseI64(destination, _))
        | (Erase, Produced(value), EraseF32(destination, _))
        | (Erase, Produced(value), EraseF64(destination, _))
        | (Unerase, Produced(value), UneraseI32(destination, _))
        | (Unerase, Produced(value), UneraseI64(destination, _))
        | (Unerase, Produced(value), UneraseF32(destination, _))
        | (Unerase, Produced(value), UneraseF64(destination, _)) =>
          value == destination
        (Unerase, Consumed(value), UneraseUnit(source)) => value == source
        _ => false
      }
      if matches {
        return representation_operation(body, instruction)
      }
    }
  }
  None
}

///|
fn verify_representation_transition_emission(
  image : @vmcfg.Image,
  provenance : LoisvmLoweringProvenance,
) -> Unit raise LoisvmLoweringError {
  for index, entry in image.functions {
    let function : @bytecode.FunctionId = { value: index + 1, }
    let operations = match entry {
      Body(body) => representation_operations(body)
      RuntimeImport(_) => []
    }
    let planned : Array[LoisvmRepresentationTransitionOccurrence] = []
    for occurrence in provenance.transition_occurrences {
      guard occurrence.function == function else { continue }
      guard provenance.representation_transitions.get(
          occurrence.transition.index,
        )
        is Some(transition) else {
        raise RepresentationSpecializationInvariant(
          detail="representation transition occurrence is outside its exported catalog",
        )
      }
      if transition.kind != CallableAdapter {
        planned.push(occurrence)
      }
    }
    if planned.length() != operations.length() {
      raise FunctionProvenanceCompilerDefect(
        TransitionOperationCountMismatch(
          function~,
          events=planned.length(),
          operations=operations.length(),
        ),
      )
    }
  }
}

///|
priv struct EmittedRepresentationOperation {
  kind : LoisvmRepresentationTransitionKind
  source : @bytecode.ValueAbi?
  target : @bytecode.ValueAbi?
}

///|
fn representation_operations(
  body : @vmcfg.FunctionBody,
) -> Array[EmittedRepresentationOperation] {
  let operations : Array[EmittedRepresentationOperation] = []
  for block in body.blocks {
    for instruction in block.instructions {
      if representation_operation(body, instruction) is Some(operation) {
        operations.push(operation)
      }
    }
  }
  operations
}

///|
fn representation_operation(
  body : @vmcfg.FunctionBody,
  instruction : @vmcfg.Instruction,
) -> EmittedRepresentationOperation? {
  match instruction {
    EraseUnit(destination) =>
      Some({
        kind: LoisvmRepresentationTransitionKind::Erase,
        source: None,
        target: Some(vmcfg_value_abi(body, destination)),
      })
    EraseI32(destination, source)
    | EraseI64(destination, source)
    | EraseF32(destination, source)
    | EraseF64(destination, source) =>
      Some({
        kind: LoisvmRepresentationTransitionKind::Erase,
        source: Some(vmcfg_value_abi(body, source)),
        target: Some(vmcfg_value_abi(body, destination)),
      })
    UneraseUnit(source) =>
      Some({
        kind: LoisvmRepresentationTransitionKind::Unerase,
        source: Some(vmcfg_value_abi(body, source)),
        target: None,
      })
    UneraseI32(destination, source)
    | UneraseI64(destination, source)
    | UneraseF32(destination, source)
    | UneraseF64(destination, source) =>
      Some({
        kind: LoisvmRepresentationTransitionKind::Unerase,
        source: Some(vmcfg_value_abi(body, source)),
        target: Some(vmcfg_value_abi(body, destination)),
      })
    _ => None
  }
}

///|
fn physical_transition_matches_operation(
  transition : PhysicalRepresentationTransition,
  operation : EmittedRepresentationOperation,
) -> Bool {
  let kind_matches = match (transition.kind, operation.kind) {
    (Erase, LoisvmRepresentationTransitionKind::Erase)
    | (Unerase, LoisvmRepresentationTransitionKind::Unerase) => true
    _ => false
  }
  kind_matches &&
  canonical_runtime_key_matches_abi(transition.source, operation.source) &&
  canonical_runtime_key_matches_abi(transition.target, operation.target)
}

///|
fn canonical_runtime_key_matches_abi(
  contract : CanonicalRuntimeTypeKey,
  abi : @bytecode.ValueAbi?,
) -> Bool {
  match (contract, abi) {
    (Unit, None) => true
    (Value(expected), Some(actual)) => expected == actual
    (
      Callable(_),
      Some(
        { representation: I64, cleanup: OwnedCallable, kind: CallableValue, }
      ),
    ) => true
    _ => false
  }
}

///|
fn vmcfg_value_abi(
  body : @vmcfg.FunctionBody,
  value : @vmcfg.ValueId,
) -> @bytecode.ValueAbi {
  let metadata = body.values[value.value]
  {
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    kind: metadata.kind,
  }
}

///|
fn verify_emitted_transition_events(
  physical : PhysicalAnfProgram,
  emitted_by_function : Array[
    Array[PhysicalEmittedRepresentationTransitionEvent],
  ],
) -> Unit raise LoisvmLoweringError {
  if emitted_by_function.length() != physical.emissions.length() {
    raise RepresentationSpecializationInvariant(
      detail="physical function emission and transition-event sidecar counts disagree",
    )
  }
  for index, emission in physical.emissions {
    let emitted = emitted_by_function[index]
    for event_index, event in emitted {
      ignore(physical.representation_transitions.transition(event.transition)) catch {
        _ =>
          raise FunctionProvenanceCompilerDefect(
            TransitionEventMismatch(
              function=emission.function,
              event=event_index,
              transition=event.transition,
            ),
          )
      }
    }
  }
}
