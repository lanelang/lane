///|
test "effect synthesis combines call evaluation and latent effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let pure_callee = metadata.define_value(
    "pure",
    Value,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let effectful_callee = metadata.define_value(
    "effectful",
    Value,
    Function([Primitive(Int)], Primitive(Int), Singleton(effect, [])),
  )
  let program = Program::{ metadata, terms: [] }
  assert_eq(
    synthesize_expr(program, Call(Ref(pure_callee), [Literal(Int(1L))])),
    Ok({ type_: Primitive(Int), effect: Empty }),
  )
  assert_eq(
    synthesize_expr(program, Call(Ref(effectful_callee), [Literal(Int(1L))])),
    Ok({ type_: Primitive(Int), effect: Singleton(effect, []) }),
  )
}

///|
test "effect synthesis substitutes open effect applications" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let callee = metadata.define_value(
    "callee",
    Value,
    Forall(
      [effect_parameter],
      Function([], Primitive(Int), Parameter(effect_parameter)),
    ),
  )
  let applied = TypeApply(Ref(callee), [EffectArgument(Singleton(effect, []))])
  let program = Program::{ metadata, terms: [] }
  assert_eq(
    synthesize_expr(program, applied),
    Ok({
      type_: Function([], Primitive(Int), Singleton(effect, [])),
      effect: Empty,
    }),
  )
  assert_eq(
    synthesize_expr(program, Call(applied, [])),
    Ok({ type_: Primitive(Int), effect: Singleton(effect, []) }),
  )
}

///|
test "effect synthesis includes invoke payload effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let payload_effect = metadata.define_effect("Payload", [])
  let operation_effect = metadata.define_effect("Operation", [])
  let operation = metadata.define_operation(
    "op",
    operation_effect,
    [],
    [Primitive(Int)],
    Primitive(Bool),
  )
  let payload = metadata.define_value(
    "payload",
    Value,
    Function([], Primitive(Int), Singleton(payload_effect, [])),
  )
  let program = Program::{ metadata, terms: [] }
  assert_eq(
    synthesize_expr(
      program,
      Invoke({
        operation,
        effect_arguments: [],
        hidden_witnesses: [],
        payloads: [Call(Ref(payload), [])],
      }),
    ),
    Ok({
      type_: Primitive(Bool),
      effect: Union([
        Singleton(payload_effect, []),
        Singleton(operation_effect, []),
      ]),
    }),
  )
}

///|
test "effect synthesis removes installed effects and includes clause effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let handled_effect = metadata.define_effect("Handled", [])
  let outer_effect = metadata.define_effect("Outer", [])
  let handled_operation = metadata.define_operation(
    "handled",
    handled_effect,
    [],
    [],
    Primitive(Int),
  )
  let outer_operation = metadata.define_operation(
    "outer",
    outer_effect,
    [],
    [],
    Primitive(Int),
  )
  let body_result = metadata.define_value("body", MatchBinder, Primitive(Int))
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let program = Program::{ metadata, terms: [] }
  let install = Install({
    body: Invoke({
      operation: handled_operation,
      effect_arguments: [],
      hidden_witnesses: [],
      payloads: [],
    }),
    result_type: Primitive(Int),
    dictionaries: [
      {
        handled_effect: Singleton(handled_effect, []),
        operations: [
          {
            operation: handled_operation,
            callable: Monomorphic({
              parameters: [resume_value],
              result_type: Primitive(Int),
              body: Invoke({
                operation: outer_operation,
                effect_arguments: [],
                hidden_witnesses: [],
                payloads: [],
              }),
            }),
          },
        ],
      },
    ],
    final_clause: {
      parameters: [body_result],
      result_type: Primitive(Int),
      body: Invoke({
        operation: outer_operation,
        effect_arguments: [],
        hidden_witnesses: [],
        payloads: [],
      }),
    },
  })
  assert_eq(
    synthesize_expr(program, install),
    Ok({ type_: Primitive(Int), effect: Singleton(outer_effect, []) }),
  )
}

///|
test "effect synthesis rejects impossible trusted-core shapes" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let missing = @buslane.ValueId::{ index: 0 }
  assert_eq(
    synthesize_expr({ metadata, terms: [] }, Ref(missing)),
    Err(UnknownValue(missing)),
  )
  assert_eq(
    synthesize_expr({ metadata, terms: [] }, Call(Literal(Int(1L)), [])),
    Err(ExpectedFunction(Primitive(Int))),
  )
}
