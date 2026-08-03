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
  let result = metadata.define_value("result", Value, Primitive(I64))
  let payload = metadata.define_value("payload", Parameter, Primitive(I64))
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let final_value = metadata.define_value(
    "final_value",
    Parameter,
    Primitive(I64),
  )
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Install({
          body: Invoke({
            operation,
            effect_arguments: [TypeArgument(Primitive(I64))],
            hidden_witnesses: [TypeArgument(Primitive(I64))],
            payloads: [Literal(I64(40L))],
          }),
          result_type: Primitive(I64),
          dictionaries: [
            {
              handled_effect: Singleton(effect, [TypeArgument(Primitive(I64))]),
              operations: [
                {
                  operation,
                  callable: Polymorphic([operation_parameter], {
                    parameters: [payload, resume_value],
                    result_type: Primitive(I64),
                    body: Call(Ref(resume_value), [Ref(payload)]),
                  }),
                },
              ],
            },
          ],
          final_clause: {
            parameters: [final_value],
            result_type: Primitive(I64),
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
      #|    type_parameter tparam#0 = "A"#0 : Type;
      #|    type_parameter tparam#1 = "B"#2 : Type;
      #|    value value#0 = "result"#4 value : I64;
      #|    value value#1 = "payload"#5 parameter : I64;
      #|    value value#2 = "resume"#6 parameter : (I64) -> I64;
      #|    value value#3 = "final_value"#7 parameter : I64;
      #|    effect effect#0 = "Console"#1[tparam#0] {operation#0};
      #|    operation operation#0 = "read"#3[tparam#1](tparam#1) -> tparam#1 : effect#0;
      #|  }
      #|  let value#0 = install invoke operation#0[I64; I64](40) -> I64 {
      #|    effect#0[I64] {
      #|      operation#0 => fn[tparam#1](value#1, value#2) -> I64 {
      #|        value#2(value#1)
      #|      }
      #|    }
      #|    final => fn(value#3) -> I64 {
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
    Function([], Primitive(I64), source_effect),
  )
  let result = metadata.define_value("result", Value, Primitive(I64))
  let binder = metadata.define_value("%bind", Parameter, Primitive(I64))
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
            result_type: Primitive(I64),
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
      #|    type_parameter tparam#0 = "E"#0 : Effect;
      #|    value value#0 = "callee"#2 value : () -> I64 ! tparam#0;
      #|    value value#1 = "result"#3 value : I64;
      #|    value value#2 = "%bind"#4 parameter : I64;
      #|    effect effect#0 = "Handled"#1 {};
      #|  }
      #|  external value#0
      #|  let value#1 = bind value#2 <- open_context tparam#0 => {tparam#0, effect#0} {
      #|    value#0()
      #|  } in
      #|    fn(value#2) -> I64 {
      #|      value#2
      #|    }
      #|}
    ),
  )
}
