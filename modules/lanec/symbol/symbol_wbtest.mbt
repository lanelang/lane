///|
fn loc() -> SourceSpan {
  SourceSpan::dummy()
}

///|
test "symbol registry pretty prints separated identities" {
  let registry = SymbolRegistry()
  let point = registry.define_type("Point", Struct, 0, loc())
  let option = registry.define_type("Option", Enum, 1, loc())
  registry.define_type_parameter("A", loc()) |> ignore
  let hidden = registry.define_type_parameter("T", loc())
  registry.define_type_member(point, "T", 0, hidden, loc()) |> ignore
  registry.define_value("unwrap_or", TopLevelFunction, loc()) |> ignore
  registry.define_value("fallback", Parameter, loc()) |> ignore
  registry.define_field(point, "x", 0, loc()) |> ignore
  registry.define_field(point, "y", 1, loc()) |> ignore
  registry.define_variant(option, "none", 0, 0, loc()) |> ignore
  registry.define_variant(option, "some", 1, 1, loc()) |> ignore
  inspect(
    @prettyprinter.render(registry),
    content=(
      #|symbols {
      #|  types {
      #|    type#0 struct Point/0
      #|    type#1 enum Option/1
      #|  }
      #|  type_parameters {
      #|    tparam#0 A
      #|    tparam#1 T
      #|  }
      #|  type_members {
      #|    tmember#0 owner=type#0 parameter=tparam#1 T index=0
      #|  }
      #|  values {
      #|    value#0 top_function unwrap_or
      #|    value#1 parameter fallback
      #|  }
      #|  fields {
      #|    field#0 owner=type#0 x index=0
      #|    field#1 owner=type#0 y index=1
      #|  }
      #|  variants {
      #|    variant#0 owner=type#1 none index=0 payloads=0
      #|    variant#1 owner=type#1 some index=1 payloads=1
      #|  }
      #|}
    ),
  )
}

///|
test "symbol registry looks up owned metadata" {
  let registry = SymbolRegistry()
  let option = registry.define_type("Option", Enum, 1, loc())
  let some = registry.define_variant(option, "some", 1, 1, loc())
  inspect(
    @prettyprinter.render(registry.variant_metadata(some)),
    content="Some(variant#0 owner=type#0 some index=1 payloads=1)",
  )
}

///|
test "declaration scopes keep stable identities across revisions" {
  let registry = SymbolRegistry()
  let first = registry.declaration_scope("A")
  let first_type = first.define_type("Item", Struct, 0, loc())
  let first_parameter = registry.define_type_parameter("T", loc())
  let first_type_member = first.define_type_member(
    first_type,
    "T",
    0,
    first_parameter,
    loc(),
  )
  let first_value = first.define_value("make", TopLevelFunction, loc())
  let first_effect = first.define_effect("Read", 0, loc())
  let first_field = first.define_field(first_type, "value", 0, loc())
  let first_variant = first.define_variant(first_type, "item", 0, 1, loc())
  let first_operation = first.define_operation(
    first_effect,
    "read",
    0,
    0,
    loc(),
  )
  let revised = registry.declaration_scope("A")
  let revised_type = revised.define_type("Item", Struct, 0, loc())
  let revised_parameter = registry.define_type_parameter("T", loc())
  let revised_type_member = revised.define_type_member(
    revised_type,
    "T",
    0,
    revised_parameter,
    loc(),
  )
  let revised_value = revised.define_value("make", TopLevelFunction, loc())
  let revised_effect = revised.define_effect("Read", 0, loc())
  let revised_field = revised.define_field(revised_type, "value", 0, loc())
  let revised_variant = revised.define_variant(
    revised_type,
    "item",
    0,
    1,
    loc(),
  )
  let revised_operation = revised.define_operation(
    revised_effect,
    "read",
    0,
    0,
    loc(),
  )
  let other_type = registry
    .declaration_scope("B")
    .define_type("Item", Struct, 0, loc())
  debug_inspect(
    [
      first_type == revised_type,
      first_type_member == revised_type_member,
      first_value == revised_value,
      first_effect == revised_effect,
      first_field == revised_field,
      first_variant == revised_variant,
      first_operation == revised_operation,
      first_type == other_type,
    ],
    content="[true, true, true, true, true, true, true, false]",
  )
}
