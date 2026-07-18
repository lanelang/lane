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
