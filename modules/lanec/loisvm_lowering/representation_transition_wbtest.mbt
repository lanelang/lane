///|
test "representation transition catalog interns one canonical ABI transition" {
  let catalog = PhysicalRepresentationTransitionCatalog::new()
  let transition : PhysicalRepresentationTransition = {
    source: Value({
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
    }),
    target: Value({ representation: I64, cleanup: Trivial, kind: ScalarValue, }),
    kind: Unerase,
  }
  let first = catalog.intern(transition)
  let second = catalog.intern(transition)
  assert_eq(first, second)
  assert_true(catalog.transition(first) == transition)
}

///|
test "equal representation sites remain distinct emitted events" {
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let transition = physical.representation_transitions.intern({
    source: CanonicalRuntimeTypeKey::Value({
      representation: I64,
      cleanup: Trivial,
      kind: ScalarValue,
    }),
    target: CanonicalRuntimeTypeKey::Value({
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
    }),
    kind: PhysicalRepresentationTransitionKind::Erase,
  })
  let events = []
  let lowerer : FunctionLowerer = {
    physical_program: physical,
    function: Some({ value: 1, }),
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    physical: None,
    adapter_support: None,
    emitted_transition_events: events,
  }
  let site : PhysicalRepresentationTransitionSite = {
    transition,
    boundary: DataConstructionPayload,
    binding: Some(Temp({ index: 7, })),
    ordinal: Some(0),
  }
  let operation = Produced(@vmcfg.ValueId::{ value: 0, })
  lowerer.record_representation_transition_event(site, operation)
  lowerer.record_representation_transition_event(site, operation)
  assert_eq(
    events.map(event => {
      (event.transition, event.boundary, event.binding, event.ordinal)
    }),
    [
      (transition, DataConstructionPayload, Some(Temp({ index: 7, })), Some(0)),
      (transition, DataConstructionPayload, Some(Temp({ index: 7, })), Some(0)),
    ],
  )
}

///|
fn transition_stream_test_body() -> @vmcfg.FunctionEntry {
  Body({
    values: [
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        ownership: Owned,
        erased_companion: None,
      },
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [UneraseUnit({ value: 0, })],
        terminator: Return(None),
      },
    ],
  })
}

///|
fn transition_stream_test_catalog() -> (
  PhysicalRepresentationTransitionCatalog,
  LoisvmRepresentationTransitionId,
  LoisvmRepresentationTransitionId,
) {
  let catalog = PhysicalRepresentationTransitionCatalog::new()
  let erased : @bytecode.ValueAbi = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
  }
  let first = catalog.intern({
    source: Value(erased),
    target: Unit,
    kind: Unerase,
  })
  let second = catalog.intern({
    source: Value({ ..erased, representation: I32, }),
    target: Unit,
    kind: Unerase,
  })
  (catalog, first, second)
}

///|
test "canonical VM CFG function selects one equivalent transition stream" {
  let (catalog, transition, _) = transition_stream_test_catalog()
  let first : PhysicalEmittedRepresentationTransitionEvent = {
    transition,
    boundary: AtomBinding,
    binding: Some(Temp({ index: 1, })),
    ordinal: None,
    operation: Consumed({ value: 0, }),
  }
  let equivalent : PhysicalEmittedRepresentationTransitionEvent = {
    transition,
    boundary: FunctionResult,
    binding: Some(Temp({ index: 99, })),
    ordinal: None,
    operation: Consumed({ value: 0, }),
  }
  let representative = canonical_transition_event_stream(
    { value: 1, },
    [{ value: 1, }, { value: 2, }],
    [[first], [equivalent]],
    transition_stream_test_body(),
    catalog,
  )
  assert_eq(
    representative.map(entry => {
      let event = entry.1
      (event.transition, event.boundary, event.binding, event.ordinal)
    }),
    [(transition, AtomBinding, Some(Temp({ index: 1, })), None)],
  )
}

///|
test "canonical VM CFG function rejects a transition inconsistent with its operation" {
  let (catalog, transition, different_transition) = transition_stream_test_catalog()
  let event : PhysicalEmittedRepresentationTransitionEvent = {
    transition,
    boundary: AtomBinding,
    binding: None,
    ordinal: None,
    operation: Consumed({ value: 0, }),
  }
  let different = { ..event, transition: different_transition, }
  let result : Result[
    Array[(Int, PhysicalEmittedRepresentationTransitionEvent)],
    LoisvmLoweringError,
  ] = Ok(
    canonical_transition_event_stream(
      { value: 1, },
      [{ value: 1, }, { value: 2, }],
      [[event], [different]],
      transition_stream_test_body(),
      catalog,
    ),
  ) catch {
    error => Err(error)
  }
  guard result
    is Err(
      FunctionProvenanceCompilerDefect(
        TransitionEventMismatch(function~, event~, transition~)
      )
    ) else {
    fail("expected an operation-anchored transition mismatch")
  }
  assert_eq(
    (function, event, transition),
    ({ value: 1, }, 0, different_transition),
  )
}

///|
test "canonical VM CFG function rejects a missing transition stream" {
  let (catalog, transition, _) = transition_stream_test_catalog()
  let event : PhysicalEmittedRepresentationTransitionEvent = {
    transition,
    boundary: AtomBinding,
    binding: None,
    ordinal: None,
    operation: Consumed({ value: 0, }),
  }
  let result : Result[
    Array[(Int, PhysicalEmittedRepresentationTransitionEvent)],
    LoisvmLoweringError,
  ] = Ok(
    canonical_transition_event_stream(
      { value: 1, },
      [{ value: 1, }, { value: 2, }],
      [[event], []],
      transition_stream_test_body(),
      catalog,
    ),
  ) catch {
    error => Err(error)
  }
  assert_true(
    result
    is Err(
      FunctionProvenanceCompilerDefect(
        TransitionEventStreamMismatch(
          function={ value: 1, },
          source={ value: 2, }
        )
      )
    ),
  )
}
