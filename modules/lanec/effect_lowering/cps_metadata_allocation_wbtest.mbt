///|
test "selective CPS returns allocation failure without a partial rewrite" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  ignore(metadata.define_type_parameter("E", Effect))
  metadata.name_allocator = Exhausted
  let metadata_before = metadata.snapshot()
  guard rewrite_selective_cps_abis({ metadata, terms: [], })
    is Err(MetadataAllocationCompilerDefect(cause)) else {
    fail("expected a metadata allocation compiler defect")
  }
  assert_true(cause is MetadataNameExhausted)
  assert_eq(metadata, metadata_before)
}
