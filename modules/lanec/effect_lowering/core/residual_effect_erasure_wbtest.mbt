///|
test "residual effect erasure preserves extern call structure" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Unit), Builtin(Io)),
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
      #|    name_allocator: Fresh({ value: 3 }),
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

///|
test "residual effect erasure clears external effect rows at its boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let vector_op = metadata.define_effect("VectorOp", [], flavor=External)
  let vector_get = metadata.define_value(
    "vector_get",
    External,
    Function([Primitive(I64)], Primitive(I64), Singleton(vector_op, [])),
  )
  let erased = erase_residual_effects({
    metadata,
    terms: [External(vector_get)],
  })
  debug_inspect(
    (
      erased.metadata.effect_info(vector_op).map(info => info.flavor),
      erased.metadata.value_info(vector_get).map(info => info.type_),
    ),
    content=(
      #|(
      #|  Some(External),
      #|  Some(Function([Primitive(I64)], Primitive(I64), Empty)),
      #|)
    ),
  )
}
