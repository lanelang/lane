///|
test "checked derive preserves traversal substitution and value-use contracts" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let location = SourceSpan::dummy()
  let parameter = registry.define_type_parameter("T", location)
  let deriver_symbol = registry.define_value("deriver", TopLevelValue, location)
  let evidence_symbol = registry.define_value(
    "evidence",
    TopLevelValue,
    location,
  )
  let result_symbol = registry.define_value("derived", TopLevelValue, location)
  let abi_type = registry.define_type("Abi", Struct, 0, location)
  let abi_field = registry.define_field(abi_type, "field", 0, location)
  let abi_variant = registry.define_variant(abi_type, "variant", 0, 0, location)
  let parameter_type = @types.Type::Parameter(parameter)
  let deriver = CheckedExpr::Value(
    name="deriver",
    symbol=deriver_symbol,
    type_=parameter_type,
    loc=location,
  )
  let evidence = CheckedExpr::Value(
    name="evidence",
    symbol=evidence_symbol,
    type_=parameter_type,
    loc=location,
  )
  let abi : CheckedDeriveAbi = {
    deriver: abi_type,
    deriver_unit: abi_field,
    deriver_product: abi_field,
    deriver_void: abi_field,
    deriver_sum: abi_field,
    deriver_field: abi_field,
    deriver_variant: abi_field,
    deriver_record: abi_field,
    deriver_enumeration: abi_field,
    product: abi_type,
    product_head: abi_field,
    product_tail: abi_field,
    sum: abi_type,
    sum_here: abi_variant,
    sum_there: abi_variant,
    iso: abi_type,
    type_info: abi_type,
    field_info: abi_type,
    variant_info: abi_type,
    void_type: abi_type,
  }
  let expression = CheckedExpr::Derive(
    plan={
      capability: parameter_type,
      target: parameter_type,
      representation: parameter_type,
      abi,
      shape: Record(fields=[
        { symbol: abi_field, name: "value", type_: parameter_type },
      ]),
      deriver,
      evidence: [
        { path: "Item.value", required_type: parameter_type, value: evidence },
      ],
      metadata: { name: "Item", qualified_name: "Test.Item" },
    },
    type_=parameter_type,
    loc=location,
  )

  let children = []
  expression.for_each_child_expr(fn(child) { children.push(child) })
  assert_eq(children, [deriver, evidence])

  let substitution = @types.TypeSubstitution::single(parameter, Primitive(Int))
  assert_eq(
    expression.substitute(substitution),
    Derive(
      plan={
        capability: Primitive(Int),
        target: Primitive(Int),
        representation: Primitive(Int),
        abi,
        shape: Record(fields=[
          { symbol: abi_field, name: "value", type_: Primitive(Int) },
        ]),
        deriver: Value(
          name="deriver",
          symbol=deriver_symbol,
          type_=Primitive(Int),
          loc=location,
        ),
        evidence: [
          {
            path: "Item.value",
            required_type: Primitive(Int),
            value: Value(
              name="evidence",
              symbol=evidence_symbol,
              type_=Primitive(Int),
              loc=location,
            ),
          },
        ],
        metadata: { name: "Item", qualified_name: "Test.Item" },
      },
      type_=Primitive(Int),
      loc=location,
    ),
  )

  let source = CheckedSourceFile::{
    module_path: { components: ["Test"], loc: location },
    declarations: [
      Let({
        is_public: false,
        is_offered: false,
        symbol: result_symbol,
        name: "derived",
        name_loc: location,
        initializer: expression,
        type_: parameter_type,
        loc: location,
      }),
    ],
    loc: location,
  }
  assert_eq(source.value_use_analysis(registry), {
    binders: [],
    references: [
      { target: deriver_symbol, origin_binder: None, loc: location },
      { target: evidence_symbol, origin_binder: None, loc: location },
    ],
  })
}
