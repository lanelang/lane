///|
test "runtime contract preserves a missing declaration as a typed ABI error" {
  let contract = CanonicalBasicAbiRuntimeContract::from_void_type(
    Some({ index: 0, }),
  )
  guard contract.certify([], MetadataRegistry()) is Err(error) else {
    fail("missing canonical Void declaration unexpectedly certified")
  }
  assert_true(error is MissingDeclaration(provider=Void))
  debug_inspect(
    error.object_diagnostic("Broken"),
    content=(
      #|{
      #|  source_id: None,
      #|  message: "invalid canonical Basic ABI in module object `Broken`",
      #|  span: None,
      #|  severity: Error,
      #|  code: Some("E4208"),
      #|  labels: [],
      #|  notes: [
      #|    "canonical Basic provider `Basic.Data.Void.Void` is not bound to the certified runtime identity",
      #|    "module objects must carry the certified canonical Basic runtime contract before identity remapping begins",
      #|  ],
      #|  helps: ["recompile the module object from valid Lane source"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
    ),
  )
}
