///|
test "handler clauses use the outer dictionary for the same effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Reader", [])
  let operation = metadata.define_operation(
    "read",
    effect,
    [],
    [],
    Primitive(Int),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let inner_final = metadata.define_value("inner_result", Local, Primitive(Int))
  let outer_final = metadata.define_value("outer_result", Local, Primitive(Int))
  let clause_value = metadata.define_value("outer_value", Local, Primitive(Int))
  let inner_resume = metadata.define_value(
    "inner_resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
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
              operation,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [],
            }),
            result_binder: inner_final,
            result_type: Primitive(Int),
            final_body: Ref(inner_final),
            handlers: [
              {
                handled_effect: Singleton(effect, []),
                operations: [
                  {
                    operation,
                    type_binders: [],
                    payload_binders: [],
                    resume_binder: inner_resume,
                    body: Let(
                      clause_value,
                      Perform({
                        operation,
                        effect_arguments: [],
                        hidden_witnesses: [],
                        payloads: [],
                      }),
                      Call(Resume(inner_resume), [Ref(clause_value)]),
                    ),
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
              handled_effect: Singleton(effect, []),
              operations: [
                {
                  operation,
                  type_binders: [],
                  payload_binders: [],
                  resume_binder: outer_resume,
                  body: Literal(Int(42L)),
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
  assert_eq(evaluated.lookup(result).as_int(), Some(42L))
}

///|
test "handler lowering preserves generic operation clauses" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let clause_hidden = metadata.define_type_parameter("ClauseHidden", Type)
  let effect = metadata.define_effect("Generic", [element])
  let operation = metadata.define_operation(
    "select",
    effect,
    [hidden],
    [Parameter(hidden), Parameter(element)],
    Parameter(hidden),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let selected = metadata.define_value("selected", Local, Primitive(String))
  let final_binder = metadata.define_value("result", Local, Primitive(Int))
  let hidden_payload = metadata.define_value(
    "hidden_payload",
    Parameter,
    Parameter(clause_hidden),
  )
  let element_payload = metadata.define_value(
    "element_payload",
    Parameter,
    Primitive(Int),
  )
  let resume_binder = metadata.define_value(
    "resume",
    Parameter,
    Function([Parameter(clause_hidden)], Primitive(Int), Empty),
  )
  let source = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Let(
            selected,
            Perform({
              operation,
              effect_arguments: [TypeArgument(Primitive(Int))],
              hidden_witnesses: [TypeArgument(Primitive(String))],
              payloads: [Literal(String("selected")), Literal(Int(1L))],
            }),
            Literal(Int(7L)),
          ),
          result_binder: final_binder,
          result_type: Primitive(Int),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(effect, [TypeArgument(Primitive(Int))]),
              operations: [
                {
                  operation,
                  type_binders: [clause_hidden],
                  payload_binders: [hidden_payload, element_payload],
                  resume_binder,
                  body: Call(Resume(resume_binder), [Ref(hidden_payload)]),
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
  assert_eq(evaluated.lookup(result).as_int(), Some(7L))
}
