///|
priv enum ExprContinuation {
  Identity
  Then((Expr) -> Expr raise SynthesisError)
}

///|
pub fn introduce_monadic_binds(
  program : Program,
) -> Result[Program, SynthesisError] {
  Ok(introduce_monadic_binds_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn introduce_monadic_binds_or_raise(
  program : Program,
) -> Program raise SynthesisError {
  {
    metadata: program.metadata,
    terms: program.terms.map(term => transform_top_term(program, term)),
  }
}

///|
fn transform_top_term(
  program : Program,
  term : TopTerm,
) -> TopTerm raise SynthesisError {
  match term {
    Let(id, expression) => {
      let facts = synthesize_expr_or_raise(program.metadata, expression)
      Let(
        id,
        transform_expr(program, expression, facts.effect, facts.type_, Identity),
      )
    }
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: transform_recursable(program, binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn transform_recursable(
  program : Program,
  expression : Expr,
) -> Expr raise SynthesisError {
  match expression {
    Function(function) => Function(transform_function(program, function))
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, transform_recursable(program, body))
    _ => {
      let facts = synthesize_expr_or_raise(program.metadata, expression)
      transform_expr(program, expression, facts.effect, facts.type_, Identity)
    }
  }
}

///|
fn transform_function(
  program : Program,
  function : FunctionExpr,
) -> FunctionExpr raise SynthesisError {
  let body_facts = synthesize_expr_or_raise(program.metadata, function.body)
  {
    parameters: function.parameters,
    result_type: function.result_type,
    body: transform_expr(
      program,
      function.body,
      body_facts.effect,
      function.result_type,
      Identity,
    ),
  }
}

///|
fn transform_expr(
  program : Program,
  expression : Expr,
  ambient_effect : @buslane.Effect,
  answer_type : @buslane.Type,
  continuation : ExprContinuation,
) -> Expr raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => continuation.apply(expression)
    Function(function) =>
      continuation.apply(Function(transform_function(program, function)))
    TypeLambda(parameters, body) =>
      continuation.apply(
        TypeLambda(parameters, transform_recursable(program, body)),
      )
    Call(callee, arguments) =>
      transform_expr(
        program,
        callee,
        ambient_effect,
        answer_type,
        Then(transformed_callee => {
          transform_values(
            program,
            arguments,
            0,
            [],
            ambient_effect,
            answer_type,
            transformed_arguments => {
              finish_call(
                program, callee, transformed_callee, transformed_arguments, ambient_effect,
                answer_type, continuation,
              )
            },
          )
        }),
      )
    TypeApply(callee, arguments) =>
      transform_expr(
        program,
        callee,
        ambient_effect,
        answer_type,
        Then(transformed_callee => {
          continuation.apply(TypeApply(transformed_callee, arguments))
        }),
      )
    Construct(construct) =>
      transform_values(
        program,
        construct.payloads,
        0,
        [],
        ambient_effect,
        answer_type,
        payloads => {
          continuation.apply(
            Construct({
              data_constructor: construct.data_constructor,
              type_arguments: construct.type_arguments,
              hidden_witnesses: construct.hidden_witnesses,
              payloads,
            }),
          )
        },
      )
    Let(id, initializer, body) =>
      transform_expr(
        program,
        initializer,
        ambient_effect,
        answer_type,
        Then(value => {
          Let(
            id,
            value,
            transform_expr(
              program, body, ambient_effect, answer_type, continuation,
            ),
          )
        }),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: transform_recursable(program, binding.rhs),
        }),
        transform_expr(program, body, ambient_effect, answer_type, continuation),
      )
    Match(match_) =>
      transform_expr(
        program,
        match_.scrutinee,
        ambient_effect,
        answer_type,
        Then(scrutinee => {
          finish_match(
            program, match_, scrutinee, ambient_effect, answer_type, continuation,
          )
        }),
      )
    Invoke(invoke) =>
      transform_values(
        program,
        invoke.payloads,
        0,
        [],
        ambient_effect,
        answer_type,
        payloads => {
          let invocation = Expr::Invoke({ ..invoke, payloads, })
          bind_computation(
            program,
            invocation,
            synthesize_expr_or_raise(program.metadata, invocation).type_,
            answer_type,
            continuation,
          )
        },
      )
    Install(install) => {
      let transformed = Expr::Install({
        body: transform_with_identity(program, install.body),
        result_type: install.result_type,
        dictionaries: install.dictionaries.map(dictionary => {
          handled_effect: dictionary.handled_effect,
          operations: dictionary.operations.map(operation => {
            operation: operation.operation,
            callable: transform_clause_callable(program, operation.callable),
          }),
        }),
        final_clause: transform_function(program, install.final_clause),
      })
      let effect = synthesize_expr_or_raise(program.metadata, transformed).effect
      if effect == Empty {
        continuation.apply(transformed)
      } else {
        bind_computation(
          program,
          transformed,
          install.result_type,
          answer_type,
          continuation,
        )
      }
    }
    Bind(_) | OpenContext(_) => continuation.apply(expression)
  }
}

