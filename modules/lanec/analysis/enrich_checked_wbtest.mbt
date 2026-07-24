///|
test "panic semantic analysis rejects missing value metadata" {
  required_value_metadata(SymbolRegistry(), { index: 0 }) |> ignore
}

///|
test "panic semantic tokens reject missing value metadata" {
  semantic_token_kind_for_value(SymbolRegistry(), { index: 0 }) |> ignore
}

///|
test "semantic tokens exclude generated locals by provenance" {
  let registry : @symbol.SymbolRegistry = SymbolRegistry()
  let generated = registry.define_generated_local(
    "_generated",
    @basic.SourceSpan::dummy(),
  )
  assert_eq(semantic_token_kind_for_value(registry, generated), None)
}
