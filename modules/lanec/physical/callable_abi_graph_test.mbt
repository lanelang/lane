///|
test "physical callable ABI graph interns complete nested contracts" {
  let graph = @physical.CallableAbiGraph::new()
  let scalar : @physical.ValueAbi = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
  }
  let leaf = graph.intern({
    witnesses: [],
    parameters: [Value(scalar)],
    result: Value(scalar),
  })
  let same_leaf = graph.intern({
    witnesses: [],
    parameters: [Value(scalar)],
    result: Value(scalar),
  })
  let parent = graph.intern({
    witnesses: [],
    parameters: [Callable(leaf)],
    result: Unit,
  })
  assert_eq(leaf, same_leaf)
  assert_false(parent == leaf)
}
