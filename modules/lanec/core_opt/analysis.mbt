///|
/// Whether an expression is known to perform nothing.
///
/// An expression the facts query cannot synthesize is treated as performing
/// something. The optimizer only ever uses this to decide whether removing a
/// computation is safe, so the unknown case has a safe answer, and answering it
/// beats aborting a compilation over a defect somewhere upstream.
fn expression_has_empty_effect(
  facts : @buslane.ExpressionFactsQuery,
  expression : @buslane.Expr,
) -> Bool {
  match facts.has_empty_effect(expression) {
    Ok(result) => result
    Err(_) => false
  }
}

///|
fn count_value_uses(
  expression : @buslane.Expr,
  value : @buslane.ValueId,
) -> Int {
  match expression {
    Ref(reference) | Resume(reference) => if reference == value { 1 } else { 0 }
    Literal(_) => 0
    Function(function) => count_value_uses(function.body, value)
    Call(callee, arguments) => {
      let mut count = count_value_uses(callee, value)
      for argument in arguments {
        count = count + count_value_uses(argument, value)
      }
      count
    }
    TypeLambda(_, body) | TypeApply(body, _) => count_value_uses(body, value)
    Construct(construct) =>
      construct.payloads.fold(init=0, fn(count, payload) {
        count + count_value_uses(payload, value)
      })
    Let(_, initializer, body) =>
      count_value_uses(initializer, value) + count_value_uses(body, value)
    LetRec(bindings, body) => {
      let mut count = count_value_uses(body, value)
      for binding in bindings {
        count = count + count_value_uses(binding.rhs, value)
      }
      count
    }
    Match(match_) => {
      let mut count = count_value_uses(match_.scrutinee, value)
      for alternative in match_.alternatives {
        count = count + count_value_uses(alternative.body, value)
      }
      count
    }
    Perform(perform) =>
      perform.payloads.fold(init=0, fn(count, payload) {
        count + count_value_uses(payload, value)
      })
    Handle(handle) => {
      let mut count = count_value_uses(handle.body, value) +
        count_value_uses(handle.final_body, value)
      for table in handle.handlers {
        for operation in table.operations {
          count = count + count_value_uses(operation.body, value)
        }
      }
      count
    }
  }
}

///|
fn prune_unreachable(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> @buslane.Program {
  @occurrence.retain_reachable_top_terms(program, [entry] + roots)
}
