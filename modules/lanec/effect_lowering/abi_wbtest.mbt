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
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(I64))
  let input = Program::{
    metadata,
    terms: [External(pure), Let(result, Call(Ref(pure), [Literal(I64(1L))]))],
  }
  let output = rewrite_test_program(input)
  assert_eq(output, input)
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS keeps Io-only definitions and calls direct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Unit), Builtin(Io)),
  )
  let input = Program::{
    metadata,
    terms: [
      External(println),
      LetRec([
        {
          id: main,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Unit),
            body: Call(Ref(println), [Literal(String("hello"))]),
          }),
        },
      ]),
    ],
  }
  let output = rewrite_test_program(input)
  assert_eq(output, input)
  debug_inspect(
    output.metadata.value_info(main).unwrap().type_,
    content="Function([], Primitive(Unit), Builtin(Io))",
  )
}

///|
test "selective CPS keeps external-effect definitions and calls direct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let vector_op = metadata.define_effect("VectorOp", [], flavor=External)
  let effect = @buslane.Effect::Singleton(vector_op, [])
  let vector_get = metadata.define_value(
    "vector_get",
    External,
    Function([Primitive(I64)], Primitive(I64), effect),
  )
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(I64), effect),
  )
  let input = Program::{
    metadata,
    terms: [
      External(vector_get),
      LetRec([
        {
          id: main,
          rhs: Function({
            parameters: [],
            result_type: Primitive(I64),
            body: Call(Ref(vector_get), [Literal(I64(0L))]),
          }),
        },
      ]),
    ],
  }
  let output = rewrite_test_program(input)
  assert_eq(output, input)
  debug_inspect(
    (
      output.metadata.effect_info(vector_op).map(info => info.flavor),
      output.metadata.value_info(main).map(info => info.type_),
    ),
    content=(
      #|(
      #|  Some(External),
      #|  Some(Function([], Primitive(I64), Singleton({ index: 0 }, []))),
      #|)
    ),
  )
}

///|
test "selective CPS preserves Io on mixed callable and continuation types" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let handled = metadata.define_effect("Handled", [])
  let invoke = metadata.define_operation(
    "invoke",
    handled,
    [],
    [],
    Primitive(Unit),
  )
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let mixed_effect : @buslane.Effect = Union([
    Builtin(Io),
    Singleton(handled, []),
  ])
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Unit), mixed_effect),
  )
  let written = metadata.define_value("written", Local, Primitive(Unit))
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(println),
      LetRec([
        {
          id: main,
          rhs: Function({
            parameters: [],
            result_type: Primitive(Unit),
            body: Let(
              written,
              Call(Ref(println), [Literal(String("before"))]),
              Invoke({
                operation: invoke,
                effect_arguments: [],
                hidden_witnesses: [],
                payloads: [],
              }),
            ),
          }),
        },
      ]),
    ],
  })
  guard output.metadata.value_info(main).unwrap().type_
    is Forall([answer, residual], Function([_, continuation], result, latent)) else {
    abort("expected mixed CPS callable type")
  }
  let row = @buslane.Effect::Union([Builtin(Io), Parameter(residual)])
  assert_eq(latent, row)
  assert_eq(result, Parameter(answer))
  assert_eq(continuation, Function([Primitive(Unit)], Parameter(answer), row))
  assert_cps_ordinary_output(output)
  debug_inspect(
    output.terms[1],
    content=(
      #|"letrec {\n  value#1 = fn[tparam#2, tparam#3] {\n    fn(value#3, value#4) -> tparam#2 {\n      let value#2 = value#0(\"before\") in\n      match value#3 as value#5 -> tparam#2 {\n        datacon#0(value#6) => value#6(value#4)\n      }\n    }\n  }\n}"
    ),
  )
}

