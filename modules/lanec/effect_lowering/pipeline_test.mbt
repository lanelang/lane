///|
test "effect lowering exposes snapshots without transitional IR" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let answer = metadata.define_value(
    "answer",
    Function,
    Function([], unit_type, Empty),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      Let(
        answer,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Literal(Unit),
        }),
      ),
    ],
  }
  let snapshots = []
  let lowered = lower_effects_observed(source, snapshot => {
    snapshots.push(snapshot)
  }).unwrap()
  assert_true(@buslane.verify_program(lowered).is_ok())
  assert_eq(lower_effects(source), Ok(lowered))
  debug_inspect(
    snapshots,
    content=(
      #|[
      #|  {
      #|    stage: HandlersElaborated,
      #|    text: "let value#0 = fn() -> Unit {\n  ()\n}",
      #|    scale: { top_terms: 1, functions: 1, nodes: 3, calls: 0 },
      #|  },
      #|  {
      #|    stage: MonadicTransformed,
      #|    text: "let value#0 = fn() -> Unit {\n  ()\n}",
      #|    scale: { top_terms: 1, functions: 1, nodes: 3, calls: 0 },
      #|  },
      #|  {
      #|    stage: SelectiveCpsRewritten,
      #|    text: "let value#0 = fn() -> Unit {\n  ()\n}",
      #|    scale: { top_terms: 1, functions: 1, nodes: 3, calls: 0 },
      #|  },
      #|  {
      #|    stage: OpenContextsResolved,
      #|    text: "let value#0 = fn() -> Unit {\n  ()\n}",
      #|    scale: { top_terms: 1, functions: 1, nodes: 3, calls: 0 },
      #|  },
      #|]
    ),
  )
}

///|
test "effect lowering rejects an unverified Buslane input" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value("answer", Value, Primitive(Unit))
  let source : @buslane.Program = {
    metadata,
    terms: [Let(answer, Literal(I64(42L)))],
  }
  guard lower_effects(source) is Err(InvalidProgram(stage~, result~)) else {
    fail("expected invalid input to be rejected")
  }
  assert_eq(stage, Input)
  assert_false(result.is_ok())
}
