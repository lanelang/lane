///|
fn core_opt_test_program() -> (@buslane.Program, @buslane.ValueId) {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  (
    {
      metadata,
      terms: [
        Let(
          main,
          Function({
            parameters: [],
            result_type: unit_type,
            body: Literal(Unit),
          }),
        ),
      ],
    },
    main,
  )
}

///|
test "core optimizer preserves a verified program and explicit roots" {
  let (program, main) = core_opt_test_program()
  guard optimize({ program, entry: main, roots: [main] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized == program, @buslane.verify_program(optimized).is_ok()),
    content="(true, true)",
  )
}

///|
test "core optimizer rejects an unknown optimization root" {
  let (program, main) = core_opt_test_program()
  debug_inspect(
    optimize({ program, entry: main, roots: [{ index: 1 }] }),
    content="Err(UnknownRoot({ index: 1 }))",
  )
}

///|
test "core optimizer eliminates compatible top-level and local aliases" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let target = metadata.define_value("target", External, function_type)
  let top_alias = metadata.define_value("top_alias", Value, function_type)
  let local_alias = metadata.define_value("local_alias", Local, function_type)
  let main = metadata.define_value("main", Function, function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(target),
      Let(top_alias, Ref(target)),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(local_alias, Ref(top_alias), Call(Ref(local_alias), [])),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.terms,
    content=(
      #|[
      #|  External({ index: 0 }),
      #|  Let(
      #|    { index: 3 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(Unit),
      #|        body: Call(Ref({ index: 0 }), []),
      #|      },
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "core optimizer removes dead pure lets but preserves effectful calls" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let io_function_type = @buslane.Type::Function([], unit_type, Io)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let println = metadata.define_value("println", External, io_function_type)
  let dead = metadata.define_value("dead", Local, unit_type)
  let observed = metadata.define_value("observed", Local, unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(println),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            dead,
            Literal(Unit),
            Let(observed, Call(Ref(println), []), Literal(Unit)),
          ),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.terms,
    content=(
      #|[
      #|  External({ index: 0 }),
      #|  Let(
      #|    { index: 3 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(Unit),
      #|        body: Let({ index: 2 }, Call(Ref({ index: 0 }), []), Literal(Unit)),
      #|      },
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "core optimizer reduces trivial beta calls and known constructor matches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let box_type = metadata.define_type("Box", [])
  let box_constructor = metadata.define_data_constructor("box", box_type, [], [
    int_type,
  ])
  let box_value_type = @buslane.Type::Constructor(box_type)
  let parameter = metadata.define_value("parameter", Parameter, int_type)
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    box_value_type,
  )
  let field = metadata.define_value("field", MatchBinder, int_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: int_type,
              body: Match({
                scrutinee: Construct({
                  data_constructor: box_constructor,
                  type_arguments: [],
                  hidden_witnesses: [],
                  payloads: [Ref(parameter)],
                }),
                binder: match_binder,
                result_type: int_type,
                alternatives: [
                  {
                    alt_constructor: DataCon(box_constructor),
                    type_binders: [],
                    value_binders: [field],
                    body: Ref(field),
                  },
                ],
              }),
            }),
            [Literal(Int(42L))],
          ),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.terms,
    content=(
      #|[
      #|  Let(
      #|    { index: 3 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(Int),
      #|        body: Literal(Int(42)),
      #|      },
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "core optimizer specializes a concrete generic dictionary chain" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let element_type = @buslane.Type::Parameter(element)
  let bool_type = @buslane.Type::Primitive(Bool)
  let equal_function = @buslane.Type::Function(
    [element_type, element_type],
    bool_type,
    Empty,
  )
  let equal_type = metadata.define_type("Equal", [element])
  let equal_constructor = metadata.define_data_constructor(
    "Equal",
    equal_type,
    [],
    [equal_function, equal_function],
  )
  let equal_instance = @buslane.Type::Apply(Constructor(equal_type), [
    TypeArgument(element_type),
  ])
  let int_type = @buslane.Type::Primitive(Int)
  let int_equal_type = @buslane.Type::Function(
    [int_type, int_type],
    bool_type,
    Empty,
  )
  let intrinsic = metadata.define_value("%i64_equal", External, int_equal_type)
  let make_parameter = metadata.define_value("equal", Parameter, equal_function)
  let make = metadata.define_value(
    "make_equal",
    Function,
    Forall([element], Function([equal_function], equal_instance, Empty)),
  )
  let receiver = metadata.define_value("receiver", Parameter, equal_instance)
  let match_binder = metadata.define_value(
    "matched_equal",
    MatchBinder,
    equal_instance,
  )
  let field = metadata.define_value("equal_field", MatchBinder, equal_function)
  let inverse_field = metadata.define_value(
    "not_equal_field",
    MatchBinder,
    equal_function,
  )
  let accessor = metadata.define_value(
    "equal",
    Function,
    Forall([element], Function([equal_instance], equal_function, Empty)),
  )
  let left = metadata.define_value("left", Parameter, element_type)
  let right = metadata.define_value("right", Parameter, element_type)
  let dictionary = metadata.define_value(
    "dictionary",
    Parameter,
    equal_instance,
  )
  let operation = metadata.define_value(
    "op_equal",
    Function,
    Forall(
      [element],
      Function([element_type, element_type, equal_instance], bool_type, Empty),
    ),
  )
  let int_equal_instance = @buslane.Type::Apply(Constructor(equal_type), [
    TypeArgument(int_type),
  ])
  let int_dictionary = metadata.define_value(
    "int_equal_ops",
    Value,
    int_equal_instance,
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], bool_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(intrinsic),
      Let(
        make,
        TypeLambda(
          [element],
          Function({
            parameters: [make_parameter],
            result_type: equal_instance,
            body: Construct({
              data_constructor: equal_constructor,
              type_arguments: [TypeArgument(element_type)],
              hidden_witnesses: [],
              payloads: [Ref(make_parameter), Ref(make_parameter)],
            }),
          }),
        ),
      ),
      Let(
        accessor,
        TypeLambda(
          [element],
          Function({
            parameters: [receiver],
            result_type: equal_function,
            body: Match({
              scrutinee: Ref(receiver),
              binder: match_binder,
              result_type: equal_function,
              alternatives: [
                {
                  alt_constructor: DataCon(equal_constructor),
                  type_binders: [],
                  value_binders: [field, inverse_field],
                  body: Ref(field),
                },
              ],
            }),
          }),
        ),
      ),
      Let(
        operation,
        TypeLambda(
          [element],
          Function({
            parameters: [left, right, dictionary],
            result_type: bool_type,
            body: Call(
              Call(TypeApply(Ref(accessor), [TypeArgument(element_type)]), [
                Ref(dictionary),
              ]),
              [Ref(left), Ref(right)],
            ),
          }),
        ),
      ),
      Let(
        int_dictionary,
        Call(TypeApply(Ref(make), [TypeArgument(int_type)]), [Ref(intrinsic)]),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: bool_type,
          body: Call(TypeApply(Ref(operation), [TypeArgument(int_type)]), [
            Literal(Int(1L)),
            Literal(Int(2L)),
            Ref(int_dictionary),
          ]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.terms,
    content=(
      #|[
      #|  External({ index: 0 }),
      #|  Let(
      #|    { index: 13 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(Bool),
      #|        body: Call(Ref({ index: 0 }), [Literal(Int(1)), Literal(Int(2))]),
      #|      },
      #|    ),
      #|  ),
      #|]
    ),
  )
}
