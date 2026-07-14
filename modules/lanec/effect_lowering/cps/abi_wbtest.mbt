///|
fn rewrite_test_program(program : Program) -> Program {
  rewrite_selective_cps_abis(introduce_monadic_binds(program).unwrap()).unwrap()
}

///|
test "selective CPS keeps pure definitions and calls direct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let pure = metadata.define_value(
    "pure",
    External,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let input = Program::{
    metadata,
    terms: [External(pure), Let(result, Call(Ref(pure), [Literal(Int(1L))]))],
  }
  let output = rewrite_test_program(input)
  assert_eq(output, input)
  assert_cps_ordinary_output(output)
}

///|
test "direct calls bridge Unit-specialized CPS callables" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_type_parameter("Answer", Type)
  let encoded_type = @buslane.Type::Forall(
    [answer],
    Function(
      [Primitive(Unit), Function([Primitive(Int)], Parameter(answer), Empty)],
      Parameter(answer),
      Empty,
    ),
  )
  let encoded = metadata.define_value("encoded", External, encoded_type)
  let program : Program = { metadata, terms: [External(encoded)] }
  let bridged = lower_cps_direct_call(
    program,
    Ref(encoded),
    [],
    Primitive(Int),
    1,
  )
  guard bridged
    is Call(
      TypeApply(Ref(callee), [TypeArgument(Primitive(Int))]),
      [Literal(Unit), Function(identity)]
    ) else {
    abort("expected direct CPS bridge")
  }
  assert_eq(callee, encoded)
  assert_eq(identity.result_type, Primitive(Int))
  assert_eq(identity.body, Ref(identity.parameters[0]))
}

