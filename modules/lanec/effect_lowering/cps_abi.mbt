///|
priv struct CpsContextBinding {
  term : @buslane.Effect
  value : Expr
}

///|
priv struct CpsEnvironment {
  effect : @buslane.Effect
  bindings : Array[CpsContextBinding]
}

///|
pub fn rewrite_selective_cps_abis(
  program : Program,
) -> Result[Program, SynthesisError] {
  Ok(rewrite_selective_cps_abis_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn rewrite_selective_cps_abis_or_raise(
  program : Program,
) -> Program raise SynthesisError {
  let counts = CpsSourceCounts::{
    types: program.metadata.types.length(),
    data_constructors: program.metadata.data_constructors.length(),
    values: program.metadata.values.length(),
  }
  let schema = build_dictionary_cps_schema_or_raise(program.metadata)
  let terms = program.terms.map(term => {
    lower_cps_top_term(schema, program, term)
  })
  rewrite_cps_source_metadata(schema, counts)
  { metadata: program.metadata, terms }
}

///|
fn lower_cps_top_term(
  schema : DictionaryCpsSchema,
  program : Program,
  term : TopTerm,
) -> TopTerm raise SynthesisError {
  match term {
    Let(id, expression) => {
      let facts = synthesize_expr_or_raise(program.metadata, expression)
      if facts.effect == Empty {
        Let(id, lower_cps_direct_expr(schema, program, expression, None))
      } else {
        raise UnsupportedTopLevelEffect(facts.effect)
      }
    }
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lower_cps_recursable(schema, program, binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn lower_cps_recursable(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
) -> Expr raise SynthesisError {
  match expression {
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(parameter => schema.companion_parameter(parameter)),
        lower_cps_recursable(schema, program, body),
      )
    Function(function) => lower_cps_function(schema, program, function)
    _ => lower_cps_direct_expr(schema, program, expression, None)
  }
}

///|
fn lower_cps_function(
  schema : DictionaryCpsSchema,
  program : Program,
  function : FunctionExpr,
) -> Expr raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(program.metadata, function.body)
  let result_type = schema.rewrite_type(function.result_type)
  if body_facts.effect == Empty {
    Function({
      parameters: function.parameters,
      result_type,
      body: lower_cps_direct_expr(schema, program, function.body, None),
    })
  } else {
    let answer_parameter = program.metadata.define_type_parameter(
      "%answer",
      Type,
    )
    let answer_type = @buslane.Type::Parameter(answer_parameter)
    let context_terms = effect_terms(body_facts.effect)
    let context_parameters = []
    let bindings = []
    for term in context_terms {
      let parameter = program.metadata.define_value(
        "%context",
        Parameter,
        schema.context_term_type(term, answer_type),
      )
      context_parameters.push(parameter)
      bindings.push({ term, value: Ref(parameter) })
    }
    let continuation = program.metadata.define_value(
      "%continuation",
      Parameter,
      Function([result_type], answer_type, Empty),
    )
    let environment = CpsEnvironment::{ effect: body_facts.effect, bindings }
    TypeLambda(
      [answer_parameter],
      Function({
        parameters: context_parameters + function.parameters + [continuation],
        result_type: answer_type,
        body: lower_cps_with_continuation(
          schema,
          program,
          function.body,
          environment,
          answer_type,
          Ref(continuation),
        ),
      }),
    )
  }
}

///|
fn lower_cps_direct_expr(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  current_answer : @buslane.Type?,
) -> Expr raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => expression
    Function(function) => lower_cps_function(schema, program, function)
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(parameter => schema.companion_parameter(parameter)),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    Call(callee, arguments) => {
      let callee_facts = synthesize_expr_or_raise(program.metadata, callee)
      guard callee_facts.type_ is Function(_, _, latent_effect) else {
        raise ExpectedFunction(callee_facts.type_)
      }
      if latent_effect != Empty {
        raise MissingEffectContext(latent_effect)
      }
      Call(
        lower_cps_direct_expr(schema, program, callee, current_answer),
        arguments.map(argument => {
          lower_cps_direct_expr(schema, program, argument, current_answer)
        }),
      )
    }
    TypeApply(_, _) =>
      lower_cps_type_apply_chain(
        schema,
        program,
        expression,
        answer_or_unit(current_answer),
      )
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments.map(argument => {
          rewrite_cps_expression_argument(schema, argument, current_answer)
        }),
        hidden_witnesses: construct.hidden_witnesses.map(argument => {
          rewrite_cps_expression_argument(schema, argument, current_answer)
        }),
        payloads: construct.payloads.map(payload => {
          lower_cps_direct_expr(schema, program, payload, current_answer)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        id,
        lower_cps_direct_expr(schema, program, initializer, current_answer),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lower_cps_recursable(schema, program, binding.rhs),
        }),
        lower_cps_direct_expr(schema, program, body, current_answer),
      )
    Match(match_) =>
      Match({
        scrutinee: lower_cps_direct_expr(
          schema,
          program,
          match_.scrutinee,
          current_answer,
        ),
        binder: match_.binder,
        result_type: schema.rewrite_type(match_.result_type),
        alternatives: match_.alternatives.map(alternative => {
          alt_constructor: alternative.alt_constructor,
          type_binders: alternative.type_binders.map(parameter => {
            schema.companion_parameter(parameter)
          }),
          value_binders: alternative.value_binders,
          body: lower_cps_direct_expr(
            schema,
            program,
            alternative.body,
            current_answer,
          ),
        }),
      })
    Invoke(invoke) =>
      Invoke({
        ..invoke,
        payloads: invoke.payloads.map(payload => {
          lower_cps_direct_expr(schema, program, payload, current_answer)
        }),
      })
    Install(install) => lower_cps_direct_install(schema, program, install)
    Bind(_) | OpenContext(_) => expression
  }
}