///|
test "direct calls bridge Unit-specialized CPS callables" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_type_parameter("Answer", Type)
  let residual = metadata.define_type_parameter(
    "Residual",
    Effect,
    flavor=External,
  )
  let context_answer = metadata.define_type_parameter("ContextAnswer", Type)
  let context_residual = metadata.define_type_parameter(
    "ContextResidual",
    Effect,
    flavor=External,
  )
  let row = @buslane.Effect::Union([Builtin(Io), Parameter(residual)])
  let context_type = @buslane.Type::Apply(
    TypeLambda([context_answer, context_residual], Primitive(Unit)),
    [TypeArgument(Parameter(answer)), EffectArgument(row)],
  )
  let encoded_type = @buslane.Type::Forall(
    [answer, residual],
    Function(
      [context_type, Function([Primitive(I64)], Parameter(answer), row)],
      Parameter(answer),
      row,
    ),
  )
  let encoded = metadata.define_value("encoded", External, encoded_type)
  let program : Program = { metadata, terms: [External(encoded)] }
  let bridged = lower_cps_direct_call(
    program.metadata,
    Ref(encoded),
    [],
    Primitive(I64),
  )
  guard bridged
    is Call(
      TypeApply(
        Ref(callee),
        [TypeArgument(Primitive(I64)), EffectArgument(Empty)]
      ),
      [Literal(Unit), Function(identity)]
    ) else {
    abort("expected direct CPS bridge")
  }
  assert_eq(callee, encoded)
  assert_eq(identity.result_type, Primitive(I64))
  assert_eq(identity.body, Ref(identity.parameters[0]))
  assert_eq(
    synthesize_expr_or_raise(program.metadata, bridged).effect,
    Builtin(Io),
  )
}

///|
test "direct calls do not omit represented CPS contexts" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_type_parameter("Answer", Type)
  let residual = metadata.define_type_parameter(
    "Residual",
    Effect,
    flavor=External,
  )
  let dictionary = metadata.define_type("Dictionary", [])
  let encoded_type = @buslane.Type::Forall(
    [answer, residual],
    Function(
      [
        Constructor(dictionary),
        Function([Primitive(I64)], Parameter(answer), Parameter(residual)),
      ],
      Parameter(answer),
      Parameter(residual),
    ),
  )
  let encoded = metadata.define_value("encoded", External, encoded_type)
  try lower_cps_direct_call(metadata, Ref(encoded), [], Primitive(I64)) catch {
    ExpectedFunction(actual) => assert_eq(actual, encoded_type)
    error => fail("unexpected synthesis error: \{Repr(error)}")
  } noraise {
    _ => fail("expected represented context rejection")
  }
}

///|
test "selective CPS rewrites monadic function and tail call ABI" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let callee = metadata.define_value(
    "callee",
    External,
    Function([Primitive(I64)], Primitive(I64), latent),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([Primitive(I64)], Primitive(I64), latent),
  )
  let input = metadata.define_value("input", Parameter, Primitive(I64))
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(callee),
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [input],
            result_type: Primitive(I64),
            body: Call(Ref(callee), [Ref(input)]),
          }),
        },
      ]),
    ],
  })
  guard output.terms[1]
    is LetRec(
      [{ rhs: TypeLambda([answer, residual], Function(transformed)), .. }]
    ) else {
    abort("expected CPS function")
  }
  guard transformed.parameters is [context, transformed_input, continuation] else {
    abort("expected context, source, and continuation parameters")
  }
  assert_eq(transformed_input, input)
  assert_eq(transformed.result_type, Parameter(answer))
  guard metadata.value_info(outer).unwrap().type_
    is Forall(
      [metadata_answer, metadata_residual],
      Function(_, metadata_result, metadata_latent)
    ) else {
    abort("expected synchronized CPS metadata")
  }
  assert_eq(metadata_answer, answer)
  assert_eq(metadata_residual, residual)
  assert_eq(metadata_result, Parameter(answer))
  assert_eq(metadata_latent, Parameter(residual))
  assert_eq(
    transformed.body,
    Call(
      TypeApply(Ref(callee), [
        TypeArgument(Parameter(answer)),
        EffectArgument(Parameter(residual)),
      ]),
      [Ref(context), Ref(input), Ref(continuation)],
    ),
  )
  guard metadata.value_info(context).unwrap().type_
    is Apply(
      Constructor(_),
      [TypeArgument(context_answer), EffectArgument(context_residual)]
    ) else {
    abort("expected typed dictionary context")
  }
  assert_eq(context_answer, Parameter(answer))
  assert_eq(context_residual, Parameter(residual))
  assert_eq(
    metadata.value_info(continuation).unwrap().type_,
    Function([Primitive(I64)], Parameter(answer), Parameter(residual)),
  )
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS synchronizes local generic callable metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let local_type : @buslane.Type = Function([], Primitive(I64), latent)
  let local_function = metadata.define_value("local", Local, local_type)
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], local_type, Empty),
  )
  let output = rewrite_test_program({
    metadata,
    terms: [
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: local_type,
            body: LetRec(
              [
                {
                  id: local_function,
                  rhs: Function({
                    parameters: [],
                    result_type: Primitive(I64),
                    body: Literal(I64(1L)),
                  }),
                },
              ],
              Ref(local_function),
            ),
          }),
        },
      ]),
    ],
  })
  guard output.terms
    is [
      LetRec(
        [
          {
            rhs: Function(
              {
                body: LetRec(
                  [
                    {
                      rhs: TypeLambda([answer, residual], Function(local_cps)),
                      ..,
                    },
                  ],
                  _
                ),
                ..,
              }
            ),
            ..,
          },
        ]
      ),
    ] else {
    abort("expected a local CPS callable")
  }
  assert_eq(
    metadata.value_info(local_function).unwrap().type_,
    Forall(
      [answer, residual],
      Function(
        local_cps.parameters.map(parameter => {
          metadata.value_info(parameter).unwrap().type_
        }),
        Parameter(answer),
        Parameter(residual),
      ),
    ),
  )
  assert_cps_ordinary_output(output)
}