///|
test "selective CPS rewrites monadic function and tail call ABI" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let callee = metadata.define_value(
    "callee",
    External,
    Function([Primitive(Int)], Primitive(Int), latent),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([Primitive(Int)], Primitive(Int), latent),
  )
  let input = metadata.define_value("input", Parameter, Primitive(Int))
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(callee),
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [input],
            result_type: Primitive(Int),
            body: Call(Ref(callee), [Ref(input)]),
          }),
        },
      ]),
    ],
  })
  guard output.terms[1]
    is LetRec([{ rhs: TypeLambda([answer], Function(transformed)), .. }]) else {
    abort("expected CPS function")
  }
  guard transformed.parameters is [context, transformed_input, continuation] else {
    abort("expected context, source, and continuation parameters")
  }
  assert_eq(transformed_input, input)
  assert_eq(transformed.result_type, Parameter(answer))
  guard metadata.value_info(outer).unwrap().type_
    is Forall([metadata_answer], Function(_, metadata_result, Empty)) else {
    abort("expected synchronized CPS metadata")
  }
  assert_eq(metadata_answer, answer)
  assert_eq(metadata_result, Parameter(answer))
  assert_eq(
    transformed.body,
    Call(TypeApply(Ref(callee), [TypeArgument(Parameter(answer))]), [
      Ref(context),
      Ref(input),
      Ref(continuation),
    ]),
  )
  guard metadata.value_info(context).unwrap().type_
    is Apply(Constructor(_), [TypeArgument(context_answer)]) else {
    abort("expected typed dictionary context")
  }
  assert_eq(context_answer, Parameter(answer))
  assert_eq(
    metadata.value_info(continuation).unwrap().type_,
    Function([Primitive(Int)], Parameter(answer), Empty),
  )
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS composes an explicit bind continuation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let effectful = metadata.define_value(
    "effectful",
    External,
    Function([], Primitive(Int), latent),
  )
  let pure = metadata.define_value(
    "pure",
    External,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(Int), latent),
  )
  let local_value = metadata.define_value("local", Local, Primitive(Int))
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(effectful),
      External(pure),
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Int),
            body: Let(
              local_value,
              Call(Ref(effectful), []),
              Call(Ref(pure), [Ref(local_value)]),
            ),
          }),
        },
      ]),
    ],
  })
  guard output.terms[2]
    is LetRec([{ rhs: TypeLambda([answer], Function(transformed)), .. }]) else {
    abort("expected CPS function")
  }
  guard transformed.parameters is [context, outer_continuation] else {
    abort("expected CPS parameters")
  }
  guard transformed.body
    is Call(
      TypeApply(Ref(callee), [TypeArgument(call_answer)]),
      [Ref(call_context), Function(next)]
    ) else {
    abort("expected CPS call with local continuation")
  }
  assert_eq(callee, effectful)
  assert_eq(call_answer, Parameter(answer))
  assert_eq(call_context, context)
  guard next.parameters is [binder] else { abort("expected bind parameter") }
  assert_eq(next.result_type, Parameter(answer))
  assert_eq(
    next.body,
    Let(
      local_value,
      Ref(binder),
      Call(Ref(outer_continuation), [Call(Ref(pure), [Ref(local_value)])]),
    ),
  )
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS replaces effect polymorphism with companions" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let generic_type : @buslane.Type = Forall(
    [effect_parameter],
    Function([], Primitive(Int), Parameter(effect_parameter)),
  )
  let callee = metadata.define_value("callee", External, generic_type)
  let outer = metadata.define_value("outer", Function, generic_type)
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(callee),
      LetRec([
        {
          id: outer,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [],
              result_type: Primitive(Int),
              body: Call(
                TypeApply(Ref(callee), [
                  EffectArgument(Parameter(effect_parameter)),
                ]),
                [],
              ),
            }),
          ),
        },
      ]),
    ],
  })
  guard output.terms[1]
    is LetRec(
      [
        {
          rhs: TypeLambda(
            [companion],
            TypeLambda([answer], Function(transformed))
          ),
          ..,
        },
      ]
    ) else {
    abort("expected companion and answer type parameters")
  }
  assert_eq(metadata.type_parameter_info(companion).unwrap().kind, Type)
  guard transformed.parameters is [context, continuation] else {
    abort("expected abstract context parameter")
  }
  assert_eq(metadata.value_info(context).unwrap().type_, Parameter(companion))
  assert_eq(
    transformed.body,
    Call(
      TypeApply(TypeApply(Ref(callee), [TypeArgument(Parameter(companion))]), [
        TypeArgument(Parameter(answer)),
      ]),
      [Ref(context), Ref(continuation)],
    ),
  )
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS calls a first-class effectful callable" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let action_type : @buslane.Type = Function([], Primitive(Int), latent)
  let action = metadata.define_value("action", Parameter, action_type)
  let apply = metadata.define_value(
    "apply",
    Function,
    Function([action_type], Primitive(Int), latent),
  )
  let output = rewrite_test_program({
    metadata,
    terms: [
      LetRec([
        {
          id: apply,
          rhs: Function({
            parameters: [action],
            result_type: Primitive(Int),
            body: Call(Ref(action), []),
          }),
        },
      ]),
    ],
  })
  guard output.terms[0]
    is LetRec([{ rhs: TypeLambda([answer], Function(transformed)), .. }]) else {
    abort("expected CPS apply function")
  }
  guard transformed.parameters is [context, transformed_action, continuation] else {
    abort("expected context, callable, and continuation")
  }
  assert_eq(transformed_action, action)
  assert_eq(
    transformed.body,
    Call(TypeApply(Ref(action), [TypeArgument(Parameter(answer))]), [
      Ref(context),
      Ref(continuation),
    ]),
  )
  guard metadata.value_info(action).unwrap().type_
    is Forall(
      [action_answer],
      Function([_, action_continuation], action_result, Empty)
    ) else {
    abort("expected first-class CPS callable type")
  }
  assert_eq(action_result, Parameter(action_answer))
  assert_eq(
    action_continuation,
    Function([Primitive(Int)], Parameter(action_answer), Empty),
  )
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS preserves effectful argument evaluation order" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let first = metadata.define_value(
    "first",
    External,
    Function([], Primitive(Int), latent),
  )
  let second = metadata.define_value(
    "second",
    External,
    Function([], Primitive(Int), latent),
  )
  let combine = metadata.define_value(
    "combine",
    External,
    Function([Primitive(Int), Primitive(Int)], Primitive(Int), Empty),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(Int), latent),
  )
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(first),
      External(second),
      External(combine),
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Int),
            body: Call(Ref(combine), [
              Call(Ref(first), []),
              Call(Ref(second), []),
            ]),
          }),
        },
      ]),
    ],
  })
  guard output.terms[3]
    is LetRec([{ rhs: TypeLambda([answer], Function(transformed)), .. }]) else {
    abort("expected CPS outer function")
  }
  guard transformed.parameters is [context, outer_continuation] else {
    abort("expected CPS parameters")
  }
  guard transformed.body
    is Call(
      TypeApply(Ref(first_callee), _),
      [Ref(first_context), Function(first_next)]
    ) else {
    abort("expected first effectful argument")
  }
  assert_eq(first_callee, first)
  assert_eq(first_context, context)
  guard first_next.parameters is [first_value] else {
    abort("expected first result")
  }
  guard first_next.body
    is Call(
      TypeApply(Ref(second_callee), _),
      [Ref(second_context), Function(second_next)]
    ) else {
    abort("expected second effectful argument")
  }
  assert_eq(second_callee, second)
  assert_eq(second_context, context)
  guard second_next.parameters is [second_value] else {
    abort("expected second result")
  }
  assert_eq(
    second_next.body,
    Call(Ref(outer_continuation), [
      Call(Ref(combine), [Ref(first_value), Ref(second_value)]),
    ]),
  )
  assert_eq(first_next.result_type, Parameter(answer))
  assert_eq(second_next.result_type, Parameter(answer))
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS shares one continuation after monadic match branches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let effectful = metadata.define_value(
    "effectful",
    External,
    Function([], Primitive(Int), latent),
  )
  let pure = metadata.define_value(
    "pure",
    External,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(Int), latent),
  )
  let match_binder = metadata.define_value(
    "match",
    MatchBinder,
    Primitive(Bool),
  )
  let local_value = metadata.define_value("local", Local, Primitive(Int))
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(effectful),
      External(pure),
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Int),
            body: Let(
              local_value,
              Match({
                scrutinee: Literal(Bool(true)),
                binder: match_binder,
                result_type: Primitive(Int),
                alternatives: [
                  {
                    alt_constructor: Literal(Bool(true)),
                    type_binders: [],
                    value_binders: [],
                    body: Call(Ref(effectful), []),
                  },
                  {
                    alt_constructor: Default,
                    type_binders: [],
                    value_binders: [],
                    body: Literal(Int(0L)),
                  },
                ],
              }),
              Call(Ref(pure), [Ref(local_value)]),
            ),
          }),
        },
      ]),
    ],
  })
  guard output.terms[2]
    is LetRec([{ rhs: TypeLambda([answer], Function(transformed)), .. }]) else {
    abort("expected CPS function")
  }
  guard transformed.body is Match(transformed_match) else {
    abort("expected shared match")
  }
  assert_eq(transformed_match.result_type, Parameter(answer))
  guard transformed_match.alternatives[0].body
    is Call(_, [_, first_continuation]) else {
    abort("expected effectful branch continuation")
  }
  guard transformed_match.alternatives[1].body
    is Call(second_continuation, [Literal(Int(0L))]) else {
    abort("expected pure branch continuation")
  }
  assert_eq(first_continuation, second_continuation)
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS selects a generic operation dictionary field" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let effect = metadata.define_effect("Effect", [element])
  ignore(metadata.define_operation("first", effect, [], [], Primitive(Int)))
  let operation = metadata.define_operation(
    "second",
    effect,
    [hidden],
    [Parameter(hidden), Parameter(element)],
    Primitive(Unit),
  )
  let latent = @buslane.Effect::Singleton(effect, [TypeArgument(Primitive(Int))])
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(Unit), latent),
  )
  let output = rewrite_test_program({
    metadata,
    terms: [
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Unit),
            body: Invoke({
              operation,
              effect_arguments: [TypeArgument(Primitive(Int))],
              hidden_witnesses: [TypeArgument(Primitive(String))],
              payloads: [Literal(String("payload")), Literal(Int(1L))],
            }),
          }),
        },
      ]),
    ],
  })
  guard output.terms[0]
    is LetRec([{ rhs: TypeLambda([answer], Function(transformed)), .. }]) else {
    abort("expected CPS function")
  }
  guard transformed.parameters is [_, continuation] else {
    abort("expected context and continuation")
  }
  guard transformed.body
    is Match(
      {
        alternatives: [{ value_binders: [first_field, second_field], body, .. }],
        ..,
      }
    ) else {
    abort("expected static dictionary projection")
  }
  assert_true(first_field != second_field)
  assert_eq(
    body,
    Call(TypeApply(Ref(second_field), [TypeArgument(Primitive(String))]), [
      Literal(String("payload")),
      Literal(Int(1L)),
      Ref(continuation),
    ]),
  )
  assert_eq(transformed.result_type, Parameter(answer))
  assert_cps_ordinary_output(output)
}
