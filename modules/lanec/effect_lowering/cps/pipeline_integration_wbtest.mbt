///|
test "selective CPS removes concrete open-context markers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let first = metadata.define_effect("First", [])
  let second = metadata.define_effect("Second", [])
  let callee = metadata.define_value(
    "callee",
    External,
    Function([], Primitive(Int), Singleton(first, [])),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function(
      [],
      Primitive(Int),
      Union([Singleton(first, []), Singleton(second, [])]),
    ),
  )
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(callee),
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Int),
            body: Call(Ref(callee), []),
          }),
        },
      ]),
    ],
  })
  assert_cps_ordinary_output(output)
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
