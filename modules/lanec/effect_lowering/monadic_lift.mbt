///|
fn lift_monadic_continuations_or_raise(
  program : Program,
) -> (@buslane.Program, @function_origin.FunctionOriginCatalog) raise SynthesisError {
  validate_open_resolve_output_or_raise(program)
  let function_origins = @function_origin.FunctionOriginCatalog::new()
  let lowered : @buslane.Program = {
    metadata: program.metadata,
    terms: program.terms.map(term => {
      lift_monadic_top_term(term, function_origins)
    }),
  }
  (lowered, function_origins)
}

///|
fn lift_monadic_top_term(
  term : TopTerm,
  function_origins : @function_origin.FunctionOriginCatalog,
) -> @buslane.TopTerm raise SynthesisError {
  match term {
    Let(id, expression) =>
      Let(id, lift_monadic_expr(expression, function_origins))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lift_monadic_expr(binding.rhs, function_origins),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn lift_monadic_expr(
  expression : Expr,
  function_origins : @function_origin.FunctionOriginCatalog,
) -> @buslane.Expr raise SynthesisError {
  match expression {
    Ref(id) => Ref(id)
    Literal(literal) => Literal(literal)
    Function(function) => {
      let lowered : @buslane.FunctionExpr = {
        parameters: function.parameters,
        result_type: function.result_type,
        body: lift_monadic_expr(function.body, function_origins),
      }
      if !function_origins.record(lowered, function.origin) {
        raise FunctionOriginCompilerDefect
      }
      Function(lowered)
    }
    Call(callee, arguments) =>
      Call(
        lift_monadic_expr(callee, function_origins),
        arguments.map(argument => lift_monadic_expr(argument, function_origins)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, lift_monadic_expr(body, function_origins))
    TypeApply(callee, arguments) =>
      TypeApply(lift_monadic_expr(callee, function_origins), arguments)
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_witnesses: construct.hidden_witnesses,
        payloads: construct.payloads.map(payload => {
          lift_monadic_expr(payload, function_origins)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        id,
        lift_monadic_expr(initializer, function_origins),
        lift_monadic_expr(body, function_origins),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: lift_monadic_expr(binding.rhs, function_origins),
        }),
        lift_monadic_expr(body, function_origins),
      )
    Match(match_) =>
      Match({
        scrutinee: lift_monadic_expr(match_.scrutinee, function_origins),
        binder: match_.binder,
        result_type: match_.result_type,
        alternatives: match_.alternatives.map(alternative => {
          alt_constructor: alternative.alt_constructor,
          type_binders: alternative.type_binders,
          value_binders: alternative.value_binders,
          body: lift_monadic_expr(alternative.body, function_origins),
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
