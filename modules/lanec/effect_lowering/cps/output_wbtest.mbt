///|
fn assert_cps_ordinary_output(program : Program) -> Unit raise {
  let ordinary = @buslane.Program::{
    metadata: program.metadata,
    terms: program.terms.map(cps_ordinary_top_term),
  }
  assert_true(@buslane.verify_program(ordinary).is_ok())
}

///|
fn cps_ordinary_top_term(term : TopTerm) -> @buslane.TopTerm {
  match term {
    Let(id, expression) => Let(id, cps_ordinary_expr(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: cps_ordinary_expr(binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn cps_ordinary_expr(expression : Expr) -> @buslane.Expr {
  match expression {
    Ref(id) => Ref(id)
    Literal(literal) => Literal(literal)
    Function(function) => Function(cps_ordinary_function(function))
    Call(callee, arguments) =>
      Call(cps_ordinary_expr(callee), arguments.map(cps_ordinary_expr))
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, cps_ordinary_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(cps_ordinary_expr(callee), arguments)
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_witnesses: construct.hidden_witnesses,
        payloads: construct.payloads.map(cps_ordinary_expr),
      })
    Let(id, initializer, body) =>
      Let(id, cps_ordinary_expr(initializer), cps_ordinary_expr(body))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: cps_ordinary_expr(binding.rhs),
        }),
        cps_ordinary_expr(body),
      )
    Match(match_) =>
      Match({
        scrutinee: cps_ordinary_expr(match_.scrutinee),
        binder: match_.binder,
        result_type: match_.result_type,
        alternatives: match_.alternatives.map(alternative => {
          alt_constructor: alternative.alt_constructor,
          type_binders: alternative.type_binders,
          value_binders: alternative.value_binders,
          body: cps_ordinary_expr(alternative.body),
        }),
      })
    Invoke(_) | Install(_) | Bind(_) | OpenContext(_) =>
      abort("expected ordinary selective-CPS output")
  }
}

///|
fn cps_ordinary_function(function : FunctionExpr) -> @buslane.FunctionExpr {
  {
    parameters: function.parameters,
    result_type: function.result_type,
    body: cps_ordinary_expr(function.body),
  }
}
