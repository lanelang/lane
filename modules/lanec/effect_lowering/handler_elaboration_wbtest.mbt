///|
test "handler elaboration replaces effect syntax with invoke and install" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "op",
    effect,
    [],
    [Primitive(Int)],
    Primitive(Int),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let result_binder = metadata.define_value(
    "result",
    MatchBinder,
    Primitive(Int),
  )
  let payload = metadata.define_value("payload", Parameter, Primitive(Int))
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let resumed = metadata.define_value("resumed", Local, Primitive(Int))
  let input = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(Int(40L))],
          }),
          result_binder,
          result_type: Primitive(Int),
          final_body: Ref(result_binder),
          handlers: [
            {
              handled_effect: Singleton(effect, []),
              operations: [
                {
                  operation,
                  type_binders: [],
                  payload_binders: [payload],
                  resume_binder: resume_value,
                  body: Let(
                    resumed,
                    Call(Resume(resume_value), [Ref(payload)]),
                    Call(Resume(resume_value), [Ref(resumed)]),
                  ),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  let expected = Program::{
    metadata,
    terms: [
      Let(
        result,
        Install({
          body: Invoke({
            operation,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(Int(40L))],
          }),
          result_type: Primitive(Int),
          dictionaries: [
            {
              handled_effect: Singleton(effect, []),
              operations: [
                {
                  operation,
                  callable: Monomorphic({
                    parameters: [payload, resume_value],
                    result_type: Primitive(Int),
                    body: Let(
                      resumed,
                      Call(Ref(resume_value), [Ref(payload)]),
                      Call(Ref(resume_value), [Ref(resumed)]),
                    ),
                  }),
                },
              ],
            },
          ],
          final_clause: {
            parameters: [result_binder],
            result_type: Primitive(Int),
            body: Ref(result_binder),
          },
        }),
      ),
    ],
  }
  assert_eq(elaborate_handlers(input), expected)
}

///|
test "handler elaboration turns generic operation clauses into type lambdas" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("A", Type)
  let effect = metadata.define_effect("Effect", [effect_parameter])
  let hidden = metadata.define_type_parameter("B", Type)
  let operation = metadata.define_operation(
    "op",
    effect,
    [hidden],
    [Parameter(hidden)],
    Parameter(hidden),
  )
  let clause_type = metadata.define_type_parameter("C", Type)
  let result = metadata.define_value("result", Value, Primitive(Int))
  let result_binder = metadata.define_value(
    "result",
    MatchBinder,
    Parameter(hidden),
  )
  let payload = metadata.define_value(
    "payload",
    Parameter,
    Parameter(clause_type),
  )
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Parameter(clause_type)], Primitive(Int), Empty),
  )
  let input = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Literal(Int(0L)),
          result_binder,
          result_type: Primitive(Int),
          final_body: Literal(Int(0L)),
          handlers: [
            {
              handled_effect: Singleton(effect, [TypeArgument(Primitive(Int))]),
              operations: [
                {
                  operation,
                  type_binders: [clause_type],
                  payload_binders: [payload],
                  resume_binder: resume_value,
                  body: Literal(Int(1L)),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  let output = elaborate_handlers(input)
  guard output.terms[0] is Let(_, Install(install)) else {
    abort("expected elaborated install")
  }
  assert_eq(
    install.dictionaries[0].operations[0].callable,
    Polymorphic([clause_type], {
      parameters: [payload, resume_value],
      result_type: Primitive(Int),
      body: Literal(Int(1L)),
    }),
  )
}
