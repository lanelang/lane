///|
test "runtime ANF projection preserves effect-aware source metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let io_type = @buslane.Type::Function(
    [Primitive(String)],
    Primitive(Unit),
    Builtin(Io),
  )
  let println = metadata.define_value("println", External, io_type)
  let source : @buslane.Program = { metadata, terms: [External(println)] }
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).unwrap()
  debug_inspect(
    (
      source.metadata.value_info(println).map(info => info.type_),
      runtime.metadata().value_info(println).map(info => info.type_),
    ),
    content=(
      #|(
      #|  Some(Function([Primitive(String)], Primitive(Unit), Builtin(Io))),
      #|  Some(Function([Primitive(String)], Primitive(Unit), Empty)),
      #|)
    ),
  )
}

///|
test "runtime ANF removes effect-only binders and applications atomically" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_type_parameter("E", Effect)
  let token = metadata.define_type("Token", [effect])
  let token_constructor = metadata.define_data_constructor("Token", token, [], [])
  let token_of_effect = @buslane.Type::Apply(Constructor(token), [
    EffectArgument(Parameter(effect)),
  ])
  let make = metadata.define_value(
    "make",
    Function,
    Forall([effect], Function([], token_of_effect, Empty)),
  )
  let answer_type = @buslane.Type::Apply(Constructor(token), [
    EffectArgument(Empty),
  ])
  let answer = metadata.define_value(
    "answer",
    Function,
    Function([], answer_type, Empty),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      Let(
        make,
        TypeLambda(
          [effect],
          Function({
            parameters: [],
            result_type: token_of_effect,
            body: Construct({
              data_constructor: token_constructor,
              type_arguments: [EffectArgument(Parameter(effect))],
              hidden_witnesses: [],
              payloads: [],
            }),
          }),
        ),
      ),
      Let(
        answer,
        Function({
          parameters: [],
          result_type: answer_type,
          body: Call(TypeApply(Ref(make), [EffectArgument(Empty)]), []),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).unwrap()
  debug_inspect(
    (
      runtime.metadata().type_info(token),
      runtime.metadata().value_info(make).map(info => info.type_),
      runtime.metadata().value_info(answer).map(info => info.type_),
      runtime.terms(),
    ),
    content=(
      #|(
      #|  Some(
      #|    {
      #|      name: { name_space: TypeName, occurrence: "Token", unique: { value: 1 } },
      #|      flavor: Data,
      #|      parameters: [],
      #|      constructors: [{ index: 0 }],
      #|    },
      #|  ),
      #|  Some(Function([], Constructor({ index: 0 }), Empty)),
      #|  Some(Function([], Constructor({ index: 0 }), Empty)),
      #|  <ArrayView:
      #|    [
      #|      Let(
      #|        { index: 0 },
      #|        Atom(
      #|          Function(
      #|            {
      #|              id: { value: 0 },
      #|              source: Some({ index: 0 }),
      #|              parameters: [],
      #|              result_type: Constructor({ index: 0 }),
      #|              body: Let(
      #|                Temp(
      #|                  temp={ index: 0 },
      #|                  rhs=Construct(
      #|                    {
      #|                      data_constructor: { index: 0 },
      #|                      type_arguments: [],
      #|                      hidden_witnesses: [],
      #|                      payloads: [],
      #|                    },
      #|                  ),
      #|                ),
      #|                Atom(Temp({ index: 0 })),
      #|              ),
      #|            },
      #|          ),
      #|        ),
      #|      ),
      #|      Let(
      #|        { index: 1 },
      #|        Atom(
      #|          Function(
      #|            {
      #|              id: { value: 1 },
      #|              source: Some({ index: 1 }),
      #|              parameters: [],
      #|              result_type: Constructor({ index: 0 }),
      #|              body: Let(
      #|                Temp(
      #|                  temp={ index: 1 },
      #|                  rhs=Call(callee=Ref({ index: 0 }), arguments=[]),
      #|                ),
      #|                Atom(Temp({ index: 1 })),
      #|              ),
      #|            },
      #|          ),
      #|        ),
      #|      ),
      #|    ]>,
      #|)
    ),
  )
}

///|
test "runtime ANF preserves a used higher-kinded companion" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let companion = metadata.define_type_parameter(
    "Companion",
    Function([Type, Effect], Type),
  )
  let residual = metadata.define_type_parameter("Residual", Effect)
  let callable = metadata.define_value(
    "callable",
    External,
    Forall(
      [companion, residual],
      Function(
        [],
        Apply(Parameter(companion), [
          TypeArgument(Primitive(I64)),
          EffectArgument(Parameter(residual)),
        ]),
        Empty,
      ),
    ),
  )
  let source : @buslane.Program = { metadata, terms: [External(callable)] }
  assert_true(@buslane.verify_program(source).is_ok())
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).unwrap()
  debug_inspect(
    runtime.metadata().value_info(callable).map(info => info.type_),
    content=(
      #|Some(
      #|  Forall(
      #|    [{ index: 0 }],
      #|    Function(
      #|      [],
      #|      Apply(
      #|        Parameter({ index: 0 }),
      #|        [TypeArgument(Primitive(I64)), EffectArgument(Empty)],
      #|      ),
      #|      Empty,
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "runtime ANF beta-reduces projected type-lambda applications" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_type_parameter("Value", Type)
  let effect = metadata.define_type_parameter("Effect", Effect)
  let projected_result = @buslane.Type::Apply(
    TypeLambda([value, effect], Primitive(Unit)),
    [TypeArgument(Primitive(I64)), EffectArgument(Empty)],
  )
  let callable = metadata.define_value(
    "callable",
    External,
    Function([], projected_result, Empty),
  )
  let source : @buslane.Program = { metadata, terms: [External(callable)] }
  assert_true(@buslane.verify_program(source).is_ok())
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).unwrap()
  assert_eq(
    runtime.metadata().value_info(callable).map(info => info.type_),
    Some(Function([], Primitive(Unit), Empty)),
  )
}
