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
  let checked_evidence : CheckedDeriveEvidence = {
    path: "Item.value",
    required_type: parameter_type,
    value: evidence,
  }
  let field : CheckedDeriveField = { symbol: abi_field, name: "value" }
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
      abi,
      shape: Record(
        product=CheckedDeriveProduct::make(abi_type, [
          (field, parameter_type, checked_evidence),
        ]),
      ),
      deriver,
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
        abi,
        shape: Record(
          product=CheckedDeriveProduct::make(abi_type, [
            (
              field,
              Primitive(Int),
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
            ),
          ]),
        ),
        deriver: Value(
          name="deriver",
          symbol=deriver_symbol,
          type_=Primitive(Int),
          loc=location,
        ),
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

///|
test "checked derive recipe owns right-nested product and sum representations" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let location = SourceSpan::dummy()
  let product = registry.define_type("Product", Struct, 0, location)
  let sum = registry.define_type("Sum", Enum, 0, location)
  let void_type = registry.define_type("Void", Enum, 0, location)
  let first = registry.define_field(product, "first", 0, location)
  let second = registry.define_field(product, "second", 1, location)
  let variant = registry.define_variant(sum, "variant", 0, 0, location)
  let empty_variant = registry.define_variant(sum, "empty", 1, 0, location)
  let evidence_for = fn(path : String, type_ : @types.Type) {
    CheckedDeriveEvidence::{
      path,
      required_type: type_,
      value: ErrorRecovery(type_~, loc=location),
    }
  }
  let payload = CheckedDeriveProduct::make(product, [
    ((), Primitive(Int), evidence_for("item[0]", Primitive(Int))),
    ((), Primitive(Bool), evidence_for("item[1]", Primitive(Bool))),
  ])
  let checked_sum = CheckedDeriveSum::make(sum, void_type, [
    { symbol: variant, name: "item", payload },
    {
      symbol: empty_variant,
      name: "empty",
      payload: CheckedDeriveProduct::make(product, []),
    },
  ])
  debug_inspect(
    (
      CheckedDeriveProduct::make(product, [
        (
          CheckedDeriveField::{ symbol: first, name: "first" },
          Primitive(Int),
          evidence_for("first", Primitive(Int)),
        ),
        (
          { symbol: second, name: "second" },
          Primitive(Bool),
          evidence_for("second", Primitive(Bool)),
        ),
      ]),
      checked_sum,
    ),
    content=(
      #|(
      #|  {
      #|    representation: Apply(
      #|      Constructor({ index: 0 }),
      #|      [
      #|        TypeArgument(Primitive(Int)),
      #|        TypeArgument(
      #|          Apply(
      #|            Constructor({ index: 0 }),
      #|            [TypeArgument(Primitive(Bool)), TypeArgument(Primitive(Unit))],
      #|          ),
      #|        ),
      #|      ],
      #|    ),
      #|    steps: [
      #|      {
      #|        head: { symbol: { index: 0 }, name: "first" },
      #|        head_type: Primitive(Int),
      #|        tail_type: Apply(
      #|          Constructor({ index: 0 }),
      #|          [TypeArgument(Primitive(Bool)), TypeArgument(Primitive(Unit))],
      #|        ),
      #|        evidence: {
      #|          path: "first",
      #|          required_type: Primitive(Int),
      #|          value: ErrorRecovery(
      #|            type_=Primitive(Int),
      #|            loc={
      #|              start_offset: 0,
      #|              end_offset: 0,
      #|              start_line: 1,
      #|              start_column: 1,
      #|              end_line: 1,
      #|              end_column: 1,
      #|            },
      #|          ),
      #|        },
      #|      },
      #|      {
      #|        head: { symbol: { index: 1 }, name: "second" },
      #|        head_type: Primitive(Bool),
      #|        tail_type: Primitive(Unit),
      #|        evidence: {
      #|          path: "second",
      #|          required_type: Primitive(Bool),
      #|          value: ErrorRecovery(
      #|            type_=Primitive(Bool),
      #|            loc={
      #|              start_offset: 0,
      #|              end_offset: 0,
      #|              start_line: 1,
      #|              start_column: 1,
      #|              end_line: 1,
      #|              end_column: 1,
      #|            },
      #|          ),
      #|        },
      #|      },
      #|    ],
      #|  },
      #|  {
      #|    representation: Apply(
      #|      Constructor({ index: 1 }),
      #|      [
      #|        TypeArgument(
      #|          Apply(
      #|            Constructor({ index: 0 }),
      #|            [
      #|              TypeArgument(Primitive(Int)),
      #|              TypeArgument(
      #|                Apply(
      #|                  Constructor({ index: 0 }),
      #|                  [TypeArgument(Primitive(Bool)), TypeArgument(Primitive(Unit))],
      #|                ),
      #|              ),
      #|            ],
      #|          ),
      #|        ),
      #|        TypeArgument(
      #|          Apply(
      #|            Constructor({ index: 1 }),
      #|            [
      #|              TypeArgument(Primitive(Unit)),
      #|              TypeArgument(Constructor({ index: 2 })),
      #|            ],
      #|          ),
      #|        ),
      #|      ],
      #|    ),
      #|    steps: [
      #|      {
      #|        head: {
      #|          symbol: { index: 0 },
      #|          name: "item",
      #|          payload: {
      #|            representation: Apply(
      #|              Constructor({ index: 0 }),
      #|              [
      #|                TypeArgument(Primitive(Int)),
      #|                TypeArgument(
      #|                  Apply(
      #|                    Constructor({ index: 0 }),
      #|                    [TypeArgument(Primitive(Bool)), TypeArgument(Primitive(Unit))],
      #|                  ),
      #|                ),
      #|              ],
      #|            ),
      #|            steps: [
      #|              {
      #|                head: (),
      #|                head_type: Primitive(Int),
      #|                tail_type: Apply(
      #|                  Constructor({ index: 0 }),
      #|                  [TypeArgument(Primitive(Bool)), TypeArgument(Primitive(Unit))],
      #|                ),
      #|                evidence: {
      #|                  path: "item[0]",
      #|                  required_type: Primitive(Int),
      #|                  value: ErrorRecovery(
      #|                    type_=Primitive(Int),
      #|                    loc={
      #|                      start_offset: 0,
      #|                      end_offset: 0,
      #|                      start_line: 1,
      #|                      start_column: 1,
      #|                      end_line: 1,
      #|                      end_column: 1,
      #|                    },
      #|                  ),
      #|                },
      #|              },
      #|              {
      #|                head: (),
      #|                head_type: Primitive(Bool),
      #|                tail_type: Primitive(Unit),
      #|                evidence: {
      #|                  path: "item[1]",
      #|                  required_type: Primitive(Bool),
      #|                  value: ErrorRecovery(
      #|                    type_=Primitive(Bool),
      #|                    loc={
      #|                      start_offset: 0,
      #|                      end_offset: 0,
      #|                      start_line: 1,
      #|                      start_column: 1,
      #|                      end_line: 1,
      #|                      end_column: 1,
      #|                    },
      #|                  ),
      #|                },
      #|              },
      #|            ],
      #|          },
      #|        },
      #|        tail_type: Apply(
      #|          Constructor({ index: 1 }),
      #|          [
      #|            TypeArgument(Primitive(Unit)),
      #|            TypeArgument(Constructor({ index: 2 })),
      #|          ],
      #|        ),
      #|      },
      #|      {
      #|        head: {
      #|          symbol: { index: 1 },
      #|          name: "empty",
      #|          payload: { representation: Primitive(Unit), steps: [] },
      #|        },
      #|        tail_type: Constructor({ index: 2 }),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}
