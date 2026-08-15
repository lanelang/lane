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
    exports: [],
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
fn provider_interface(
  selected_type : @types.Type,
  unrelated_type : @types.Type,
) -> ModuleInterface {
  let interface = {
    ..empty_module_interface("Provider", None),
    values: [
      {
        symbol: { index: 0 },
        kind: Let,
        is_offered: false,
        name: "selected",
        type_: selected_type,
        parameters: None,
        loc: @basic.SourceSpan::dummy(),
      },
      {
        symbol: { index: 1 },
        kind: Let,
        is_offered: false,
        name: "unrelated",
        type_: unrelated_type,
        parameters: None,
        loc: @basic.SourceSpan::dummy(),
      },
    ],
  }
  { ..interface, exports: interface.owned_exports() }
}

///|
fn facade_for_selected(provider : ModuleInterface) -> ModuleInterface {
  for selected in provider.exports {
    if selected.exposed_name == "selected" &&
      selected.export_namespace == ValueNamespace {
      return { ..empty_module_interface("Facade", None), exports: [selected] }
    }
  }
  abort("expected provider export")
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
test "semantic fingerprint result reports invalid interface references" {
  assert_eq(
    invalid_reference_interface().semantic_fingerprint_result(),
    Err("unresolved interface type reference"),
  )
}

///|
test "facade fingerprint tracks only selected provider declarations" {
  let initial = facade_for_selected(
    provider_interface(Primitive(I64), Primitive(Bool)),
  )
  let unrelated_change = facade_for_selected(
    provider_interface(Primitive(I64), Primitive(String)),
  )
  let selected_change = facade_for_selected(
    provider_interface(Primitive(Bool), Primitive(String)),
  )
  assert_eq(
    initial.semantic_fingerprint(),
    unrelated_change.semantic_fingerprint(),
  )
  assert_false(
    initial.semantic_fingerprint() == selected_change.semantic_fingerprint(),
  )
}

///|
test "panic semantic fingerprint rejects invalid interface" {
  invalid_reference_interface().semantic_fingerprint() |> ignore
}
