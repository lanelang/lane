///|
test "core optimizer partially evaluates a known nonrecursive call" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let helper_type = @buslane.Type::Function([int_type], int_type, Empty)
  let parameter = metadata.define_value("value", Parameter, int_type)
  let helper = metadata.define_value("helper", Function, helper_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({
          parameters: [parameter],
          result_type: int_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(Ref(helper), [Literal(Int(42L))]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    Let(
      #|      { index: 2 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Int),
      #|          body: Literal(Int(42)),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer partially evaluates a known generic call" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let type_parameter = metadata.define_type_parameter("A", Type)
  let parameter_type = @buslane.Type::Parameter(type_parameter)
  let identity_type = @buslane.Type::Forall(
    [type_parameter],
    Function([parameter_type], parameter_type, Empty),
  )
  let parameter = metadata.define_value("value", Parameter, parameter_type)
  let identity = metadata.define_value("identity", Function, identity_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        identity,
        TypeLambda(
          [type_parameter],
          Function({
            parameters: [parameter],
            result_type: parameter_type,
            body: Ref(parameter),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(TypeApply(Ref(identity), [TypeArgument(int_type)]), [
            Literal(Int(42L)),
          ]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    Let(
      #|      { index: 2 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Int),
      #|          body: Literal(Int(42)),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer devirtualizes a known dictionary projection" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let operation_type = @buslane.Type::Function([int_type], int_type, Empty)
  let dictionary_type_id = metadata.define_type("Dictionary", [])
  let dictionary_constructor = metadata.define_data_constructor(
    "dictionary",
    dictionary_type_id,
    [],
    [operation_type],
  )
  let dictionary_type = @buslane.Type::Constructor(dictionary_type_id)
  let implementation_parameter = metadata.define_value(
    "input",
    Parameter,
    int_type,
  )
  let implementation = metadata.define_value(
    "implementation",
    Function,
    operation_type,
  )
  let dictionary = metadata.define_value("dictionary", Value, dictionary_type)
  let dictionary_parameter = metadata.define_value(
    "dictionary",
    Parameter,
    dictionary_type,
  )
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    dictionary_type,
  )
  let operation = metadata.define_value(
    "operation",
    MatchBinder,
    operation_type,
  )
  let apply = metadata.define_value(
    "apply",
    Function,
    Function([dictionary_type], int_type, Empty),
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        implementation,
        Function({
          parameters: [implementation_parameter],
          result_type: int_type,
          body: Literal(Int(42L)),
        }),
      ),
      Let(
        dictionary,
        Construct({
          data_constructor: dictionary_constructor,
          type_arguments: [],
          hidden_witnesses: [],
          payloads: [Ref(implementation)],
        }),
      ),
      Let(
        apply,
        Function({
          parameters: [dictionary_parameter],
          result_type: int_type,
          body: Match({
            scrutinee: Ref(dictionary_parameter),
            binder: match_binder,
            result_type: int_type,
            alternatives: [
              {
                alt_constructor: DataCon(dictionary_constructor),
                type_binders: [],
                value_binders: [operation],
                body: Call(Ref(operation), [Literal(Int(0L))]),
              },
            ],
          }),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(Ref(apply), [Ref(dictionary)]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    Let(
      #|      { index: 7 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Int),
      #|          body: Literal(Int(42)),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer does not unfold a recursive call through an alias" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let recurse = metadata.define_value("recurse", Function, function_type)
  let again = metadata.define_value("again", Local, function_type)
  let main = metadata.define_value("main", Function, function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: recurse,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Let(again, Ref(recurse), Call(Ref(again), [])),
          }),
        },
      ]),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(recurse), []),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    LetRec(
      #|      [
      #|        {
      #|          id: { index: 0 },
      #|          rhs: Function(
      #|            {
      #|              parameters: [],
      #|              result_type: Primitive(Unit),
      #|              body: Call(Ref({ index: 0 }), []),
      #|            },
      #|          ),
      #|        },
      #|      ],
      #|    ),
      #|    Let(
      #|      { index: 2 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Unit),
      #|          body: Call(Ref({ index: 0 }), []),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer keeps a known call when its body exceeds the size budget" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let function_type = @buslane.Type::Function([int_type], int_type, Empty)
  let observe = metadata.define_value("observe", External, function_type)
  let helper_parameter = metadata.define_value("value", Parameter, int_type)
  let helper = metadata.define_value("helper", Function, function_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let mut body = @buslane.Expr::Ref(helper_parameter)
  for _ in 0..<64 {
    body = Call(Ref(observe), [body])
  }
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        helper,
        Function({ parameters: [helper_parameter], result_type: int_type, body }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(Ref(helper), [Literal(Int(0L))]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (
      optimized.terms.length(),
      optimized.terms[2],
      @buslane.verify_program(optimized),
    ),
    content=(
      #|(
      #|  3,
      #|  Let(
      #|    { index: 3 },
      #|    Function(
      #|      {
      #|        parameters: [],
      #|        result_type: Primitive(Int),
      #|        body: Call(Ref({ index: 2 }), [Literal(Int(0))]),
      #|      },
      #|    ),
      #|  ),
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer does not unfold a mutually recursive SCC" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let first = metadata.define_value("first", Function, function_type)
  let second = metadata.define_value("second", Function, function_type)
  let main = metadata.define_value("main", Function, function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: first,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(Ref(second), []),
          }),
        },
        {
          id: second,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(Ref(first), []),
          }),
        },
      ]),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(first), []),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    LetRec(
      #|      [
      #|        {
      #|          id: { index: 0 },
      #|          rhs: Function(
      #|            {
      #|              parameters: [],
      #|              result_type: Primitive(Unit),
      #|              body: Call(Ref({ index: 1 }), []),
      #|            },
      #|          ),
      #|        },
      #|        {
      #|          id: { index: 1 },
      #|          rhs: Function(
      #|            {
      #|              parameters: [],
      #|              result_type: Primitive(Unit),
      #|              body: Call(Ref({ index: 0 }), []),
      #|            },
      #|          ),
      #|        },
      #|      ],
      #|    ),
      #|    Let(
      #|      { index: 2 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Unit),
      #|          body: Call(Ref({ index: 0 }), []),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer preserves an escaping callable while specializing its direct call" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let function_type = @buslane.Type::Function([int_type], int_type, Empty)
  let holder_type_id = metadata.define_type("Holder", [])
  let holder_constructor = metadata.define_data_constructor(
    "holder",
    holder_type_id,
    [],
    [function_type],
  )
  let holder_type = @buslane.Type::Constructor(holder_type_id)
  let parameter = metadata.define_value("value", Parameter, int_type)
  let helper = metadata.define_value("helper", Function, function_type)
  let holder = metadata.define_value("holder", Value, holder_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({
          parameters: [parameter],
          result_type: int_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        holder,
        Construct({
          data_constructor: holder_constructor,
          type_arguments: [],
          hidden_witnesses: [],
          payloads: [Ref(helper)],
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(Ref(helper), [Literal(Int(42L))]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [holder] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    Let(
      #|      { index: 1 },
      #|      Function(
      #|        {
      #|          parameters: [{ index: 0 }],
      #|          result_type: Primitive(Int),
      #|          body: Ref({ index: 0 }),
      #|        },
      #|      ),
      #|    ),
      #|    Let(
      #|      { index: 2 },
      #|      Construct(
      #|        {
      #|          data_constructor: { index: 0 },
      #|          type_arguments: [],
      #|          hidden_witnesses: [],
      #|          payloads: [Ref({ index: 1 })],
      #|        },
      #|      ),
      #|    ),
      #|    Let(
      #|      { index: 3 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Int),
      #|          body: Literal(Int(42)),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer keeps dictionary projection behind a dynamic parameter" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let operation_type = @buslane.Type::Function([int_type], int_type, Empty)
  let dictionary_type_id = metadata.define_type("Dictionary", [])
  let dictionary_constructor = metadata.define_data_constructor(
    "dictionary",
    dictionary_type_id,
    [],
    [operation_type],
  )
  let dictionary_type = @buslane.Type::Constructor(dictionary_type_id)
  let dictionary_parameter = metadata.define_value(
    "dictionary",
    Parameter,
    dictionary_type,
  )
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    dictionary_type,
  )
  let operation = metadata.define_value(
    "operation",
    MatchBinder,
    operation_type,
  )
  let apply = metadata.define_value(
    "apply",
    Function,
    Function([dictionary_type], int_type, Empty),
  )
  let consumer_parameter = metadata.define_value(
    "dictionary",
    Parameter,
    dictionary_type,
  )
  let consumer = metadata.define_value(
    "consumer",
    Function,
    Function([dictionary_type], int_type, Empty),
  )
  let apply_body : @buslane.Expr = Function({
    parameters: [dictionary_parameter],
    result_type: int_type,
    body: Match({
      scrutinee: Ref(dictionary_parameter),
      binder: match_binder,
      result_type: int_type,
      alternatives: [
        {
          alt_constructor: DataCon(dictionary_constructor),
          type_binders: [],
          value_binders: [operation],
          body: Call(Ref(operation), [Literal(Int(0L))]),
        },
      ],
    }),
  })
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(apply, apply_body),
      Let(
        consumer,
        Function({
          parameters: [consumer_parameter],
          result_type: int_type,
          body: Call(Ref(apply), [Ref(consumer_parameter)]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: consumer, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    Let(
      #|      { index: 3 },
      #|      Function(
      #|        {
      #|          parameters: [{ index: 0 }],
      #|          result_type: Primitive(Int),
      #|          body: Match(
      #|            {
      #|              scrutinee: Ref({ index: 0 }),
      #|              binder: { index: 1 },
      #|              result_type: Primitive(Int),
      #|              alternatives: [
      #|                {
      #|                  alt_constructor: DataCon({ index: 0 }),
      #|                  type_binders: [],
      #|                  value_binders: [{ index: 2 }],
      #|                  body: Call(Ref({ index: 2 }), [Literal(Int(0))]),
      #|                },
      #|              ],
      #|            },
      #|          ),
      #|        },
      #|      ),
      #|    ),
      #|    Let(
      #|      { index: 5 },
      #|      Function(
      #|        {
      #|          parameters: [{ index: 4 }],
      #|          result_type: Primitive(Int),
      #|          body: Call(Ref({ index: 3 }), [Ref({ index: 4 })]),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}

///|
test "core optimizer materializes a top-level dictionary before devirtualizing it" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let operation_type = @buslane.Type::Function([int_type], int_type, Empty)
  let dictionary_type_id = metadata.define_type("Dictionary", [])
  let dictionary_constructor = metadata.define_data_constructor(
    "dictionary",
    dictionary_type_id,
    [],
    [operation_type],
  )
  let dictionary_type = @buslane.Type::Constructor(dictionary_type_id)
  let implementation_parameter = metadata.define_value(
    "input",
    Parameter,
    int_type,
  )
  let implementation = metadata.define_value(
    "implementation",
    Function,
    operation_type,
  )
  let maker_parameter = metadata.define_value(
    "operation",
    Parameter,
    operation_type,
  )
  let maker = metadata.define_value(
    "make_dictionary",
    Function,
    Function([operation_type], dictionary_type, Empty),
  )
  let dictionary = metadata.define_value("dictionary", Value, dictionary_type)
  let dictionary_parameter = metadata.define_value(
    "dictionary",
    Parameter,
    dictionary_type,
  )
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    dictionary_type,
  )
  let operation = metadata.define_value(
    "operation",
    MatchBinder,
    operation_type,
  )
  let apply = metadata.define_value(
    "apply",
    Function,
    Function([dictionary_type], int_type, Empty),
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], int_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        implementation,
        Function({
          parameters: [implementation_parameter],
          result_type: int_type,
          body: Literal(Int(42L)),
        }),
      ),
      Let(
        maker,
        Function({
          parameters: [maker_parameter],
          result_type: dictionary_type,
          body: Construct({
            data_constructor: dictionary_constructor,
            type_arguments: [],
            hidden_witnesses: [],
            payloads: [Ref(maker_parameter)],
          }),
        }),
      ),
      Let(dictionary, Call(Ref(maker), [Ref(implementation)])),
      Let(
        apply,
        Function({
          parameters: [dictionary_parameter],
          result_type: int_type,
          body: Match({
            scrutinee: Ref(dictionary_parameter),
            binder: match_binder,
            result_type: int_type,
            alternatives: [
              {
                alt_constructor: DataCon(dictionary_constructor),
                type_binders: [],
                value_binders: [operation],
                body: Call(Ref(operation), [Literal(Int(0L))]),
              },
            ],
          }),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: int_type,
          body: Call(Ref(apply), [Ref(dictionary)]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  debug_inspect(
    (optimized.terms, @buslane.verify_program(optimized)),
    content=(
      #|(
      #|  [
      #|    Let(
      #|      { index: 9 },
      #|      Function(
      #|        {
      #|          parameters: [],
      #|          result_type: Primitive(Int),
      #|          body: Literal(Int(42)),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  { diagnostics: [] },
      #|)
    ),
  )
}
