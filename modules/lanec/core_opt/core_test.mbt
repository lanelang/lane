///|
fn core_opt_test_program() -> (@buslane.Program, @buslane.ValueId) raise @buslane.MetadataAllocationError {
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
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [main],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (
      optimized.program() == program,
      @buslane.verify_program(optimized.program()).is_ok(),
    ),
    content="(true, true)",
  )
}

///|
test "core optimizer rejects an unknown optimization root" {
  let (program, main) = core_opt_test_program()
  debug_inspect(
    optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [{ index: 1, }],
    }),
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
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.program().terms,
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
  let io_function_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let main_type = @buslane.Type::Function([], unit_type, Builtin(Io))
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
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.program().terms,
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
test "core optimizer removes an unused empty-effect call" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let pure_function_type = @buslane.Type::Function([], unit_type, Empty)
  let pure = metadata.define_value("pure", External, pure_function_type)
  let dead = metadata.define_value("dead", Local, unit_type)
  let main = metadata.define_value("main", Function, pure_function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(pure),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(dead, Call(Ref(pure), []), Literal(Unit)),
        }),
      ),
    ],
  }
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.program().terms,
    content=(
      #|[
      #|  Let(
      #|    { index: 2 },
      #|    Function({ parameters: [], result_type: Primitive(Unit), body: Literal(Unit) }),
      #|  ),
      #|]
    ),
  )
}

///|
test "core optimizer reduces trivial beta calls and known constructor matches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let box_type = metadata.define_type("Box", [])
  let box_constructor = metadata.define_data_constructor("box", box_type, [], [
    i64_type,
  ])
  let box_value_type = @buslane.Type::Constructor(box_type)
  let parameter = metadata.define_value("parameter", Parameter, i64_type)
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    box_value_type,
  )
  let field = metadata.define_value("field", MatchBinder, i64_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: i64_type,
              body: Match({
                scrutinee: Construct({
                  data_constructor: box_constructor,
                  type_arguments: [],
                  hidden_witnesses: [],
                  payloads: [Ref(parameter)],
                }),
                binder: match_binder,
                result_type: i64_type,
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
            [Literal(I64(42L))],
          ),
        }),
      ),
    ],
  }
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.program().terms,
    content=(
      #|[
      #|  Let(
      #|    { index: 3 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(I64),
      #|        body: Literal(I64(42)),
      #|      },
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "core optimizer reduces a constructor match through a pure binding spine" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let box_type = metadata.define_type("Box", [])
  let box_constructor = metadata.define_data_constructor("box", box_type, [], [
    i64_type,
  ])
  let box_value_type = @buslane.Type::Constructor(box_type)
  let local_box = metadata.define_value("local_box", Local, box_value_type)
  let boxed = metadata.define_value("boxed", Value, box_value_type)
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    box_value_type,
  )
  let field = metadata.define_value("field", MatchBinder, i64_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let constructed = @buslane.Expr::Construct({
    data_constructor: box_constructor,
    type_arguments: [],
    hidden_witnesses: [],
    payloads: [Literal(I64(42L))],
  })
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(boxed, Let(local_box, constructed, Ref(local_box))),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Match({
            scrutinee: Ref(boxed),
            binder: match_binder,
            result_type: i64_type,
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
      ),
    ],
  }
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    optimized.program().terms,
    content=(
      #|[
      #|  Let(
      #|    { index: 4 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(I64),
      #|        body: Literal(I64(42)),
      #|      },
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "core optimizer scalar-replaces local projections without reordering payloads" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let pair_type = metadata.define_type("Pair", [])
  let pair_constructor = metadata.define_data_constructor(
    "pair",
    pair_type,
    [],
    [i64_type, i64_type],
  )
  let pair_value_type = @buslane.Type::Constructor(pair_type)
  let observe_type = @buslane.Type::Function([], i64_type, Builtin(Io))
  let observe_left = metadata.define_value(
    "observe_left",
    External,
    observe_type,
  )
  let observe_right = metadata.define_value(
    "observe_right",
    External,
    observe_type,
  )
  let add = metadata.define_value(
    "add",
    External,
    Function([i64_type, i64_type], i64_type, Empty),
  )
  let pair = metadata.define_value("pair", Local, pair_value_type)
  let matched = metadata.define_value("matched", MatchBinder, pair_value_type)
  let left = metadata.define_value("left", MatchBinder, i64_type)
  let right = metadata.define_value("right", MatchBinder, i64_type)
  let left_result = metadata.define_value("left_result", Local, i64_type)
  let matched_again = metadata.define_value(
    "matched_again",
    MatchBinder,
    pair_value_type,
  )
  let left_again = metadata.define_value("left_again", MatchBinder, i64_type)
  let right_again = metadata.define_value("right_again", MatchBinder, i64_type)
  let right_result = metadata.define_value("right_result", Local, i64_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Builtin(Io)),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe_left),
      External(observe_right),
      External(add),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Let(
            pair,
            Construct({
              data_constructor: pair_constructor,
              type_arguments: [],
              hidden_witnesses: [],
              payloads: [
                Call(Ref(observe_left), []),
                Call(Ref(observe_right), []),
              ],
            }),
            Let(
              left_result,
              Match({
                scrutinee: Ref(pair),
                binder: matched,
                result_type: i64_type,
                alternatives: [
                  {
                    alt_constructor: DataCon(pair_constructor),
                    type_binders: [],
                    value_binders: [left, right],
                    body: Ref(left),
                  },
                ],
              }),
              Let(
                right_result,
                Match({
                  scrutinee: Ref(pair),
                  binder: matched_again,
                  result_type: i64_type,
                  alternatives: [
                    {
                      alt_constructor: DataCon(pair_constructor),
                      type_binders: [],
                      value_binders: [left_again, right_again],
                      body: Ref(right_again),
                    },
                  ],
                }),
                Call(Ref(add), [Ref(left_result), Ref(right_result)]),
              ),
            ),
          ),
        }),
      ),
    ],
  }
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized.program().terms
    is [
      External(actual_left),
      External(actual_right),
      External(actual_add),
      Let(
        _,
        Function(
          {
            body: Let(
              actual_left_field,
              Call(Ref(left_callee), []),
              Let(
                actual_right_field,
                Call(Ref(right_callee), []),
                Call(Ref(add_callee), [Ref(left_argument), Ref(right_argument)])
              )
            ),
            ..
          }
        )
      ),
    ] else {
    fail("expected ordered scalar field bindings")
  }
  assert_eq(
    (
      actual_left, actual_right, actual_add, actual_left_field, actual_right_field,
      left_callee, right_callee, add_callee, left_argument, right_argument,
    ),
    (
      observe_left, observe_right, add, left, right, observe_left, observe_right,
      add, left, right,
    ),
  )
  assert_true(@buslane.verify_program(optimized.program()).is_ok())
}