///|
fn lower_cps_with_continuation(
  schema : DictionaryCpsSchema,
  program : Program,
  expression : Expr,
  environment : CpsEnvironment,
  answer_type : @buslane.Type,
  continuation : Expr,
) -> Expr raise SynthesisError {
  match expression {
    Let(id, initializer, body) => {
      let initializer_facts = synthesize_expr_or_raise(
        program.metadata,
        initializer,
      )
      if initializer_facts.effect == Empty {
        Let(
          id,
          lower_cps_direct_expr(schema, program, initializer, Some(answer_type)),
          lower_cps_with_continuation(
            schema, program, body, environment, answer_type, continuation,
          ),
        )
      } else {
        lower_cps_residual_bind(
          schema, program, expression, environment, answer_type, continuation,
        )
      }
    }
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lower_cps_recursable(schema, program, binding.rhs),
        }),
        lower_cps_with_continuation(
          schema, program, body, environment, answer_type, continuation,
        ),
      )
    Bind(bind) => {
      let next = Function({
        parameters: [bind.binder],
        result_type: answer_type,
        body: lower_cps_with_continuation(
          schema,
          program,
          bind.continuation.body,
          environment,
          answer_type,
          continuation,
        ),
      })
      lower_cps_computation(
        schema,
        program,
        bind.computation,
        environment,
        answer_type,
        next,
        Some(bind.binder),
      )
    }
    Call(callee, arguments) => {
      let callee_facts = synthesize_expr_or_raise(program.metadata, callee)
      guard callee_facts.type_ is Function(_, _, latent_effect) else {
        raise ExpectedFunction(callee_facts.type_)
      }
      if latent_effect == Empty {
        Call(continuation, [
          lower_cps_direct_expr(
            schema,
            program,
            Call(callee, arguments),
            Some(answer_type),
          ),
        ])
      } else {
        lower_cps_monadic_call(
          schema, program, callee, arguments, environment, answer_type, continuation,
          latent_effect, false,
        )
      }
    }
    Match(match_) => {
      let facts = synthesize_expr_or_raise(program.metadata, expression)
      if facts.effect == Empty {
        Call(continuation, [
          lower_cps_direct_expr(schema, program, expression, Some(answer_type)),
        ])
      } else {
        lower_cps_monadic_match(
          schema, program, match_, environment, answer_type, continuation,
        )
      }
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
          OpenContext({
            ..open,
            body: lower_cps_with_continuation(
              schema,
              program,
              open.body,
              environment,
              answer_type,
              continuation,
            ),
          })
      }
    Invoke(_) | Install(_) =>
      lower_cps_computation(
        schema,
        program,
        expression,
        environment,
        answer_type,
        continuation,
        None,
      )
    Ref(_)
    | Literal(_)
    | Function(_)
    | TypeLambda(_, _)
    | TypeApply(_, _)
    | Construct(_) =>
      Call(continuation, [
        lower_cps_direct_expr(schema, program, expression, Some(answer_type)),
      ])
  }
}