///|
test "direct CPS lowering uses precommitted local binding metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let local_type : @buslane.Type = Function([], Primitive(I64), latent)
  let local_function = metadata.define_value("local", Local, local_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], local_type, Empty),
  )
  let body : Expr = Let(
    local_function,
    Function({
      parameters: [],
      result_type: Primitive(I64),
      body: Literal(I64(1L)),
    }),
    Ref(local_function),
  )
  // The declarations this pass rewrites are the ones the program mentions, so
  // the expression under test has to be in the program it is lowered against.
  let source = Program::{
    metadata: metadata.snapshot(),
    terms: [
      Let(entry, Function({ parameters: [], result_type: local_type, body })),
    ],
  }
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  rewrite_cps_source_metadata(schema, collect_program_declarations(source))
  let lowered = lower_cps_direct_expr(schema, source, body, None)
  guard lowered
    is Let(_, TypeLambda([answer, residual], Function(transformed)), _) else {
    abort("expected a local CPS callable")
  }
  assert_eq(
    metadata.value_info(local_function).unwrap().type_,
    Forall(
      [answer, residual],
      Function(
        transformed.parameters.map(parameter => {
          metadata.value_info(parameter).unwrap().type_
        }),
        Parameter(answer),
        Parameter(residual),
      ),
    ),
  )
}

///|
test "expected and synthesized CPS callables use one ABI shape" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "perform",
    effect,
    [],
    [],
    Primitive(I64),
  )
  let latent : @buslane.Effect = Singleton(effect, [])
  let callable_type : @buslane.Type = Function([], Primitive(I64), latent)
  let choose = metadata.define_value(
    "choose",
    External,
    Function([callable_type, callable_type], Primitive(Unit), Empty),
  )
  let declared = metadata.define_value("declared", Function, callable_type)
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let function = FunctionExpr::{
    parameters: [],
    result_type: Primitive(I64),
    body: Invoke({
      operation,
      effect_arguments: [],
      hidden_witnesses: [],
      payloads: [],
    }),
  }
  let output = rewrite_test_program({
    metadata,
    terms: [
      External(choose),
      LetRec([{ id: declared, rhs: Function(function) }]),
      Let(result, Call(Ref(choose), [Ref(declared), Function(function)])),
    ],
  })
  guard output.terms[2] is Let(_, Call(_, [_, synthesized])) else {
    abort("expected inline callable argument")
  }
  let declared_type = metadata.value_info(declared).unwrap().type_
  let synthesized_type = synthesize_expr_or_raise(metadata, synthesized).type_
  assert_true(
    metadata.types_definitionally_equal(declared_type, synthesized_type),
  )
  assert_cps_ordinary_output(output)
}

///|
test "effectful result wrappers materialize one CPS callable shape" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let source_result : @buslane.Type = Function(
    [Primitive(I64)],
    Primitive(Bool),
    latent,
  )
  let factory = metadata.define_value(
    "factory",
    External,
    Function([], source_result, Empty),
  )
  let result = metadata.define_value("result", Value, source_result)
  let output = rewrite_test_program({
    metadata,
    terms: [External(factory), Let(result, Call(Ref(factory), []))],
  })
  guard output.terms
    is [
      External(actual_factory),
      Let(actual_result, TypeLambda([answer, residual], Function(wrapper))),
    ] &&
    wrapper.parameters is [context, value, continuation] else {
    abort("expected one shape-materialized effectful result wrapper")
  }
  assert_eq((actual_factory, actual_result), (factory, result))
  assert_eq(
    wrapper.body,
    Call(
      TypeApply(Call(Ref(factory), []), [
        TypeArgument(Parameter(answer)),
        EffectArgument(Parameter(residual)),
      ]),
      [Ref(context), Ref(value), Ref(continuation)],
    ),
  )
  assert_true(
    metadata.types_definitionally_equal(
      metadata.value_info(result).unwrap().type_,
      synthesize_expr_or_raise(
        metadata,
        TypeLambda([answer, residual], Function(wrapper)),
      ).type_,
    ),
  )
  assert_cps_ordinary_output(output)
}

