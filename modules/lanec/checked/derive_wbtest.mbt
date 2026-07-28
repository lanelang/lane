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
  let generated_symbol = registry.define_generated_local(
    "_derive_expansion", location,
  )
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
  let iso = CheckedExpr::Literal(
    literal=Unit,
    type_=Primitive(Unit),
    loc=location,
  )
  let expansion = CheckedExpr::Value(
    name="_derive_expansion",
    symbol=generated_symbol,
    type_=parameter_type,
    loc=location,
  )
  let expression = CheckedExpr::Derive(
    plan={
      capability: parameter_type,
      target: parameter_type,
      representation: parameter_type,
      deriver,
      evidence: [
        { path: "Item.value", required_type: parameter_type, value: evidence },
      ],
      metadata: { name: "Item", qualified_name: "Test.Item" },
      iso,
      expansion,
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
        iso,
        expansion: Value(
          name="_derive_expansion",
          symbol=generated_symbol,
          type_=Primitive(Int),
          loc=location,
        ),
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
