///|
test "effect synthesis combines call evaluation and latent effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let pure_callee = metadata.define_value(
    "pure",
    Value,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let effectful_callee = metadata.define_value(
    "effectful",
    Value,
    Function([Primitive(I64)], Primitive(I64), Singleton(effect, [])),
  )
  let program = Program::{ metadata, terms: [], }
  assert_eq(
    synthesize_expr(program, Call(Ref(pure_callee), [Literal(I64(1L))])),
    Ok({ type_: Primitive(I64), effect: Empty, }),
  )
  assert_eq(
    synthesize_expr(program, Call(Ref(effectful_callee), [Literal(I64(1L))])),
    Ok({ type_: Primitive(I64), effect: Singleton(effect, []), }),
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
      Function([], Primitive(I64), Parameter(effect_parameter)),
    ),
  )
  let applied = TypeApply(Ref(callee), [EffectArgument(Singleton(effect, []))])
  let program = Program::{ metadata, terms: [], }
  assert_eq(
    synthesize_expr(program, applied),
    Ok({
      type_: Function([], Primitive(I64), Singleton(effect, [])),
      effect: Empty,
    }),
  )
  assert_eq(
    synthesize_expr(program, Call(applied, [])),
    Ok({ type_: Primitive(I64), effect: Singleton(effect, []), }),
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
    [Primitive(I64)],
    Primitive(Bool),
  )
  let payload = metadata.define_value(
    "payload",
    Value,
    Function([], Primitive(I64), Singleton(payload_effect, [])),
  )
  let program = Program::{ metadata, terms: [], }
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
    Primitive(I64),
  )
  let outer_operation = metadata.define_operation(
    "outer",
    outer_effect,
    [],
    [],
    Primitive(I64),
  )
  let body_result = metadata.define_value("body", MatchBinder, Primitive(I64))
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let program = Program::{ metadata, terms: [], }
  let install = Install({
    body: Invoke({
      operation: handled_operation,
      effect_arguments: [],
      hidden_witnesses: [],
      payloads: [],
    }),
    result_type: Primitive(I64),
    dictionaries: [
      {
        handled_effect: Singleton(handled_effect, []),
        operations: [
          {
            operation: handled_operation,
            callable: Monomorphic({
              origin: SourceWritten,
              parameters: [resume_value],
              result_type: Primitive(I64),
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
      origin: SourceWritten,
      parameters: [body_result],
      result_type: Primitive(I64),
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
    Ok({ type_: Primitive(I64), effect: Singleton(outer_effect, []), }),
  )
}

///|
test "effect synthesis rejects impossible trusted-core shapes" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let missing = @buslane.ValueId::{ index: 0, }
  assert_eq(
    synthesize_expr({ metadata, terms: [], }, Ref(missing)),
    Err(UnknownValue(missing)),
  )
  assert_eq(
    synthesize_expr({ metadata, terms: [], }, Call(Literal(I64(1L)), [])),
    Err(ExpectedFunction(Primitive(I64))),
  )
}
