///|
test "effect lowering pretty prints handler elaboration" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("A", Type)
  let effect = metadata.define_effect("Console", [effect_parameter])
  let operation_parameter = metadata.define_type_parameter("B", Type)
  let operation = metadata.define_operation(
    "read",
    effect,
    [operation_parameter],
    [Parameter(operation_parameter)],
    Parameter(operation_parameter),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let payload = metadata.define_value("payload", Parameter, Primitive(Int))
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let final_value = metadata.define_value(
    "final_value",
    Parameter,
    Primitive(Int),
  )
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Install({
          body: Invoke({
            operation,
            effect_arguments: [TypeArgument(Primitive(Int))],
            hidden_witnesses: [TypeArgument(Primitive(Int))],
            payloads: [Literal(Int(40L))],
          }),
          result_type: Primitive(Int),
          dictionaries: [
            {
              handled_effect: Singleton(effect, [TypeArgument(Primitive(Int))]),
              operations: [
                {
                  operation,
                  callable: Polymorphic([operation_parameter], {
                    parameters: [payload, resume_value],
                    result_type: Primitive(Int),
                    body: Call(Ref(resume_value), [Ref(payload)]),
                  }),
                },
              ],
            },
          ],
          final_clause: {
            parameters: [final_value],
            result_type: Primitive(Int),
            body: Ref(final_value),
          },
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    type_parameter A#0 : Type
      #|    type_parameter B#2 : Type
      #|    value result#4 : Int
      #|    parameter payload#5 : Int
      #|    parameter resume#6 : (Int) -> Int
      #|    parameter final_value#7 : Int
      #|    effect Console#1[tparam#0] {
      #|      read#3[tparam#1](tparam#1) -> tparam#1
      #|    }
      #|  }
      #|  let value#0 = install invoke operation#0[Int; Int](40) -> Int {
      #|    effect#0[Int] {
      #|      operation#0 => fn[tparam#1](value#1, value#2) -> Int {
      #|        value#2(value#1)
      #|      }
      #|    }
      #|    final => fn(value#3) -> Int {
      #|      value#3
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "effect lowering pretty prints monadic context adaptation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let handled = metadata.define_effect("Handled", [])
  let source_effect : @buslane.Effect = Parameter(effect_parameter)
  let target_effect : @buslane.Effect = Union([
    Parameter(effect_parameter),
    Singleton(handled, []),
  ])
  let callee = metadata.define_value(
    "callee",
    Value,
    Function([], Primitive(Int), source_effect),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let binder = metadata.define_value("%bind", Parameter, Primitive(Int))
  let program = Program::{
    metadata,
    terms: [
      External(callee),
      Let(
        result,
        Bind({
          computation: OpenContext({
            source_effect,
            target_effect,
            body: Call(Ref(callee), []),
          }),
          binder,
          continuation: {
            parameters: [binder],
            result_type: Primitive(Int),
            body: Ref(binder),
          },
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    type_parameter E#0 : Effect
      #|    value callee#2 : () -> Int ! tparam#0
      #|    value result#3 : Int
      #|    parameter %bind#4 : Int
      #|    effect Handled#1 {}
      #|  }
      #|  external value#0
      #|  let value#1 = bind value#2 <- open_context tparam#0 => {tparam#0, effect#0} {
      #|    value#0()
      #|  } in
      #|    fn(value#2) -> Int {
      #|      value#2
      #|    }
      #|}
    ),
  )
}
