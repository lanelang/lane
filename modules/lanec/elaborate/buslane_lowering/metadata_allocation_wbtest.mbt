///|
test "lowering preserves metadata allocation failures without partial externals" {
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  lowerer.metadata.name_allocator = Exhausted
  let metadata_before = lowerer.metadata.snapshot()
  try lowerer.define_external("host", Primitive(Unit)) catch {
    MetadataAllocationCompilerDefect(cause) =>
      assert_true(cause is MetadataNameExhausted)
    error => fail("unexpected lowering error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a metadata allocation compiler defect")
  }
  assert_eq((lowerer.metadata, lowerer.external_terms), (metadata_before, []))
}
