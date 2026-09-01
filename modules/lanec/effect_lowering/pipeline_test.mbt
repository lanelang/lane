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
  let verified = source.certify().unwrap()
  let snapshots = []
  let lowered = lower_effects_observed(verified, snapshot => {
    snapshots.push(snapshot)
  }).unwrap()
  assert_true(@buslane.verify_program(lowered.program().program()).is_ok())
  assert_eq(lower_effects(verified), Ok(lowered))
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
test "invalid Buslane cannot enter effect lowering" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value("answer", Value, Primitive(Unit))
  let source : @buslane.Program = {
    metadata,
    terms: [Let(answer, Literal(I64(42L)))],
  }
  guard source.certify() is Err(result) else {
    fail("expected Buslane certification to reject invalid input")
  }
  assert_false(result.is_ok())
}
