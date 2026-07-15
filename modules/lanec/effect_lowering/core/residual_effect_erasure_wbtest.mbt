///|
test "residual effect erasure preserves extern call structure" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Io),
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Unit), Io),
  )
  let first = metadata.define_value("first", Local, Primitive(Unit))
  let source : @buslane.Program = {
    metadata,
    terms: [
      External(println),
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Let(
            first,
            Call(Ref(println), [Literal(String("first"))]),
            Call(Ref(println), [Literal(String("second"))]),
          ),
        }),
      ),
    ],
  }
  let erased = erase_residual_effects(source)
  debug_inspect(
    erased,
    content=(
      #|{
      #|  metadata: {
      #|    next_unique: 3,
      #|    types: [],
      #|    type_parameters: [],
      #|    values: [
      #|      {
      #|        name: { name_space: ValueName, occurrence: "println", unique: { value: 0 } },
      #|        kind: External,
      #|        type_: Function([Primitive(String)], Primitive(Unit), Empty),
      #|      },
      #|      {
      #|        name: { name_space: ValueName, occurrence: "main", unique: { value: 1 } },
      #|        kind: Function,
      #|        type_: Function([], Primitive(Unit), Empty),
      #|      },
      #|      {
      #|        name: { name_space: ValueName, occurrence: "first", unique: { value: 2 } },
      #|        kind: Local,
      #|        type_: Primitive(Unit),
      #|      },
      #|    ],
      #|    data_constructors: [],
      #|    effects: [],
      #|    operations: [],
      #|  },
      #|  terms: [
      #|    External({ index: 0 }),
      #|    Let(
      #|      { index: 1 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Unit),
      #|          body: Let(
      #|            { index: 2 },
      #|            Call(Ref({ index: 0 }), [Literal(String("first"))]),
      #|            Call(Ref({ index: 0 }), [Literal(String("second"))]),
      #|          ),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
  assert_eq(
    metadata.value_info(println).unwrap().type_,
    Function([Primitive(String)], Primitive(Unit), Empty),
  )
  assert_eq(
    metadata.value_info(main).unwrap().type_,
    Function([], Primitive(Unit), Empty),
  )
  assert_true(@buslane.verify_program(erased).is_ok())
}
