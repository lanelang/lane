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
        is_offered: false,
        name: "value",
        type_: Constructor(missing_type),
        tuple_presentations: [],
        parameters: None,
        loc: @basic.SourceSpan::dummy(),
      },
    ],
  }
}

///|
fn generic_identity_interface(binder_name : String) -> ModuleInterface {
  let parameter : @types.TypeParameter = {
    id: { index: 0 },
    name: binder_name,
    kind: Type,
  }
  {
    ..empty_module_interface("A", None),
    values: [
      {
        symbol: { index: 0 },
        kind: Function,
        is_offered: false,
        name: "identity",
        type_: Forall(
          [parameter],
          Function([Parameter(parameter.id)], Parameter(parameter.id), Empty),
        ),
        tuple_presentations: [],
        parameters: Some([
          {
            symbol: { index: 1 },
            is_auto: false,
            is_offered: false,
            name: "value",
            type_: Parameter(parameter.id),
            loc: @basic.SourceSpan::dummy(),
          },
        ]),
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
test "semantic fingerprint includes offeredness" {
  let ordinary = generic_identity_interface("T")
  let offered = {
    ..ordinary,
    values: ordinary.values.map(fn(value) { { ..value, is_offered: true } }),
  }
  assert_false(
    ordinary.semantic_fingerprint() == offered.semantic_fingerprint(),
  )
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
test "presentation fingerprint tracks generic binder names" {
  let with_t = generic_identity_interface("T")
  let with_u = generic_identity_interface("U")
  assert_eq(with_t.semantic_fingerprint(), with_u.semantic_fingerprint())
  assert_false(
    with_t.presentation_fingerprint() == with_u.presentation_fingerprint(),
  )
}

///|
test "tuple presentation changes only presentation fingerprint" {
  let nominal = generic_identity_interface("T")
  let tuple = {
    ..nominal,
    values: nominal.values.map(fn(value) {
      {
        ..value,
        tuple_presentations: [{ path: [FunctionResult], item_count: 2 }],
      }
    }),
  }
  assert_eq(nominal.semantic_fingerprint(), tuple.semantic_fingerprint())
  assert_false(
    nominal.presentation_fingerprint() == tuple.presentation_fingerprint(),
  )
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
