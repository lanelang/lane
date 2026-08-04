///|
test "monadic transformation returns allocation failure without a partial program" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Handled", [])
  let effectful = metadata.define_value(
    "effectful",
    Value,
    Function([], Primitive(I64), Singleton(effect, [])),
  )
  let pure = metadata.define_value(
    "pure",
    Value,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(I64))
  let program : Program = {
    metadata,
    terms: [Let(result, Call(Ref(pure), [Call(Ref(effectful), [])]))],
  }
  metadata.name_allocator = Exhausted
  let metadata_before = metadata.snapshot()
  guard introduce_monadic_binds(program)
    is Err(MetadataAllocationCompilerDefect(cause)) else {
    fail("expected a metadata allocation compiler defect")
  }
  assert_true(cause is MetadataNameExhausted)
  assert_eq(metadata, metadata_before)
}