///|
test "core optimizer retains a local aggregate that escapes its match boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let box_type = metadata.define_type("Box", [])
  let box_constructor = metadata.define_data_constructor("box", box_type, [], [
    i64_type,
  ])
  let box_value_type = @buslane.Type::Constructor(box_type)
  let consume = metadata.define_value(
    "consume",
    External,
    Function([box_value_type], i64_type, Empty),
  )
  let box = metadata.define_value("box", Local, box_value_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(consume),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Let(
            box,
            Construct({
              data_constructor: box_constructor,
              type_arguments: [],
              hidden_witnesses: [],
              payloads: [Literal(I64(42L))],
            }),
            Call(Ref(consume), [Ref(box)]),
          ),
        }),
      ),
    ],
  }
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized.program().terms
    is [
      External(_),
      Let(_, Function({ body: Let(_, Construct(_), Call(_, _)), .. })),
    ] else {
    fail("expected escaping aggregate allocation to remain")
  }
}

///|
test "core cleanup shares identical pure local initializers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let item = metadata.define_type("Item", [])
  let make_item = metadata.define_data_constructor("item", item, [], [])
  let item_type = @buslane.Type::Constructor(item)
  let pair = metadata.define_type("Pair", [])
  let make_pair = metadata.define_data_constructor("pair", pair, [], [
    item_type, item_type,
  ])
  let pair_type = @buslane.Type::Constructor(pair)
  let left = metadata.define_value("left", Local, item_type)
  let right = metadata.define_value("right", Local, item_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], pair_type, Empty),
  )
  let item_value = @buslane.Expr::Construct({
    data_constructor: make_item,
    type_arguments: [],
    hidden_witnesses: [],
    payloads: [],
  })
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: pair_type,
          body: Let(
            left,
            item_value,
            Let(
              right,
              item_value,
              Construct({
                data_constructor: make_pair,
                type_arguments: [],
                hidden_witnesses: [],
                payloads: [Ref(left), Ref(right)],
              }),
            ),
          ),
        }),
      ),
    ],
  }
  guard optimize({
      program: program.certify().unwrap(),
      entry: main,
      roots: [],
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized.program().terms
    is [
      Let(
        _,
        Function(
          { body: Let(retained, Construct(_), Construct({ payloads, .. })), .. }
        )
      ),
    ] else {
    fail("expected one shared local initializer")
  }
  assert_eq(retained, left)
  assert_eq(payloads, [Ref(left), Ref(left)])
  assert_true(@buslane.verify_program(optimized.program()).is_ok())
}
