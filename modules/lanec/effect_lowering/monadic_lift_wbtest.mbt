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
