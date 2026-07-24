///|
test "panic semantic analysis rejects missing value metadata" {
  required_value_metadata(SymbolRegistry(), { index: 0 }) |> ignore
}

///|
test "panic semantic tokens reject missing value metadata" {
  semantic_token_kind_for_value(SymbolRegistry(), { index: 0 }) |> ignore
}
