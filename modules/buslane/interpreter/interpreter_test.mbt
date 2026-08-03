///|
fn i64_type() -> @buslane.Type {
  Primitive(I64)
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
test "handler operation arm can directly produce a result" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let final_binder = metadata.define_value("value", Local, i64_type())
  let payload = metadata.define_value("value", Parameter, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([i64_type()], i64_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: print,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(I64(41L))],
          }),
          result_binder: final_binder,
          result_type: i64_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(console, []),
              operations: [
                {
                  operation: print,
                  type_binders: [],
                  payload_binders: [payload],
                  resume_binder,
                  body: Ref(payload),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 41
    ),
  )
}

///|
test "nested handlers dispatch to the nearest matching operation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let outer_effect = metadata.define_effect("Effect", [])
  let inner_effect = metadata.define_effect("Effect", [])
  let outer_operation = metadata.define_operation(
    "op",
    outer_effect,
    [],
    [i64_type()],
    i64_type(),
  )
  let inner_operation = metadata.define_operation(
    "op",
    inner_effect,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let outer_final = metadata.define_value("value", Local, i64_type())
  let inner_final = metadata.define_value("value", Local, i64_type())
  let outer_payload = metadata.define_value("value", Parameter, i64_type())
  let inner_payload = metadata.define_value("value", Parameter, i64_type())
  let outer_resume = metadata.define_value(
    "value",
    Parameter,
    Function([i64_type()], i64_type(), Empty),
  )
  let inner_resume = metadata.define_value(
    "value",
    Parameter,
    Function([i64_type()], i64_type(), Singleton(outer_effect, [])),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Handle({
            body: Perform({
              operation: inner_operation,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [Literal(I64(17L))],
            }),
            result_binder: inner_final,
            result_type: i64_type(),
            final_body: Ref(inner_final),
            handlers: [
              {
                handled_effect: Singleton(inner_effect, []),
                operations: [
                  {
                    operation: inner_operation,
                    type_binders: [],
                    payload_binders: [inner_payload],
                    resume_binder: inner_resume,
                    body: Perform({
                      operation: outer_operation,
                      effect_arguments: [],
                      hidden_witnesses: [],
                      payloads: [Ref(inner_payload)],
                    }),
                  },
                ],
              },
            ],
          }),
          result_binder: outer_final,
          result_type: i64_type(),
          final_body: Ref(outer_final),
          handlers: [
            {
              handled_effect: Singleton(outer_effect, []),
              operations: [
                {
                  operation: outer_operation,
                  type_binders: [],
                  payload_binders: [outer_payload],
                  resume_binder: outer_resume,
                  body: Ref(outer_payload),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 17
    ),
  )
}

///|
test "resume reinstalls the same deep handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let first = metadata.define_value("value", Local, i64_type())
  let final_binder = metadata.define_value("value", Local, i64_type())
  let payload = metadata.define_value("value", Parameter, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([i64_type()], i64_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Let(
            first,
            Perform({
              operation: print,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [Literal(I64(1L))],
            }),
            Perform({
              operation: print,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [Ref(first)],
            }),
          ),
          result_binder: final_binder,
          result_type: i64_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(console, []),
              operations: [
                {
                  operation: print,
                  type_binders: [],
                  payload_binders: [payload],
                  resume_binder,
                  body: Call(Resume(resume_binder), [Ref(payload)]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 1
    ),
  )
}

///|
test "resume continuation is multi-shot" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let ignored = metadata.define_value("value", Local, i64_type())
  let final_binder = metadata.define_value("value", Local, i64_type())
  let payload = metadata.define_value("value", Parameter, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([i64_type()], i64_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: print,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(I64(0L))],
          }),
          result_binder: final_binder,
          result_type: i64_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(console, []),
              operations: [
                {
                  operation: print,
                  type_binders: [],
                  payload_binders: [payload],
                  resume_binder,
                  body: Let(
                    ignored,
                    Call(Resume(resume_binder), [Literal(I64(1L))]),
                    Call(Resume(resume_binder), [Literal(I64(2L))]),
                  ),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 2
    ),
  )
}

///|
test "external value reference stays opaque" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let external = metadata.define_value("value", External, i64_type())
  let result = metadata.define_value("value", Value, i64_type())
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
    "value",
    External,
    Function([i64_type()], i64_type(), Empty),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(external),
      Let(result, Call(Ref(external), [Literal(I64(40L))])),
    ],
  }
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    external value#0 : (I64) -> I64
      #|    value value#1 : I64
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
      guard arguments.length() == 1 && arguments[0].as_i64() == Some(40L) else {
        abort("unexpected Buslane external arguments")
      }
      BuslaneRuntimeValue::i64(42L)
    })
  })
  let evaluated = evaluate_buslane_program(program, runtime)
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 42
    ),
  )
}

