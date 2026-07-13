///|
test "monadic-lift rejects unresolved context markers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let effect : @buslane.Effect = Parameter(effect_parameter)
  assert_eq(
    lift_monadic_continuations({
      metadata,
      terms: [
        Let(
          result,
          OpenContext({
            source_effect: effect,
            target_effect: effect,
            body: Literal(Unit),
          }),
        ),
      ],
    }),
    Err(ResidualOpenContext(source=effect, target=effect)),
  )
}

///|
test "monadic-lift exposes generic continuation captures to ANF" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let captured_type = metadata.define_type_parameter("Captured", Type)
  let effect = metadata.define_effect("Tick", [])
  let tick = metadata.define_value(
    "tick",
    External,
    Function([], Primitive(Unit), Singleton(effect, [])),
  )
  let captured = metadata.define_value(
    "captured",
    Parameter,
    Parameter(captured_type),
  )
  let ignored = metadata.define_value("ignored", Local, Primitive(Unit))
  let outer = metadata.define_value(
    "outer",
    Function,
    Forall(
      [captured_type],
      Function(
        [Parameter(captured_type)],
        Parameter(captured_type),
        Singleton(effect, []),
      ),
    ),
  )
  let monadic = rewrite_test_program({
    metadata,
    terms: [
      External(tick),
      LetRec([
        {
          id: outer,
          rhs: TypeLambda(
            [captured_type],
            Function({
              parameters: [captured],
              result_type: Parameter(captured_type),
              body: Let(ignored, Call(Ref(tick), []), Ref(captured)),
            }),
          ),
        },
      ]),
    ],
  })
  let resolved = resolve_open_contexts(monadic).unwrap()
  let lifted = lift_monadic_continuations(resolved).unwrap()
  assert_true(@buslane.verify_program(lifted).is_ok())
  guard lifted.terms[1]
    is LetRec(
      [
        {
          rhs: TypeLambda(
            [_],
            TypeLambda([_], Function({ body: outer_body, .. }))
          ),
          ..,
        },
      ]
    ) else {
    abort("expected generic CPS function")
  }
  guard outer_body is Call(_, [_, Function(continuation)]) else {
    abort("expected generated local continuation")
  }
  guard continuation.body is Let(_, _, Call(_, [Ref(captured_reference)])) else {
    abort("expected continuation to retain captured value")
  }
  assert_eq(captured_reference, captured)
  assert_eq(
    metadata.value_info(captured_reference).unwrap().type_,
    Parameter(captured_type),
  )
  let anf = @anf.lower_buslane_program_to_anf(lifted)
  assert_eq(anf.metadata, lifted.metadata)
  assert_eq(anf.terms.length(), lifted.terms.length())
}

///|
test "monadic-lift preserves erased effect-kind existentials" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("HiddenEffect", Effect)
  let opened = metadata.define_type_parameter("OpenedEffect", Effect)
  let token = metadata.define_type("EffectToken", [])
  let make_token = metadata.define_data_constructor(
    "EffectToken",
    token,
    [hidden],
    [],
  )
  let token_type = @buslane.Type::Constructor(token)
  let scrutinee = metadata.define_value("scrutinee", Local, token_type)
  let match_binder = metadata.define_value("token", MatchBinder, token_type)
  let main_type = @buslane.Type::Function([], Primitive(Unit), Empty)
  let main = metadata.define_value("main", Function, main_type)
  let source = @buslane.Program::{
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Let(
            scrutinee,
            Construct({
              data_constructor: make_token,
              type_arguments: [],
              hidden_witnesses: [EffectArgument(Empty)],
              payloads: [],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: Primitive(Unit),
              alternatives: [
                {
                  alt_constructor: DataCon(make_token),
                  type_binders: [opened],
                  value_binders: [],
                  body: Literal(Unit),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let transformed = match
    rewrite_selective_cps_abis(
      introduce_monadic_binds(elaborate_handlers(source)).unwrap(),
    ) {
    Ok(value) => value
    Err(error) => fail("mon-trans failed: \{to_repr(error)}")
  }
  let lifted = lift_monadic_continuations(
    resolve_open_contexts(transformed).unwrap(),
  ).unwrap()
  assert_eq(metadata.type_parameter_info(hidden).unwrap().kind, Effect)
  assert_eq(
    metadata.data_constructor_info(make_token).unwrap().hidden_type_parameters,
    [hidden],
  )
  guard lifted.terms[0]
    is Let(
      _,
      Function(
        {
          body: Let(
            _,
            Construct({ hidden_witnesses: [EffectArgument(Empty)], .. }),
            Match({ alternatives: [{ type_binders: [opened_binder], .. }], .. })
          ),
          ..,
        }
      )
    ) else {
    abort("expected erased effect existential to remain in nominal data")
  }
  assert_eq(opened_binder, opened)
  assert_true(@buslane.verify_program(lifted).is_ok())
}