///|
fn finish_call(
  program : Program,
  original_callee : Expr,
  callee : Expr,
  arguments : Array[Expr],
  ambient_effect : @buslane.Effect,
  answer_type : @buslane.Type,
  continuation : ExprContinuation,
) -> Expr raise SynthesisError {
  let callee_facts = synthesize_expr_or_raise(program.metadata, original_callee)
  guard callee_facts.type_ is Function(_, result_type, latent_effect) else {
    raise ExpectedFunction(callee_facts.type_)
  }
  let call = Expr::Call(callee, arguments)
  if latent_effect == Empty {
    continuation.apply(call)
  } else {
    let computation = if latent_effect == ambient_effect {
      call
    } else {
      OpenContext({
        source_effect: latent_effect,
        target_effect: ambient_effect,
        body: call,
      })
    }
    bind_computation(
      program, computation, result_type, answer_type, continuation,
    )
  }
}

///|
fn finish_match(
  program : Program,
  match_ : MatchExpr,
  scrutinee : Expr,
  ambient_effect : @buslane.Effect,
  answer_type : @buslane.Type,
  continuation : ExprContinuation,
) -> Expr raise SynthesisError {
  let mut monadic_branch = false
  let alternatives = match_.alternatives.map(alternative => {
    let facts = synthesize_expr_or_raise(program.metadata, alternative.body)
    if facts.effect != Empty {
      monadic_branch = true
    }
    {
      alt_constructor: alternative.alt_constructor,
      type_binders: alternative.type_binders,
      value_binders: alternative.value_binders,
      body: transform_expr(
        program,
        alternative.body,
        ambient_effect,
        match_.result_type,
        Identity,
      ),
    }
  })
  let transformed = Expr::Match({ ..match_, scrutinee, alternatives })
  if monadic_branch {
    bind_computation(
      program,
      transformed,
      match_.result_type,
      answer_type,
      continuation,
    )
  } else {
    continuation.apply(transformed)
  }
}

///|
fn transform_values(
  program : Program,
  expressions : Array[Expr],
  index : Int,
  values : Array[Expr],
  ambient_effect : @buslane.Effect,
  answer_type : @buslane.Type,
  continuation : (Array[Expr]) -> Expr raise SynthesisError,
) -> Expr raise SynthesisError {
  if index == expressions.length() {
    return continuation(values)
  }
  transform_expr(
    program,
    expressions[index],
    ambient_effect,
    answer_type,
    Then(value => {
      let next_values = values.copy()
      next_values.push(value)
      transform_values(
        program,
        expressions,
        index + 1,
        next_values,
        ambient_effect,
        answer_type,
        continuation,
      )
    }),
  )
}

///|
fn transform_with_identity(
  program : Program,
  expression : Expr,
) -> Expr raise SynthesisError {
  let facts = synthesize_expr_or_raise(program.metadata, expression)
  transform_expr(program, expression, facts.effect, facts.type_, Identity)
}

///|
fn transform_clause_callable(
  program : Program,
  callable : ClauseCallable,
) -> ClauseCallable raise SynthesisError {
  match callable {
    Monomorphic(function) => Monomorphic(transform_function(program, function))
    Polymorphic(parameters, function) =>
      Polymorphic(parameters, transform_function(program, function))
  }
}

///|
fn bind_computation(
  program : Program,
  computation : Expr,
  value_type : @buslane.Type,
  answer_type : @buslane.Type,
  continuation : ExprContinuation,
) -> Expr raise SynthesisError {
  match continuation {
    Identity => computation
    Then(next) => {
      let binder = program.metadata.define_value("%bind", Parameter, value_type)
      Bind({
        computation,
        binder,
        continuation: {
          parameters: [binder],
          result_type: answer_type,
          body: next(Ref(binder)),
        },
      })
    }
  }
}

///|
fn ExprContinuation::apply(
  self : ExprContinuation,
  value : Expr,
) -> Expr raise SynthesisError {
  match self {
    Identity => value
    Then(next) => next(value)
  }
}
