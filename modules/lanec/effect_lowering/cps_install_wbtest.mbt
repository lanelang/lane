///|
fn cps_test_plus_runtime(
  plus : @buslane.ValueId,
) -> @buslane_interpreter.BuslaneExternalRuntime {
  let runtime = @buslane_interpreter.BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_resolver((id, _type) => {
    if id != plus {
      raise @buslane_interpreter.missing_external(id)
    }
    @buslane_interpreter.BuslaneRuntimeValue::native_function(arguments => {
      if arguments.length() != 2 {
        raise @buslane_interpreter.external_failure(
          plus, "plus expects two arguments",
        )
      }
      guard arguments[0].as_int() is Some(left) else {
        raise @buslane_interpreter.external_failure(
          plus, "plus expects an integer left argument",
        )
      }
      guard arguments[1].as_int() is Some(right) else {
        raise @buslane_interpreter.external_failure(
          plus, "plus expects an integer right argument",
        )
      }
      @buslane_interpreter.BuslaneRuntimeValue::int(left + right)
    })
  })
  runtime
}

///|
fn lower_cps_test_source(source : @buslane.Program) -> @buslane.Program {
  let lowered = resolve_open_contexts(
    rewrite_selective_cps_abis(
      introduce_monadic_binds(elaborate_handlers(source)).unwrap(),
    ).unwrap(),
  ).unwrap()
  {
    metadata: lowered.metadata,
    terms: lowered.terms.map(cps_ordinary_top_term),
  }
}

///|
test "handler lowering preserves multi-shot resume execution" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let nondeterminism = metadata.define_effect("Nondeterminism", [])
  let choose = metadata.define_operation(
    "choose",
    nondeterminism,
    [],
    [],
    Primitive(Bool),
  )
  let plus = metadata.define_value(
    "plus",
    External,
    Function([Primitive(Int), Primitive(Int)], Primitive(Int), Empty),
  )
  let choice = metadata.define_value("choice", Local, Primitive(Bool))
  let match_binder = metadata.define_value(
    "choice",
    MatchBinder,
    Primitive(Bool),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let final_binder = metadata.define_value("result", Local, Primitive(Int))
  let resume_binder = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Bool)], Primitive(Int), Empty),
  )
  let source = @buslane.Program::{
    metadata,
    terms: [
      External(plus),
      Let(
        result,
        Handle({
          body: Let(
            choice,
            Perform({
              operation: choose,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [],
            }),
            Match({
              scrutinee: Ref(choice),
              binder: match_binder,
              result_type: Primitive(Int),
              alternatives: [
                {
                  alt_constructor: Literal(Bool(true)),
                  type_binders: [],
                  value_binders: [],
                  body: Literal(Int(10L)),
                },
                {
                  alt_constructor: Literal(Bool(false)),
                  type_binders: [],
                  value_binders: [],
                  body: Literal(Int(1L)),
                },
              ],
            }),
          ),
          result_binder: final_binder,
          result_type: Primitive(Int),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(nondeterminism, []),
              operations: [
                {
                  operation: choose,
                  type_binders: [],
                  payload_binders: [],
                  resume_binder,
                  body: Call(Ref(plus), [
                    Call(Resume(resume_binder), [Literal(Bool(true))]),
                    Call(Resume(resume_binder), [Literal(Bool(false))]),
                  ]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  let ordinary = lower_cps_test_source(source)
  assert_true(@buslane.verify_program(ordinary).is_ok())
  let evaluated = @buslane_interpreter.evaluate_buslane_program(
    ordinary,
    cps_test_plus_runtime(plus),
  )
  assert_eq(evaluated.lookup(result).as_int(), Some(11L))
}

///|
test "handler lowering relays residual effects through final clauses" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let inner_effect = metadata.define_effect("Inner", [])
  let inner_operation = metadata.define_operation(
    "inner",
    inner_effect,
    [],
    [],
    Primitive(Int),
  )
  let outer_effect = metadata.define_effect("Outer", [])
  let outer_operation = metadata.define_operation(
    "outer",
    outer_effect,
    [],
    [Primitive(Int)],
    Primitive(Int),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let inner_final = metadata.define_value("inner_result", Local, Primitive(Int))
  let outer_final = metadata.define_value("outer_result", Local, Primitive(Int))
  let outer_payload = metadata.define_value(
    "payload",
    Parameter,
    Primitive(Int),
  )
  let inner_resume = metadata.define_value(
    "inner_resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Singleton(outer_effect, [])),
  )
  let outer_resume = metadata.define_value(
    "outer_resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let source = @buslane.Program::{
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
              payloads: [],
            }),
            result_binder: inner_final,
            result_type: Primitive(Int),
            final_body: Perform({
              operation: outer_operation,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [Ref(inner_final)],
            }),
            handlers: [
              {
                handled_effect: Singleton(inner_effect, []),
                operations: [
                  {
                    operation: inner_operation,
                    type_binders: [],
                    payload_binders: [],
                    resume_binder: inner_resume,
                    body: Call(Resume(inner_resume), [Literal(Int(41L))]),
                  },
                ],
              },
            ],
          }),
          result_binder: outer_final,
          result_type: Primitive(Int),
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
                  body: Call(Resume(outer_resume), [Ref(outer_payload)]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  let ordinary = lower_cps_test_source(source)
  assert_true(@buslane.verify_program(ordinary).is_ok())
  let evaluated = @buslane_interpreter.evaluate_buslane_program(
    ordinary,
    BuslaneExternalRuntime(),
  )
  assert_eq(evaluated.lookup(result).as_int(), Some(41L))
}