///|
test "pretty recursive closure environment stays finite" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let box_type = metadata.define_type("Type", [])
  let function_type = @buslane.Type::Function([], i64_type(), Empty)
  let box = metadata.define_data_constructor("Con", box_type, [], [
    function_type,
  ])
  let function = metadata.define_value("value", Function, function_type)
  let boxed = metadata.define_value("value", Value, Constructor(box_type))
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [],
            result_type: i64_type(),
            body: Literal(I64(1L)),
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
test "recursive group closures see later bindings from same group" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let function_type = @buslane.Type::Function([], i64_type(), Empty)
  let first = metadata.define_value("value", Function, function_type)
  let second = metadata.define_value("value", Function, function_type)
  let result = metadata.define_value("value", Value, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: first,
          rhs: Function({
            parameters: [],
            result_type: i64_type(),
            body: Call(Ref(second), []),
          }),
        },
        {
          id: second,
          rhs: Function({
            parameters: [],
            result_type: i64_type(),
            body: Literal(I64(42L)),
          }),
        },
      ]),
      Let(result, Call(Ref(first), [])),
    ],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 42
    ),
  )
}

///|
test "closure capture ignores later child frame shadowing" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let first = metadata.define_value("value", Local, i64_type())
  let captured = metadata.define_value(
    "value",
    Local,
    Function([], i64_type(), Empty),
  )
  let shadow = metadata.define_value("value", Local, i64_type())
  let result = metadata.define_value("value", Value, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Let(
          first,
          Literal(I64(1L)),
          Let(
            captured,
            Function({
              parameters: [],
              result_type: i64_type(),
              body: Ref(first),
            }),
            Let(shadow, Literal(I64(2L)), Call(Ref(captured), [])),
          ),
        ),
      ),
    ],
  }
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 1
    ),
  )
}

///|
test "data constructor match selects matching alternative" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let option = metadata.define_type("Type", [parameter])
  let none = metadata.define_data_constructor("Con", option, [], [])
  let some = metadata.define_data_constructor("Con", option, [], [
    Parameter(parameter),
  ])
  let option_int = @buslane.Type::Apply(Constructor(option), [
    TypeArgument(i64_type()),
  ])
  let scrutinee = metadata.define_value("value", Value, option_int)
  let binder = metadata.define_value("value", MatchBinder, option_int)
  let payload = metadata.define_value("value", MatchBinder, i64_type())
  let result = metadata.define_value("value", Value, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: some,
          type_arguments: [TypeArgument(i64_type())],
          hidden_witnesses: [],
          payloads: [Literal(I64(7L))],
        }),
      ),
      Let(
        result,
        Match({
          scrutinee: Ref(scrutinee),
          binder,
          result_type: i64_type(),
          alternatives: [
            {
              alt_constructor: DataCon(none),
              type_binders: [],
              value_binders: [],
              body: Literal(I64(0L)),
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
      #|let value#3 = match value#0 as value#1 -> I64 {
      #|  datacon#0() => 0
      #|  datacon#1(value#2) => value#2
      #|}
    ),
  )
  expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|i64 7
    ),
  )
}

///|
test "evaluation rejects invalid program" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [Let(value, Literal(Bool(true)))],
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected I64
      #|    actual Bool
      #|  } at term value#0
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
      #|    expected I64
      #|    actual Bool
      #|  } at term value#0
      #|}
    ),
  )
}

///|
test "every verified top-term shape evaluates without an unbound value" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let thunk = @buslane.Type::Function([], unit_type, Empty)
  let external = metadata.define_value("external", External, thunk)
  let recursive = metadata.define_value("recursive", Function, thunk)
  let ordinary = metadata.define_value("ordinary", Value, unit_type)
  let observer = metadata.define_value("observer", Function, thunk)
  let call = fn(target) {
    @buslane.Expr::Function({
      parameters: [],
      result_type: unit_type,
      body: Call(Ref(target), []),
    })
  }
  // One program using every top-term shape, with each reference the verifier
  // admits: an external installed earlier, a recursive group naming itself,
  // an ordinary let reading an earlier binding, and a function body reaching
  // a binding that comes later.
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(external),
      LetRec([{ id: recursive, rhs: call(external) }]),
      Let(ordinary, Call(Ref(recursive), [])),
      Let(observer, call(recursive)),
    ],
  }
  assert_eq(@buslane.verify_program(program).diagnostics(), [])
  let runtime = BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_resolver((id, _type) => {
    if id != external {
      abort("unexpected Buslane external")
    }
    BuslaneRuntimeValue::native_function(_arguments => {
      BuslaneRuntimeValue::unit()
    })
  })
  let evaluated = evaluate_buslane_program(program, runtime)
  inspect(
    @prettyprinter.render(evaluated.lookup(ordinary), width=80),
    content="unit",
  )
}
