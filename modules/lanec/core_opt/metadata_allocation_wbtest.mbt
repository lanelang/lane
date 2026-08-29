///|
test "core optimization returns allocation failure without a partial program" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let helper_type = @buslane.Type::Function(
    [i64_type, i64_type],
    i64_type,
    Empty,
  )
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let ignored = metadata.define_value("ignored", Parameter, i64_type)
  let helper = metadata.define_value("helper", Function, helper_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({
          parameters: [parameter, ignored],
          result_type: i64_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(helper), [Literal(I64(42L)), Literal(I64(0L))]),
        }),
      ),
    ],
  }
  metadata.name_allocator = Fresh(
    @buslane.BuslaneUnique::from_int(2147483647).unwrap(),
  )
  let metadata_before = metadata.snapshot()
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Err(MetadataAllocationCompilerDefect(cause)) else {
    fail("expected a metadata allocation compiler defect")
  }
  assert_true(cause is MetadataNameExhausted)
  assert_eq(metadata, metadata_before)
}
