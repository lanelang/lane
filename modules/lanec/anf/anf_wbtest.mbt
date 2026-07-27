///|
test "lower buslane function call to ANF" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let result = metadata.define_value("value", Value, Primitive(Int))
  let function = metadata.define_value(
    "value",
    Function,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, Primitive(Int))
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: Primitive(Int),
            body: Ref(parameter),
          }),
        },
      ]),
      Let(result, Call(Ref(function), [Literal(Int(42L))])),
    ],
  }
  inspect(
    @prettyprinter.render(lower_buslane_program_to_anf(program), width=100),
    content=(
      #|anf {
      #|  letrec {
      #|    value#1 = fn(value#2) -> Int {
      #|      value#2
      #|    }
      #|  }
      #|  let value#0 = {
      #|    let temp#0 = value#1(42)
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
    Function,
    Function([Primitive(Bool)], Primitive(Int), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
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
    lower_buslane_program_to_anf(program).terms[1],
    content=(
      #|Let(
      #|  { index: 1 },
      #|  Let(
      #|    Temp(
      #|      temp={ index: 0 },
      #|      rhs=Match(
      #|        {
      #|          scrutinee: Literal(Bool(true)),
      #|          binder: { index: 2 },
      #|          result_type: Primitive(Bool),
      #|          alternatives: [
      #|            {
      #|              alt_constructor: Literal(Bool(true)),
      #|              type_binders: [],
      #|              value_binders: [],
      #|              body: Atom(Literal(Bool(true))),
      #|            },
      #|            {
      #|              alt_constructor: Default,
      #|              type_binders: [],
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
test "lower buslane handler and perform to ANF" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "op",
    effect,
    [],
    [],
    Primitive(Int),
  )
  let result = metadata.define_value("value", Value, Primitive(Int))
  let result_binder = metadata.define_value("value", Local, Primitive(Int))
  let resume_value = metadata.define_value(
    "value",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let first_resume = metadata.define_value("value", Local, Primitive(Int))
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
          result_type: Primitive(Int),
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
                    Call(Ref(resume_value), [Literal(Int(1L))]),
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
  inspect(
    @prettyprinter.render(lower_buslane_program_to_anf(program), width=100),
    content=(
      #|anf {
      #|  let value#0 = {
      #|    let temp#3 = handle {
      #|      let temp#0 = perform operation#0()
      #|      temp#0
      #|    } as value#1 -> Int {
      #|      effect#0 {
      #|        operation#0() resume value#2 => {
      #|          let temp#1 = value#2(1)
      #|          let temp#2 = value#2(temp#1)
      #|          temp#2
      #|        }
      #|      }
      #|      final => value#1
      #|    }
      #|    temp#3
      #|  }
      #|}
    ),
  )
}
