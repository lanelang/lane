///|
fn empty_module_interface(
  module_path : String,
  source_id : String?,
  hints? : Array[OptimizationHint] = [],
) -> ModuleInterface {
  {
    module_path,
    source_id,
    type_references: [],
    effect_references: [],
    types: [],
    effects: [],
    type_aliases: [],
    values: [],
    optimization_hints: hints,
  }
}

///|
fn invalid_reference_interface() -> ModuleInterface {
  let missing_type : @symbol.TypeSymbolId = { index: 0 }
  {
    ..empty_module_interface("A", None),
    values: [
      {
        symbol: { index: 0 },
        kind: Let,
        name: "value",
        type_: Constructor(missing_type),
        parameters: None,
        loc: @basic.SourceSpan::dummy(),
      },
    ],
  }
}

///|
test "semantic fingerprint ignores source identity" {
  let old_fingerprint = empty_module_interface("A", Some("old-A.lane")).semantic_fingerprint()
  let new_fingerprint = empty_module_interface("A", Some("new-A.lane")).semantic_fingerprint()
  assert_eq(old_fingerprint, new_fingerprint)
}

///|
test "semantic fingerprint tracks exported semantics" {
  let initial = empty_module_interface("A", None).semantic_fingerprint()
  let changed_hint = empty_module_interface("A", None, hints=[
    { name: "specialize" },
  ]).semantic_fingerprint()
  let changed_module = empty_module_interface("B", None).semantic_fingerprint()
  assert_false(initial == changed_hint)
  assert_false(initial == changed_module)
}

///|
test "semantic fingerprint result reports invalid interface references" {
  assert_eq(
    invalid_reference_interface().semantic_fingerprint_result(),
    Err("unresolved interface type reference"),
  )
}

///|
test "panic semantic fingerprint rejects invalid interface" {
  invalid_reference_interface().semantic_fingerprint() |> ignore
}
