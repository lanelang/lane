///|
pub fn lift_monadic_continuations(
  program : Program,
) -> Result[@buslane.Program, SynthesisError] {
  Ok(lift_monadic_continuations_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn lift_monadic_continuations_or_raise(
  program : Program,
) -> @buslane.Program raise SynthesisError {
  validate_open_resolve_output_or_raise(program)
  {
    metadata: program.metadata,
    terms: program.terms.map(lift_monadic_top_term),
  }
}

///|
fn lift_monadic_top_term(
  term : TopTerm,
) -> @buslane.TopTerm raise SynthesisError {
  match term {
    Let(id, expression) => Let(id, lift_monadic_expr(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lift_monadic_expr(binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn lift_monadic_expr(expression : Expr) -> @buslane.Expr raise SynthesisError {
  match expression {
    Ref(id) => Ref(id)
    Literal(literal) => Literal(literal)
    Function(function) =>
      Function({
        parameters: function.parameters,
        result_type: function.result_type,
        body: lift_monadic_expr(function.body),
      })
    Call(callee, arguments) =>
      Call(lift_monadic_expr(callee), arguments.map(lift_monadic_expr))
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, lift_monadic_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(lift_monadic_expr(callee), arguments)
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_witnesses: construct.hidden_witnesses,
        payloads: construct.payloads.map(lift_monadic_expr),
      })
    Let(id, initializer, body) =>
      Let(id, lift_monadic_expr(initializer), lift_monadic_expr(body))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lift_monadic_expr(binding.rhs),
        }),
        lift_monadic_expr(body),
      )
    Match(match_) =>
      Match({
        scrutinee: lift_monadic_expr(match_.scrutinee),
        binder: match_.binder,
        result_type: match_.result_type,
        alternatives: match_.alternatives.map(alternative => {
          alt_constructor: alternative.alt_constructor,
          type_binders: alternative.type_binders,
          value_binders: alternative.value_binders,
          body: lift_monadic_expr(alternative.body),
        }),
      })
    Invoke(invoke) => raise ResidualInvoke(invoke.operation)
    Install(_) => raise ResidualInstall
    Bind(_) => raise ResidualBind
    OpenContext(open) =>
      raise ResidualOpenContext(
        source=open.source_effect,
        target=open.target_effect,
      )
  }
}
