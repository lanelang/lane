///|
fn verification_function_program(
  metadata : @buslane.MetadataRegistry,
  result_type : @buslane.Type,
  effect : @buslane.Effect,
  body : Expr,
) -> Program raise @buslane.MetadataAllocationError {
  let main = metadata.define_value(
    "main",
    Function,
    Function([], result_type, effect),
  )
  {
    metadata,
    terms: [
      Let(
        main,
        Function({ origin: SourceWritten, parameters: [], result_type, body, }),
      ),
    ],
  }
}

///|
test "extended verifier checks Invoke payload types" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Probe", [])
  let operation = metadata.define_operation(
    "probe",
    effect,
    [],
    [Primitive(I64)],
    Primitive(Unit),
  )
  debug_inspect(
    verify_program(
      verification_function_program(
        metadata,
        Primitive(Unit),
        Singleton(effect, []),
        Invoke({
          operation,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [Literal(Unit)],
        }),
      ),
    ),
    content=(
      #|Ok(
      #|  {
      #|    diagnostics: [
      #|      {
      #|        kind: TypeMismatch(expected=Primitive(I64), actual=Primitive(Unit)),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 0 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 2 } }),
      #|            },
      #|          ),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Perform({ index: 0 })),
      #|          Child(PerformPayload(0)),
      #|          Expression(Literal),
      #|        ],
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
test "extended verifier checks Bind computation and continuation alignment" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let binder = metadata.define_value("bound", Parameter, Primitive(Unit))
  debug_inspect(
    verify_program(
      verification_function_program(
        metadata,
        Primitive(Unit),
        Empty,
        Bind({
          computation: Literal(I64(42L)),
          binder,
          continuation: {
            origin: SourceWritten,
            parameters: [binder],
            result_type: Primitive(Unit),
            body: Literal(Unit),
          },
        }),
      ),
    ),
    content=(
      #|Ok(
      #|  {
      #|    diagnostics: [
      #|      {
      #|        kind: TypeMismatch(expected=Primitive(Unit), actual=Primitive(I64)),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 1 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 1 } }),
      #|            },
      #|          ),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Call),
      #|          Child(CallArgument(0)),
      #|          Expression(Literal),
      #|        ],
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
test "extended verifier checks Install final-clause input" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let final_parameter = metadata.define_value(
    "handled-result",
    Parameter,
    Primitive(Unit),
  )
  debug_inspect(
    verify_program(
      verification_function_program(
        metadata,
        Primitive(Unit),
        Empty,
        Install({
          body: Literal(I64(42L)),
          result_type: Primitive(Unit),
          dictionaries: [],
          final_clause: {
            origin: SourceWritten,
            parameters: [final_parameter],
            result_type: Primitive(Unit),
            body: Literal(Unit),
          },
        }),
      ),
    ),
    content=(
      #|Ok(
      #|  {
      #|    diagnostics: [
      #|      {
      #|        kind: TypeMismatch(expected=Primitive(I64), actual=Primitive(Unit)),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 1 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 1 } }),
      #|            },
      #|          ),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Handle),
      #|        ],
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
test "extended verifier checks match alternative type binders" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let wrong_binder = metadata.define_type_parameter("Wrong", Effect)
  let box = metadata.define_type("Box", [])
  let make_box = metadata.define_data_constructor("Box", box, [hidden], [])
  let scrutinee_type = @buslane.Type::Constructor(box)
  let match_binder = metadata.define_value(
    "scrutinee",
    MatchBinder,
    scrutinee_type,
  )
  debug_inspect(
    verify_program(
      verification_function_program(
        metadata,
        Primitive(Unit),
        Empty,
        Match({
          scrutinee: Construct({
            data_constructor: make_box,
            type_arguments: [],
            hidden_witnesses: [TypeArgument(Primitive(I64))],
            payloads: [],
          }),
          binder: match_binder,
          result_type: Primitive(Unit),
          alternatives: [
            {
              alt_constructor: DataCon(make_box),
              type_binders: [wrong_binder],
              value_binders: [],
              body: Literal(Unit),
            },
          ],
        }),
      ),
    ),
    content=(
      #|Ok(
      #|  {
      #|    diagnostics: [
      #|      {
      #|        kind: KindMismatch(expected=Type, actual=Effect),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 1 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 5 } }),
      #|            },
      #|          ),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Match),
      #|          Child(MatchAlternative(0)),
      #|        ],
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
test "extended verifier checks OpenContext effect scope and inclusion" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let bound = metadata.define_type_parameter("Bound", Effect)
  let unbound = metadata.define_type_parameter("Unbound", Effect)
  let main = metadata.define_value(
    "main",
    Function,
    Forall([bound], Function([], Primitive(Unit), Empty)),
  )
  let scoped = Program::{
    metadata,
    terms: [
      Let(
        main,
        TypeLambda(
          [bound],
          Function({
            origin: SourceWritten,
            parameters: [],
            result_type: Primitive(Unit),
            body: OpenContext({
              source_effect: Empty,
              target_effect: Parameter(unbound),
              body: Literal(Unit),
            }),
          }),
        ),
      ),
    ],
  }
  debug_inspect(
    verify_program(scoped),
    content=(
      #|Ok(
      #|  {
      #|    diagnostics: [
      #|      {
      #|        kind: UnknownTypeParameter({ index: 1 }),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 0 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 2 } }),
      #|            },
      #|          ),
      #|          Expression(TypeLambda),
      #|          Child(TypeLambdaBody),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Let({ index: 4 })),
      #|          Child(LetBody),
      #|          Expression(Let({ index: 2 })),
      #|        ],
      #|      },
      #|      {
      #|        kind: UnknownTypeParameter({ index: 1 }),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 0 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 2 } }),
      #|            },
      #|          ),
      #|          Expression(TypeLambda),
      #|          Child(TypeLambdaBody),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Let({ index: 4 })),
      #|          Child(LetBody),
      #|          Expression(Let({ index: 2 })),
      #|        ],
      #|      },
      #|      {
      #|        kind: UnknownTypeParameter({ index: 1 }),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 0 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 2 } }),
      #|            },
      #|          ),
      #|          Expression(TypeLambda),
      #|          Child(TypeLambdaBody),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Let({ index: 4 })),
      #|          Child(LetBody),
      #|          Expression(Let({ index: 2 })),
      #|          Child(LetInitializer),
      #|          Expression(Function),
      #|        ],
      #|      },
      #|      {
      #|        kind: UnknownTypeParameter({ index: 1 }),
      #|        provenance: [
      #|          TopTerm(
      #|            {
      #|              id: { index: 0 },
      #|              name: Some({ name_space: ValueName, occurrence: "main", unique: { value: 2 } }),
      #|            },
      #|          ),
      #|          Expression(TypeLambda),
      #|          Child(TypeLambdaBody),
      #|          Expression(Function),
      #|          Child(FunctionBody),
      #|          Expression(Let({ index: 4 })),
      #|          Child(LetBody),
      #|          Expression(Let({ index: 2 })),
      #|          Child(LetInitializer),
      #|          Expression(Function),
      #|        ],
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )

  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let source = metadata.define_effect("Source", [])
  let target = metadata.define_effect("Target", [])
  assert_eq(
    verify_program(
      verification_function_program(
        metadata,
        Primitive(Unit),
        Empty,
        OpenContext({
          source_effect: Singleton(source, []),
          target_effect: Singleton(target, []),
          body: Literal(Unit),
        }),
      ),
    ),
    Err(MissingEffectContext(Singleton(source, []))),
  )
}
