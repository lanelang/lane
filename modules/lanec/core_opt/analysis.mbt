///|
fn expression_is_pure(
  program : @buslane.Program,
  expression : @buslane.Expr,
) -> Bool {
  match expression {
    Ref(_) | Literal(_) | Function(_) => true
    Call(_, _) => false
    TypeLambda(_, body) | TypeApply(body, _) =>
      expression_is_pure(program, body)
    Construct(construct) =>
      construct.payloads.all(payload => expression_is_pure(program, payload))
    Let(_, initializer, body) =>
      expression_is_pure(program, initializer) &&
      expression_is_pure(program, body)
    LetRec(bindings, body) =>
      bindings.all(binding => expression_is_pure(program, binding.rhs)) &&
      expression_is_pure(program, body)
    Match(match_) =>
      expression_is_pure(program, match_.scrutinee) &&
      match_.alternatives.all(alternative => {
        expression_is_pure(program, alternative.body)
      })
    Perform(_) | Handle(_) | Resume(_) => false
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
  let summary = @occurrence.analyze({ program, entry, roots })
  let terms = []
  for term in program.terms {
    match term {
      Let(value, _) if value_is_reachable(summary, value) => terms.push(term)
      LetRec(bindings) => {
        let reachable = bindings.filter(binding => {
          value_is_reachable(summary, binding.id)
        })
        if !reachable.is_empty() {
          terms.push(LetRec(reachable))
        }
      }
      External(value) if value_is_reachable(summary, value) => terms.push(term)
      _ => ()
    }
  }
  { ..program, terms, }
}

///|
fn value_is_reachable(
  summary : @occurrence.OccurrenceSummary,
  value : @buslane.ValueId,
) -> Bool {
  match summary.facts.get(value.index) {
    Some(fact) => fact.reachable_from_entry
    None => false
  }
}
