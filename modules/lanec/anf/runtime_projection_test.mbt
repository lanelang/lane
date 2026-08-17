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
      #|  Some(Callable([ByteSequence], Unit)),
      #|)
    ),
  )
}

///|
test "runtime ANF metadata observations are isolated from lowering arenas" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value(
    "answer",
    Function,
    Function([], Primitive(Unit), Empty),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      Let(
        answer,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Literal(Unit),
        }),
      ),
    ],
  }
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).unwrap()
  let lowering_arena = runtime.metadata()
  let appended = lowering_arena.intern_type_expression(Static(Scalar(I64)))
  assert_eq(
    (
      lowering_arena.type_expression(appended),
      runtime.metadata().type_expression(appended),
    ),
    (Some(Static(Scalar(I64))), None),
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
      #|  Some({ kind: Data, evidence_parameters: [], constructors: [{ index: 0 }] }),
      #|  Some(Callable([], Data({ index: 0 }, []))),
      #|  Some(Callable([], Data({ index: 0 }, []))),
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
      #|              result_type: Data({ index: 0 }, []),
      #|              body: Let(
      #|                Temp(
      #|                  temp={ index: 0 },
      #|                  rhs=Construct(
      #|                    {
      #|                      data_constructor: { index: 0 },
      #|                      type_arguments: [],
      #|                      hidden_arguments: [],
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
      #|              result_type: Data({ index: 0 }, []),
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
      #|    [{ id: { index: 0 }, arity: 1 }],
      #|    Callable(
      #|      [],
      #|      Erased({ index: 2 }, Apply(Parameter({ index: 0 }), [Static(I64)])),
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
    Some(Callable([], Unit)),
  )
}

///|
test "runtime representation equality preserves semantic value categories" {
  let metadata : @anf.RuntimeMetadata = {
    values: [],
    types: [],
    data_constructors: [],
    evidence_parameters: [],
    type_expressions: [],
  }
  let left_parameter : @anf.RuntimeEvidenceParameter = {
    id: { index: 10 },
    arity: 0,
  }
  let right_parameter : @anf.RuntimeEvidenceParameter = {
    id: { index: 20 },
    arity: 0,
  }
  let left_argument : @anf.RuntimeArgument = {
    type_expression: { index: 30 },
    evidence: Static(I64),
  }
  let right_argument : @anf.RuntimeArgument = {
    type_expression: { index: 40 },
    evidence: Static(Bool),
  }
  assert_eq(
    [
      metadata.types_representation_equivalent(Scalar(I32), Scalar(Bool)),
      metadata.types_representation_equivalent(
        Data({ index: 0 }, [left_argument]),
        Data({ index: 0 }, [right_argument]),
      ),
      metadata.types_representation_equivalent(
        OpaqueReference({ index: 0 }),
        OpaqueReference({ index: 1 }),
      ),
      metadata.types_representation_equivalent(
        Forall(
          [left_parameter],
          Callable([Erased({ index: 50 }, Parameter(left_parameter.id))], Unit),
        ),
        Forall(
          [right_parameter],
          Callable([Erased({ index: 60 }, Parameter(right_parameter.id))], Unit),
        ),
      ),
    ],
    [false, true, false, true],
  )
}

///|
test "runtime ANF eta-expands a nominal type constructor argument" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let box_type_id = metadata.define_type("Box", [element])
  ignore(
    metadata.define_data_constructor("Box", box_type_id, [], [
      Parameter(element),
    ]),
  )
  let higher_kinded = metadata.define_type_parameter(
    "HigherKinded",
    Function([Type], Type),
  )
  let selected_type = @buslane.Type::Apply(Parameter(higher_kinded), [
    TypeArgument(Primitive(I64)),
  ])
  let select = metadata.define_value(
    "select",
    External,
    Forall([higher_kinded], Function([], selected_type, Empty)),
  )
  let answer_type = @buslane.Type::Apply(Constructor(box_type_id), [
    TypeArgument(Primitive(I64)),
  ])
  let answer = metadata.define_value(
    "answer",
    Function,
    Function([], answer_type, Empty),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      External(select),
      Let(
        answer,
        Function({
          parameters: [],
          result_type: answer_type,
          body: Call(
            TypeApply(Ref(select), [TypeArgument(Constructor(box_type_id))]),
            [],
          ),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).unwrap()
  debug_inspect(
    runtime.terms(),
    content=(
      #|<ArrayView:
      #|  [
      #|    External({ index: 0 }),
      #|    Let(
      #|      { index: 1 },
      #|      Atom(
      #|        Function(
      #|          {
      #|            id: { value: 0 },
      #|            source: Some({ index: 1 }),
      #|            parameters: [],
      #|            result_type: Data(
      #|              { index: 0 },
      #|              [{ type_expression: { index: 0 }, evidence: Static(I64) }],
      #|            ),
      #|            body: Let(
      #|              Temp(
      #|                temp={ index: 0 },
      #|                rhs=ApplyEvidence(
      #|                  callee=Ref({ index: 0 }),
      #|                  arguments=[
      #|                    {
      #|                      type_expression: { index: 3 },
      #|                      evidence: Lambda([{ id: { index: 0 }, arity: 0 }], Static(Reference)),
      #|                    },
      #|                  ],
      #|                ),
      #|              ),
      #|              Let(
      #|                Temp(
      #|                  temp={ index: 1 },
      #|                  rhs=Call(callee=Temp({ index: 0 }), arguments=[]),
      #|                ),
      #|                Atom(Temp({ index: 1 })),
      #|              ),
      #|            ),
      #|          },
      #|        ),
      #|      ),
      #|    ),
      #|  ]>
    ),
  )
}
