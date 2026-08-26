///|
fn test_callable_value_abi() -> @bytecode.ValueAbi {
  { representation: I64, cleanup: OwnedCallable, kind: CallableValue, }
}

///|
test "recursive callable contracts are canonicalized by bisimulation" {
  let graph = PhysicalCallableContractCatalog::new()
  let left = graph.reserve()
  let right = graph.reserve()
  graph.fill(left, {
    witnesses: [],
    parameters: [Callable(right)],
    result: Unit,
  })
  graph.fill(right, {
    witnesses: [],
    parameters: [Callable(left)],
    result: Unit,
  })
  let identities = graph.canonicalize()
  assert_eq(identities[0], identities[1])
  assert_eq(graph.canonical_identity(left), graph.canonical_identity(right))
  graph.verify()
  debug_inspect(
    graph.contract(identities[0]),
    content="{ witnesses: [], parameters: [Callable({ index: 0 })], result: Unit }",
  )
}

///|
test "recursive callable contracts preserve observable ABI differences" {
  let graph = PhysicalCallableContractCatalog::new()
  let left = graph.reserve()
  let right = graph.reserve()
  graph.fill(left, {
    witnesses: [],
    parameters: [Callable(left)],
    result: Unit,
  })
  graph.fill(right, {
    witnesses: [],
    parameters: [Callable(right)],
    result: Value(test_callable_value_abi()),
  })
  let identities = graph.canonicalize()
  assert_true(identities[0] != identities[1])
  graph.verify()
}

///|
test "recursive canonicalization preserves published contract identities" {
  let graph = PhysicalCallableContractCatalog::new()
  let existing = graph.intern({
    witnesses: [],
    parameters: [Value(test_callable_value_abi())],
    result: Unit,
  })
  let left = graph.reserve()
  let right = graph.reserve()
  graph.fill(left, {
    witnesses: [],
    parameters: [Callable(right)],
    result: Unit,
  })
  graph.fill(right, {
    witnesses: [],
    parameters: [Callable(left)],
    result: Unit,
  })
  let identities = graph.canonicalize()
  assert_eq(identities[existing.index], existing)
  assert_eq(graph.intern(graph.contract(existing)), existing)
  graph.verify()
}

///|
test "bisimilar contract aliases do not require a callable adapter" {
  let image = test_image_lowerer(@buslane.MetadataRegistry::MetadataRegistry())
  let left = image.callable_contracts.reserve()
  let right = image.callable_contracts.reserve()
  image.callable_contracts.fill(left, {
    witnesses: [],
    parameters: [Callable(right)],
    result: Unit,
  })
  image.callable_contracts.fill(right, {
    witnesses: [],
    parameters: [Callable(left)],
    result: Unit,
  })
  ignore(image.callable_contracts.canonicalize())
  let semantic = @anf.RuntimeType::Callable([], Unit)
  let interface = fn(invocation) -> PhysicalCallableInterface {
    {
      evidence_parameters: [],
      evidence_arguments: [],
      parameter_types: [],
      result_type: Unit,
      invocation,
      callable_target: None,
      parameters: [],
      parameter_callable_targets: [],
      result_callable_target: None,
    }
  }
  assert_true(
    image.plan_callable_adaptation_with_interfaces(
      semantic,
      semantic,
      RuntimeSubstitution::new(),
      interface(left),
      interface(right),
    )
    is None,
  )
}

///|
test "callable contract graph rejects incomplete recursive nodes" {
  let graph = PhysicalCallableContractCatalog::new()
  ignore(graph.reserve())
  try graph.canonicalize() catch {
    RepresentationSpecializationInvariant(detail~) =>
      inspect(
        detail,
        content="callable-contract graph cannot be frozen with an incomplete node",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected incomplete callable-contract graph to fail")
  }
}
