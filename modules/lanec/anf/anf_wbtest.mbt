///|
fn runtime_anf_test_input(program : @buslane.Program) -> RuntimeAnfInput {
  let retained_values = []
  for term in program.terms {
    match term {
      Let(value, _) | External(value) => retained_values.push(value)
      LetRec(bindings) =>
        for binding in bindings {
          retained_values.push(binding.id)
        }
    }
  }
  {
    program,
    retained_values,
    function_origins: @function_origin.FunctionOriginCatalog::uniform(
      program,
      SourceWritten,
    ),
  }
}

///|
test "lower buslane function call to ANF" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let result = metadata.define_value("value", Value, Primitive(I64))
  let function = metadata.define_value(
    "value",
    Function,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, Primitive(I64))
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: Primitive(I64),
            body: Ref(parameter),
          }),
        },
      ]),
      Let(result, Call(Ref(function), [Literal(I64(42L))])),
    ],
  }
  inspect(
    @prettyprinter.render(
      lower_cps_core_to_runtime_anf(runtime_anf_test_input(program)).unwrap(),
      width=100,
    ),
    content=(
      #|anf {
      #|  letrec {
      #|    value#1 = fn@0(value#2) -> I64 {
      #|      value#2
      #|    }
      #|  }
      #|  let value#0 = {
      #|    let temp#0 : I64 = value#1(42)
      #|    temp#0
      #|  }
      #|}
    ),
  )
}

///|
test "ANF binds a match before applying its continuation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let consume = metadata.define_value(
    "consume",
    External,
    Function([Primitive(Bool)], Primitive(I64), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(I64))
  let binder = metadata.define_value("matched", MatchBinder, Primitive(Bool))
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(consume),
      Let(
        result,
        Call(Ref(consume), [
          Match({
            scrutinee: Literal(Bool(true)),
            binder,
            result_type: Primitive(Bool),
            alternatives: [
              {
                alt_constructor: Literal(Bool(true)),
                type_binders: [],
                value_binders: [],
                body: Literal(Bool(true)),
              },
              {
                alt_constructor: Default,
                type_binders: [],
                value_binders: [],
                body: Literal(Bool(false)),
              },
            ],
          }),
        ]),
      ),
    ],
  }
  debug_inspect(
    (match lower_cps_core_to_runtime_anf(runtime_anf_test_input(program)) {
      Ok(program) => program
      Err(error) => abort("unexpected runtime ANF error: \{Repr(error)}")
    }).terms()[1],
    content=(
      #|Let(
      #|  { index: 1 },
      #|  Let(
      #|    Temp(
      #|      temp={ index: 0 },
      #|      type_=Scalar(Bool),
      #|      rhs=Match(
      #|        {
      #|          scrutinee: Literal(Bool(true)),
      #|          binder: { index: 2 },
      #|          result_type: Scalar(Bool),
      #|          alternatives: [
      #|            {
      #|              alt_constructor: Literal(Bool(true)),
      #|              evidence_binders: [],
      #|              value_binders: [],
      #|              body: Atom(Literal(Bool(true))),
      #|            },
      #|            {
      #|              alt_constructor: Default,
      #|              evidence_binders: [],
      #|              value_binders: [],
      #|              body: Atom(Literal(Bool(false))),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|    Let(
      #|      Temp(
      #|        temp={ index: 1 },
      #|        type_=Scalar(I64),
      #|        rhs=Call(callee=Ref({ index: 0 }), arguments=[Temp({ index: 0 })]),
      #|      ),
      #|      Atom(Temp({ index: 1 })),
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "runtime ANF rejects residual handlers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "op",
    effect,
    [],
    [],
    Primitive(I64),
  )
  let result = metadata.define_value("value", Value, Primitive(I64))
  let result_binder = metadata.define_value("value", Local, Primitive(I64))
  let resume_value = metadata.define_value(
    "value",
    Parameter,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let first_resume = metadata.define_value("value", Local, Primitive(I64))
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [],
          }),
          result_binder,
          result_type: Primitive(I64),
          final_body: Ref(result_binder),
          handlers: [
            {
              handled_effect: Singleton(effect, []),
              operations: [
                {
                  operation,
                  type_binders: [],
                  payload_binders: [],
                  resume_binder: resume_value,
                  body: Let(
                    first_resume,
                    Call(Ref(resume_value), [Literal(I64(1L))]),
                    Call(Ref(resume_value), [Ref(first_resume)]),
                  ),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  assert_true(
    lower_cps_core_to_runtime_anf(runtime_anf_test_input(program))
    is Err(ResidualHandle),
  )
}
