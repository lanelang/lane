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
test "generated values have registry metadata" {
  let registry = SymbolRegistry()
  let generated = registry.define_generated_local("_generated", loc())
  debug_inspect(
    registry.value_metadata(generated),
    content=(
      #|Some(
      #|  {
      #|    id: { index: 0 },
      #|    name: "_generated",
      #|    kind: LocalBinding,
      #|    provenance: GeneratedLocal,
      #|    loc: {
      #|      start_offset: 0,
      #|      end_offset: 0,
      #|      start_line: 1,
      #|      start_column: 1,
      #|      end_line: 1,
      #|      end_column: 1,
      #|    },
      #|  },
      #|)
    ),
  )
}

///|
test "measurement registries use a temporary identity namespace" {
  let registry = SymbolRegistry()
  registry.define_value("existing", TopLevelValue, loc()) |> ignore
  let measurement = registry.measurement_registry()
  let other_measurement = registry.measurement_registry()
  let type_ = measurement.define_type("Temporary", Struct, 0, loc())
  let type_alias = measurement.define_type_alias("TemporaryAlias", loc())
  let type_parameter = measurement.define_type_parameter("T", loc())
  let effect = measurement.define_effect("TemporaryEffect", 0, loc())
  let value = measurement.define_value("first", LocalBinding, loc())
  let symbols = [
    SymbolId::Type(type_),
    SymbolId::TypeAlias(type_alias),
    SymbolId::TypeParameter(type_parameter),
    SymbolId::TypeMember(
      measurement.define_type_member(type_, "T", 0, type_parameter, loc()),
    ),
    SymbolId::Value(value),
    SymbolId::Field(measurement.define_field(type_, "field", 0, loc())),
    SymbolId::Variant(measurement.define_variant(type_, "variant", 0, 0, loc())),
    SymbolId::Effect(effect),
    SymbolId::Operation(
      measurement.define_operation(effect, "operation", 0, 0, loc()),
    ),
  ]
  debug_inspect(
    symbols,
    content=(
      #|[
      #|  Type({ index: -1 }),
      #|  TypeAlias({ index: -2 }),
      #|  TypeParameter({ index: -3 }),
      #|  TypeMember({ index: -6 }),
      #|  Value({ index: -5 }),
      #|  Field({ index: -7 }),
      #|  Variant({ index: -8 }),
      #|  Effect({ index: -4 }),
      #|  Operation({ index: -9 }),
      #|]
    ),
  )
  let second = other_measurement.define_value("second", LocalBinding, loc())
  let persistent = registry.define_value("persistent", TopLevelValue, loc())
  assert_eq(
    (persistent, second, registry.value_metadata(value)),
    (ValueSymbolId::{ index: 1 }, ValueSymbolId::{ index: -10 }, None),
  )
}

///|
test "declaration scopes keep stable identities across revisions" {
  let allocator = SymbolIdentityAllocator()
  let first_registry = allocator.registry()
  let first = first_registry.declaration_scope()
  let first_type = first.define_type("Item", Struct, 0, loc())
  let first_alias = first.define_type_alias("Number", loc())
  let first_parameter = first_registry.define_type_parameter("T", loc())
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
  let revised_registry = allocator.registry()
  let revised = revised_registry.declaration_scope(
    previous=Some(first_registry.declaration_identities()),
  )
  let revised_type = revised.define_type("Item", Struct, 0, loc())
  let revised_alias = revised.define_type_alias("Number", loc())
  let revised_parameter = revised_registry.define_type_parameter("T", loc())
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
  let other_type = allocator
    .registry()
    .declaration_scope()
    .define_type("Item", Struct, 0, loc())
  let other_alias = allocator
    .registry()
    .declaration_scope()
    .define_type_alias("Number", loc())
  debug_inspect(
    [
      first_type == revised_type,
      first_alias == revised_alias,
      first_type_member == revised_type_member,
      first_value == revised_value,
      first_effect == revised_effect,
      first_field == revised_field,
      first_variant == revised_variant,
      first_operation == revised_operation,
      first_type == other_type,
      first_alias == other_alias,
    ],
    content="[true, true, true, true, true, true, true, true, false, false]",
  )
}

///|
test "declaration revisions release removed scoped names" {
  let allocator = SymbolIdentityAllocator()
  let first_registry = allocator.registry()
  let first = first_registry
    .declaration_scope()
    .define_value("before", TopLevelValue, loc())
  let second_registry = allocator.registry()
  second_registry
  .declaration_scope(previous=Some(first_registry.declaration_identities()))
  .define_value("after", TopLevelValue, loc())
  |> ignore
  let third_registry = allocator.registry()
  let third = third_registry
    .declaration_scope(previous=Some(second_registry.declaration_identities()))
    .define_value("before", TopLevelValue, loc())
  assert_false(first == third)
  assert_true(third_registry.value_metadata(first) is None)
}
