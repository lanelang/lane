///|
fn int_type() -> @buslane.Type {
  Primitive(Int)
}

///|
fn expect_ok(program : @buslane.Program) -> Unit raise {
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "external value reference stays opaque" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let external = metadata.define_value(External, int_type())
  let result = metadata.define_value(Value, int_type())
  let program = @buslane.Program::{
    metadata,
    terms: [External(external), Let(result, Ref(external))],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  assert_false(evaluated.lookup(result).is_function())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="external_value value#0",
  )
}

///|
test "external callable call invokes resolved native function" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let external = metadata.define_value(
    External,
    Function([int_type()], int_type()),
  )
  let result = metadata.define_value(Value, int_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(external),
      Let(result, Call(Ref(external), [Literal(Int(40L))])),
    ],
  }
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    external value#0 : (Int) -> Int
      #|    value value#1 : Int
      #|  }
      #|  external value#0
      #|  let value#1 = value#0(40)
      #|}
    ),
  )
  expect_ok(program)
  let runtime = BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_resolver((id, _type) => {
    if id != external {
      abort("unexpected Buslane external")
    }
    BuslaneRuntimeValue::native_function(arguments => {
      guard arguments.length() == 1 && arguments[0].as_int() == Some(40L) else {
        abort("unexpected Buslane external arguments")
      }
      BuslaneRuntimeValue::int(42L)
    })
  })
  let evaluated = evaluate_buslane_program(program, runtime)
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 42",
  )
}

///|
test "pretty recursive closure environment stays finite" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let box_type = metadata.define_type([])
  let function_type = @buslane.Type::Function([], int_type())
  let box = metadata.define_data_constructor(box_type, [], [function_type])
  let function = metadata.define_value(Function, function_type)
  let boxed = metadata.define_value(Value, Constructor(box_type))
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [],
            result_type: int_type(),
            body: Literal(Int(1L)),
          }),
        },
      ]),
      Let(
        boxed,
        Construct({
          data_constructor: box,
          type_arguments: [],
          hidden_witnesses: [],
          payloads: [Ref(function)],
        }),
      ),
    ],
  }
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(boxed), width=80),
    content=(
      #|data_value datacon#0 {
      #|  <function>
      #|}
    ),
  )
}

///|
test "data constructor match selects matching alternative" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter(Type)
  let option = metadata.define_type([parameter])
  let none = metadata.define_data_constructor(option, [], [])
  let some = metadata.define_data_constructor(option, [], [Parameter(parameter)])
  let option_int = @buslane.Type::Apply(Constructor(option), [int_type()])
  let scrutinee = metadata.define_value(Value, option_int)
  let binder = metadata.define_value(MatchBinder, option_int)
  let payload = metadata.define_value(MatchBinder, int_type())
  let result = metadata.define_value(Value, int_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: some,
          type_arguments: [int_type()],
          hidden_witnesses: [],
          payloads: [Literal(Int(7L))],
        }),
      ),
      Let(
        result,
        Match({
          scrutinee: Ref(scrutinee),
          binder,
          result_type: int_type(),
          alternatives: [
            {
              alt_constructor: DataCon(none),
              type_binders: [],
              value_binders: [],
              body: Literal(Int(0L)),
            },
            {
              alt_constructor: DataCon(some),
              type_binders: [],
              value_binders: [payload],
              body: Ref(payload),
            },
          ],
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(program.terms[1], width=100),
    content=(
      #|let value#3 = match value#0 as value#1 -> Int {
      #|  datacon#0() => 0
      #|  datacon#1(value#2) => value#2
      #|}
    ),
  )
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 7",
  )
}

///|
test "evaluation rejects invalid program" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value(Value, int_type())
  let program = @buslane.Program::{
    metadata,
    terms: [Let(value, Literal(Bool(true)))],
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected Int
      #|    actual Bool
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(
      try {
        ignore(evaluate_buslane_program(program, BuslaneExternalRuntime()))
        abort("expected invalid program")
      } catch {
        error => error
      },
      width=100,
    ),
    content=(
      #|invalid_program {
      #|  type_mismatch {
      #|    expected Int
      #|    actual Bool
      #|  }
      #|}
    ),
  )
}
