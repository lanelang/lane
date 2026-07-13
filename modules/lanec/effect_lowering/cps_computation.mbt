///|
fn lower_cps_computation(
  schema : DictionaryCpsSchema,
  program : Program,
  computation : Expr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
  binder : @buslane.ValueId?,
) -> Expr raise SynthesisError {
  match computation {
    Call(callee, arguments) => {
      let callee_facts = synthesize_expr_or_raise(program.metadata, callee)
      guard callee_facts.type_ is Function(_, _, latent_effect) else {
        raise ExpectedFunction(callee_facts.type_)
      }
      lower_cps_monadic_call(
        schema, program, callee, arguments, environment, answer_type, continuation,
        latent_effect, false,
      )
    }
    OpenContext(open) =>
      match open.body {
        Call(callee, arguments) =>
          lower_cps_monadic_call(
            schema,
            program,
            callee,
            arguments,
            environment,
            answer_type,
            continuation,
            open.source_effect,
            true,
          )
        _ =>
          lower_cps_residual_computation(
            schema, program, computation, answer_type, continuation, binder,
          )
      }
    Match(match_) =>
      lower_cps_monadic_match(
        schema, program, match_, environment, answer_type, continuation,
      )
    Invoke(invoke) =>
      lower_cps_invoke(
        schema, program, invoke, environment, answer_type, continuation,
      )
    Install(_) =>
      lower_cps_residual_computation(
        schema, program, computation, answer_type, continuation, binder,
      )
    _ =>
      lower_cps_with_continuation(
        schema, program, computation, environment, answer_type, continuation,
      )
  }
}

///|
fn lower_cps_monadic_call(
  schema : DictionaryCpsSchema,
  program : Program,
  callee : Expr,
  arguments : Array[Expr],
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
  latent_effect : @buslane.Effect,
  force_open : Bool,
) -> Expr raise SynthesisError {
  let requirements = cps_call_context_requirements(program.metadata, callee)
  let selected = select_cps_contexts(
    schema, requirements, environment, answer_type,
  )
  let transformed_callee = TypeApply(
    lower_cps_type_apply_chain(schema, program, callee, answer_type),
    [TypeArgument(answer_type)],
  )
  let call = Expr::Call(
    transformed_callee,
    selected.values +
    arguments.map(argument => {
      lower_cps_direct_expr(schema, program, argument, Some(answer_type))
    }) +
    [continuation],
  )
  if force_open || selected.adapted || latent_effect != environment.effect {
    OpenContext({
      source_effect: latent_effect,
      target_effect: environment.effect,
      body: call,
    })
  } else {
    call
  }
}

///|
fn lower_cps_monadic_match(
  schema : DictionaryCpsSchema,
  program : Program,
  match_ : MatchExpr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  Match({
    scrutinee: lower_cps_direct_expr(
      schema,
      program,
      match_.scrutinee,
      Some(answer_type),
    ),
    binder: match_.binder,
    result_type: answer_type,
    alternatives: match_.alternatives.map(alternative => {
      alt_constructor: alternative.alt_constructor,
      type_binders: alternative.type_binders.map(parameter => {
        schema.companion_parameter(parameter)
      }),
      value_binders: alternative.value_binders,
      body: lower_cps_with_continuation(
        schema,
        program,
        alternative.body,
        environment,
        answer_type,
        continuation,
      ),
    }),
  })
}

///|
fn lower_cps_residual_bind(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  let facts = synthesize_expr_or_raise(program.metadata, expression)
  let binder = program.metadata.define_value(
    "%residual",
    Parameter,
    schema.rewrite_type(facts.type_),
  )
  lower_cps_residual_computation(
    schema,
    program,
    expression,
    answer_type,
    Function({
      parameters: [binder],
      result_type: answer_type,
      body: lower_cps_with_continuation(
        schema,
        program,
        Ref(binder),
        environment,
        answer_type,
        continuation,
      ),
    }),
    Some(binder),
  )
}

///|
fn lower_cps_residual_computation(
  schema : DictionaryCpsSchema,
  program : Program,
  computation : Expr,
  answer_type : @buslane.Type,
  continuation : Expr,
  binder : @buslane.ValueId?,
) -> Expr raise SynthesisError {
  let value_type = schema.rewrite_type(
    synthesize_expr_or_raise(program.metadata, computation).type_,
  )
  let parameter = match binder {
    Some(parameter) => parameter
    None => program.metadata.define_value("%residual", Parameter, value_type)
  }
  Bind({
    computation,
    binder: parameter,
    continuation: {
      parameters: [parameter],
      result_type: answer_type,
      body: Call(continuation, [Ref(parameter)]),
    },
  })
}
