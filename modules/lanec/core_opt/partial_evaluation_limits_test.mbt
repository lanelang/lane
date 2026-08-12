///|
fn optimized_main_body(
  optimized : @buslane.Program,
  main : @buslane.ValueId,
) -> @buslane.Expr {
  for term in optimized.terms {
    if term is Let(value, Function(function)) && value == main {
      return function.body
    }
  }
  abort("expected optimized main function")
}

///|
test "core optimizer evaluates every profitable call to one callee" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let identity_type = @buslane.Type::Function([i64_type], i64_type, Empty)
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let identity = metadata.define_value("identity", Function, identity_type)
  let payload_types = Array::make(8, i64_type)
  let result_type_id = metadata.define_type("Eight", [])
  let result_constructor = metadata.define_data_constructor(
    "eight",
    result_type_id,
    [],
    payload_types,
  )
  let result_type = @buslane.Type::Constructor(result_type_id)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], result_type, Empty),
  )
  let payloads = []
  for index in 0..<8 {
    payloads.push(
      @buslane.Expr::Call(Ref(identity), [Literal(I64(index.to_int64()))]),
    )
  }
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        identity,
        Function({
          parameters: [parameter],
          result_type: i64_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type,
          body: Construct({
            data_constructor: result_constructor,
            type_arguments: [],
            hidden_witnesses: [],
            payloads,
          }),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_main_body(optimized, main) is Construct(construct) else {
    fail("expected optimized aggregate construction")
  }
  assert_eq(optimized.terms.length(), 1)
  assert_eq(construct.payloads.length(), 8)
  for index, payload in construct.payloads {
    assert_eq(payload, Literal(I64(index.to_int64())))
  }
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer does not impose a fixed whole-program expansion count" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let identity_type = @buslane.Type::Function([i64_type], i64_type, Empty)
  let payload_types = Array::make(80, i64_type)
  let result_type_id = metadata.define_type("Eighty", [])
  let result_constructor = metadata.define_data_constructor(
    "eighty",
    result_type_id,
    [],
    payload_types,
  )
  let result_type = @buslane.Type::Constructor(result_type_id)
  let terms : Array[@buslane.TopTerm] = []
  let calls : Array[@buslane.Expr] = []
  for index in 0..<80 {
    let parameter = metadata.define_value("value", Parameter, i64_type)
    let identity = metadata.define_value("identity", Function, identity_type)
    terms.push(
      Let(
        identity,
        Function({
          parameters: [parameter],
          result_type: i64_type,
          body: Ref(parameter),
        }),
      ),
    )
    calls.push(Call(Ref(identity), [Literal(I64(index.to_int64()))]))
  }
  let main = metadata.define_value(
    "main",
    Function,
    Function([], result_type, Empty),
  )
  terms.push(
    Let(
      main,
      Function({
        parameters: [],
        result_type,
        body: Construct({
          data_constructor: result_constructor,
          type_arguments: [],
          hidden_witnesses: [],
          payloads: calls,
        }),
      }),
    ),
  )
  let program : @buslane.Program = { metadata, terms }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_main_body(optimized, main) is Construct(construct) else {
    fail("expected optimized aggregate construction")
  }
  assert_eq(optimized.terms.length(), 1)
  assert_eq(construct.payloads.length(), 80)
  for index, payload in construct.payloads {
    assert_eq(payload, Literal(I64(index.to_int64())))
  }
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer judges profitability after contextual reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let choice_type_id = metadata.define_type("Choice", [])
  let choose = metadata.define_data_constructor("choose", choice_type_id, [], [])
  let reject = metadata.define_data_constructor("reject", choice_type_id, [], [])
  let choice_type = @buslane.Type::Constructor(choice_type_id)
  let choice_value = metadata.define_value("choice", Value, choice_type)
  let parameter = metadata.define_value("choice", Parameter, choice_type)
  let helper = metadata.define_value(
    "helper",
    Function,
    Function([choice_type], i64_type, Empty),
  )
  let mut body = @buslane.Expr::Literal(I64(42L))
  for _ in 0..<24 {
    let binder = metadata.define_value("choice", MatchBinder, choice_type)
    body = Match({
      scrutinee: Ref(parameter),
      binder,
      result_type: i64_type,
      alternatives: [
        {
          alt_constructor: DataCon(choose),
          type_binders: [],
          value_binders: [],
          body,
        },
        {
          alt_constructor: DataCon(reject),
          type_binders: [],
          value_binders: [],
          body: Literal(I64(0L)),
        },
      ],
    })
  }
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        choice_value,
        Construct({
          data_constructor: choose,
          type_arguments: [],
          hidden_witnesses: [],
          payloads: [],
        }),
      ),
      Let(
        helper,
        Function({ parameters: [parameter], result_type: i64_type, body }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(helper), [Ref(choice_value)]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(optimized.terms.length(), 1)
  assert_eq(optimized_main_body(optimized, main), Literal(I64(42L)))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer revisits dependents until semantic facts stabilize" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let choice_type_id = metadata.define_type("Choice", [])
  let zero = metadata.define_data_constructor("zero", choice_type_id, [], [])
  let one = metadata.define_data_constructor("one", choice_type_id, [], [])
  let choice_type = @buslane.Type::Constructor(choice_type_id)
  let step_parameter = metadata.define_value("choice", Parameter, choice_type)
  let step_binder = metadata.define_value("choice", MatchBinder, choice_type)
  let step = metadata.define_value(
    "step",
    Function,
    Function([choice_type], choice_type, Empty),
  )
  let decode_parameter = metadata.define_value("choice", Parameter, choice_type)
  let decode_binder = metadata.define_value("choice", MatchBinder, choice_type)
  let decode = metadata.define_value(
    "decode",
    Function,
    Function([choice_type], i64_type, Empty),
  )
  let seed = metadata.define_value("seed", Value, choice_type)
  let first = metadata.define_value("first", Value, choice_type)
  let second = metadata.define_value("second", Value, choice_type)
  let third = metadata.define_value("third", Value, choice_type)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let construct = fn(data_con) {
    @buslane.Expr::Construct({
      data_constructor: data_con,
      type_arguments: [],
      hidden_witnesses: [],
      payloads: [],
    })
  }
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        step,
        Function({
          parameters: [step_parameter],
          result_type: choice_type,
          body: Match({
            scrutinee: Ref(step_parameter),
            binder: step_binder,
            result_type: choice_type,
            alternatives: [
              {
                alt_constructor: DataCon(zero),
                type_binders: [],
                value_binders: [],
                body: construct(one),
              },
              {
                alt_constructor: DataCon(one),
                type_binders: [],
                value_binders: [],
                body: construct(zero),
              },
            ],
          }),
        }),
      ),
      Let(
        decode,
        Function({
          parameters: [decode_parameter],
          result_type: i64_type,
          body: Match({
            scrutinee: Ref(decode_parameter),
            binder: decode_binder,
            result_type: i64_type,
            alternatives: [
              {
                alt_constructor: DataCon(zero),
                type_binders: [],
                value_binders: [],
                body: Literal(I64(0L)),
              },
              {
                alt_constructor: DataCon(one),
                type_binders: [],
                value_binders: [],
                body: Literal(I64(1L)),
              },
            ],
          }),
        }),
      ),
      Let(seed, construct(zero)),
      Let(first, Call(Ref(step), [Ref(seed)])),
      Let(second, Call(Ref(step), [Ref(first)])),
      Let(third, Call(Ref(step), [Ref(second)])),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(decode), [Ref(third)]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry: main, roots: [] }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(optimized.terms.length(), 1)
  assert_eq(optimized_main_body(optimized, main), Literal(I64(1L)))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "inline executor defers calls exposed by a clone to the next plan" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unary = @buslane.Type::Function([i64_type], i64_type, Empty)
  let leaf_parameter = metadata.define_value("value", Parameter, i64_type)
  let leaf = metadata.define_value("leaf", Function, unary)
  let outer_parameter = metadata.define_value("value", Parameter, i64_type)
  let outer = metadata.define_value("outer", Function, unary)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], i64_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        leaf,
        Function({
          parameters: [leaf_parameter],
          result_type: i64_type,
          body: Ref(leaf_parameter),
        }),
      ),
      Let(
        outer,
        Function({
          parameters: [outer_parameter],
          result_type: i64_type,
          body: Call(Ref(leaf), [Ref(outer_parameter)]),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(outer), [Literal(I64(42L))]),
        }),
      ),
    ],
  }
  let observations : Array[CoreOptimizationObservation] = []
  guard optimize_observed({ program, entry: main, roots: [] }, observation => {
      observations.push(observation)
    })
    is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  let accepted = observations.filter_map(observation => {
    match observation {
      ApplicationAccepted(site=KnownCallable(value), ..) => Some(value)
      _ => None
    }
  })
  assert_eq(accepted, [leaf, outer, leaf])
  assert_eq(optimized_main_body(optimized, main), Literal(I64(42L)))
  assert_true(@buslane.verify_program(optimized).is_ok())
}