///|
test "callable shape divergence reports the originating binding" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let callable_type : @buslane.Type = Function([], Primitive(I64), latent)
  let binding = metadata.define_value("binding", Local, callable_type)
  let initializer : Expr = Function({
    parameters: [],
    result_type: Primitive(I64),
    body: Literal(I64(1L)),
  })
  let source = Program::{
    metadata: metadata.snapshot(),
    terms: [LetRec([{ id: binding, rhs: initializer }])],
  }
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  rewrite_cps_source_metadata(schema, collect_program_declarations(source))
  let planned_type = metadata.value_info(binding).unwrap().type_
  let info = metadata.values[binding.index]
  metadata.values[binding.index] = {
    name: info.name,
    kind: info.kind,
    type_: Primitive(Bool),
  }
  let result : Result[Expr, SynthesisError] = Ok(
    lower_cps_binding_initializer(schema, source, binding, initializer, None),
  ) catch {
    error => Err(error)
  }
  assert_eq(
    result,
    Err(
      BindingTypeMismatch(
        value=binding,
        expected=Primitive(Bool),
        actual=planned_type,
      ),
    ),
  )
}

///|
test "CPS binding validation accepts a narrower residual effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let expected : @buslane.Type = Function([], Primitive(Unit), Builtin(Io))
  let binding = metadata.define_value("binding", Local, expected)
  validate_cps_binding_type(
    metadata,
    binding,
    Function({
      parameters: [],
      result_type: Primitive(Unit),
      body: Literal(Unit),
    }),
  )
  assert_eq(metadata.value_info(binding).unwrap().type_, expected)
}

///|
test "CPS binding validation preserves declaration metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let first = metadata.define_value("first", Local, Primitive(I64))
  let second = metadata.define_value("second", Local, Primitive(I64))
  let result : Result[Unit, SynthesisError] = try {
    validate_cps_recursive_binding_types(metadata, [
      { id: first, rhs: Literal(Bool(true)) },
      { id: second, rhs: Literal(I64(1L)) },
    ])
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_eq(
    (
      result,
      metadata.value_info(first).unwrap().type_,
      metadata.value_info(second).unwrap().type_,
    ),
    (
      Err(
        BindingTypeMismatch(
          value=first,
          expected=Primitive(I64),
          actual=Primitive(Bool),
        ),
      ),
      Primitive(I64),
      Primitive(I64),
    ),
  )
}

///|
test "selective CPS composes an explicit bind continuation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let effectful = metadata.define_value(
    "effectful",
    External,
    Function([], Primitive(I64), latent),
  )
  let pure = metadata.define_value(
    "pure",
    External,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(I64), latent),
  )
  let local_value = metadata.define_value("local", Local, Primitive(I64))
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
            result_type: Primitive(I64),
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
    is LetRec(
      [{ rhs: TypeLambda([answer, residual], Function(transformed)), .. }]
    ) else {
    abort("expected CPS function")
  }
  guard transformed.parameters is [context, outer_continuation] else {
    abort("expected CPS parameters")
  }
  guard transformed.body
    is Call(
      TypeApply(
        Ref(callee),
        [TypeArgument(call_answer), EffectArgument(call_residual)]
      ),
      [Ref(call_context), Function(next)]
    ) else {
    abort("expected CPS call with local continuation")
  }
  assert_eq(callee, effectful)
  assert_eq(call_answer, Parameter(answer))
  assert_eq(call_residual, Parameter(residual))
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
    Function([], Primitive(I64), Parameter(effect_parameter)),
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
              result_type: Primitive(I64),
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
            [companion, effect_residual],
            TypeLambda([answer, residual], Function(transformed))
          ),
          ..,
        },
      ]
    ) else {
    abort("expected companion and answer type parameters")
  }
  assert_eq(
    metadata.type_parameter_info(companion).unwrap().kind,
    Function([Type, Effect], Type),
  )
  assert_eq(metadata.type_parameter_info(effect_residual).unwrap().kind, Effect)
  let row = @buslane.Effect::Union([
    Parameter(effect_residual),
    Parameter(residual),
  ])
  guard transformed.parameters is [context, continuation] else {
    abort("expected abstract context parameter")
  }
  assert_eq(
    metadata.value_info(context).unwrap().type_,
    Apply(Parameter(companion), [
      TypeArgument(Parameter(answer)),
      EffectArgument(row),
    ]),
  )
  guard transformed.body
    is Call(
      TypeApply(
        TypeApply(
          Ref(actual_callee),
          [
            TypeArgument(Parameter(forwarded_companion)),
            EffectArgument(Parameter(forwarded_residual)),
          ]
        ),
        [TypeArgument(call_answer), EffectArgument(call_residual)]
      ),
      [Ref(actual_context), Ref(actual_continuation)]
    ) else {
    abort("expected polymorphic companion argument")
  }
  assert_eq(actual_callee, callee)
  assert_eq(forwarded_companion, companion)
  assert_eq(forwarded_residual, effect_residual)
  assert_eq(call_answer, Parameter(answer))
  assert_eq(call_residual, row)
  assert_eq(actual_context, context)
  assert_eq(actual_continuation, continuation)
  assert_cps_ordinary_output(output)
}

