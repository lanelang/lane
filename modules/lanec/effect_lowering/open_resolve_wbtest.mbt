///|
test "open-resolve removes identity and empty abstract markers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let abstract_effect : @buslane.Effect = Parameter(effect_parameter)
  let identity = Program::{
    metadata,
    terms: [
      Let(
        result,
        OpenContext({
          source_effect: abstract_effect,
          target_effect: abstract_effect,
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(
    resolve_open_contexts(identity),
    Ok({ metadata, terms: [Let(result, Literal(Unit))] }),
  )
  let empty = Program::{
    metadata,
    terms: [
      Let(
        result,
        OpenContext({
          source_effect: Empty,
          target_effect: abstract_effect,
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(
    resolve_open_contexts(empty),
    Ok({ metadata, terms: [Let(result, Literal(Unit))] }),
  )
}

///|
test "open-resolve rejects abstract plans with missing source contexts" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let first = metadata.define_effect("First", [])
  let second = metadata.define_effect("Second", [])
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let missing : @buslane.Effect = Singleton(first, [])
  let source : @buslane.Effect = Union([Parameter(effect_parameter), missing])
  let target : @buslane.Effect = Union([
    Parameter(effect_parameter),
    Singleton(second, []),
  ])
  assert_eq(
    resolve_open_contexts({
      metadata,
      terms: [
        Let(
          result,
          OpenContext({
            source_effect: source,
            target_effect: target,
            body: Literal(Unit),
          }),
        ),
      ],
    }),
    Err(MissingEffectContext(missing)),
  )
}

///|
test "open-resolve preserves ordered abstract context arguments" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let first = metadata.define_effect("First", [])
  let second = metadata.define_effect("Second", [])
  let source_effect : @buslane.Effect = Union([
    Parameter(effect_parameter),
    Singleton(first, []),
  ])
  let target_effect : @buslane.Effect = Union([
    Parameter(effect_parameter),
    Singleton(first, []),
    Singleton(second, []),
  ])
  let action_type : @buslane.Type = Function([], Primitive(Int), source_effect)
  let action = metadata.define_value("action", Parameter, action_type)
  let apply = metadata.define_value(
    "apply",
    Function,
    Forall(
      [effect_parameter],
      Function([action_type], Primitive(Int), target_effect),
    ),
  )
  let transformed = rewrite_test_program({
    metadata,
    terms: [
      LetRec([
        {
          id: apply,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [action],
              result_type: Primitive(Int),
              body: Call(Ref(action), []),
            }),
          ),
        },
      ]),
    ],
  })
  guard transformed.terms[0]
    is LetRec(
      [
        {
          rhs: TypeLambda(
            [_],
            TypeLambda([answer], Function(transformed_function))
          ),
          ..,
        },
      ]
    ) else {
    abort("expected polymorphic CPS function")
  }
  guard transformed_function.parameters
    is [abstract_context, first_context, _, transformed_action, _] else {
    abort("expected target contexts, action, and continuation")
  }
  assert_eq(transformed_action, action)
  guard transformed_function.body
    is OpenContext(
      {
        body: marked_call,
        source_effect: marked_source,
        target_effect: marked_target,
      }
    ) else {
    abort("expected abstract open-context marker")
  }
  assert_eq(marked_source, source_effect)
  assert_eq(marked_target, target_effect)
  guard marked_call
    is Call(
      TypeApply(Ref(marked_action), [TypeArgument(Parameter(marked_answer))]),
      [Ref(marked_abstract), Ref(marked_first), marked_continuation]
    ) else {
    abort("expected explicitly selected source contexts")
  }
  assert_eq(marked_action, action)
  assert_eq(marked_answer, answer)
  assert_eq(marked_abstract, abstract_context)
  assert_eq(marked_first, first_context)
  assert_eq(
    validate_open_resolve_output(transformed),
    Err(ResidualOpenContext(source=source_effect, target=target_effect)),
  )
  let resolved = resolve_open_contexts(transformed).unwrap()
  guard resolved.terms[0]
    is LetRec(
      [
        {
          rhs: TypeLambda(
            [_],
            TypeLambda([_], Function({ body: resolved_call, .. }))
          ),
          ..,
        },
      ]
    ) else {
    abort("expected resolved polymorphic CPS function")
  }
  assert_eq(resolved_call, marked_call)
  ignore(marked_continuation)
  assert_eq(validate_open_resolve_output(resolved), Ok(()))
  assert_cps_ordinary_output(resolved)
}