///|
test "selective CPS calls a first-class effectful callable" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let latent : @buslane.Effect = Singleton(effect, [])
  let action_type : @buslane.Type = Function([], Primitive(I64), latent)
  let action = metadata.define_value("action", Parameter, action_type)
  let apply = metadata.define_value(
    "apply",
    Function,
    Function([action_type], Primitive(I64), latent),
  )
  let output = rewrite_test_program({
    metadata,
    terms: [
      LetRec([
        {
          id: apply,
          rhs: Function({
            parameters: [action],
            result_type: Primitive(I64),
            body: Call(Ref(action), []),
          }),
        },
      ]),
    ],
  })
  guard output.terms[0]
    is LetRec(
      [{ rhs: TypeLambda([answer, residual], Function(transformed)), .. }]
    ) else {
    abort("expected CPS apply function")
  }
  guard transformed.parameters is [context, transformed_action, continuation] else {
    abort("expected context, callable, and continuation")
  }
  assert_eq(transformed_action, action)
  assert_eq(
    transformed.body,
    Call(
      TypeApply(Ref(action), [
        TypeArgument(Parameter(answer)),
        EffectArgument(Parameter(residual)),
      ]),
      [Ref(context), Ref(continuation)],
    ),
  )
  guard metadata.value_info(action).unwrap().type_
    is Forall(
      [action_answer, action_residual],
      Function([_, action_continuation], action_result, action_latent)
    ) else {
    abort("expected first-class CPS callable type")
  }
  assert_eq(action_result, Parameter(action_answer))
  assert_eq(action_latent, Parameter(action_residual))
  assert_eq(
    action_continuation,
    Function(
      [Primitive(I64)],
      Parameter(action_answer),
      Parameter(action_residual),
    ),
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
    Function([], Primitive(I64), latent),
  )
  let second = metadata.define_value(
    "second",
    External,
    Function([], Primitive(I64), latent),
  )
  let combine = metadata.define_value(
    "combine",
    External,
    Function([Primitive(I64), Primitive(I64)], Primitive(I64), Empty),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(I64), latent),
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
            result_type: Primitive(I64),
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
    is LetRec([{ rhs: TypeLambda([answer, _], Function(transformed)), .. }]) else {
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
    Function([], Primitive(I64), latent),
  )
  let pure = metadata.define_value(
    "pure",
    External,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(I64), latent),
  )
  let match_binder = metadata.define_value(
    "match",
    MatchBinder,
    Primitive(Bool),
  )
  let local_value = metadata.define_value("local", Local, Primitive(I64))
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
            result_type: Primitive(I64),
            body: Let(
              local_value,
              Match({
                scrutinee: Literal(Bool(true)),
                binder: match_binder,
                result_type: Primitive(I64),
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
                    body: Literal(I64(0L)),
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
    is LetRec([{ rhs: TypeLambda([answer, _], Function(transformed)), .. }]) else {
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
    is Call(second_continuation, [Literal(I64(0L))]) else {
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
  ignore(metadata.define_operation("first", effect, [], [], Primitive(I64)))
  let operation = metadata.define_operation(
    "second",
    effect,
    [hidden],
    [Parameter(hidden), Parameter(element)],
    Primitive(Unit),
  )
  let latent = @buslane.Effect::Singleton(effect, [TypeArgument(Primitive(I64))])
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
              effect_arguments: [TypeArgument(Primitive(I64))],
              hidden_witnesses: [TypeArgument(Primitive(String))],
              payloads: [Literal(String("payload")), Literal(I64(1L))],
            }),
          }),
        },
      ]),
    ],
  })
  guard output.terms[0]
    is LetRec([{ rhs: TypeLambda([answer, _], Function(transformed)), .. }]) else {
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
      Literal(I64(1L)),
      Ref(continuation),
    ]),
  )
  assert_eq(transformed.result_type, Parameter(answer))
  assert_cps_ordinary_output(output)
}
