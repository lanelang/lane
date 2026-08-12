///|
/// Whether a verified expression performs nothing.
///
/// Core optimization consumes expression facts after the Buslane verifier has
/// accepted the program. Failure here therefore means an upstream compiler
/// invariant was broken; treating it as an effect would hide that defect and
/// make optimization decisions depend on a failed analysis.
fn expression_has_empty_effect(
  facts : @buslane.ExpressionFactsQuery,
  expression : @buslane.Expr,
) -> Bool raise CoreOptimizeError {
  match facts.has_empty_effect(expression) {
    Ok(result) => result
    Err(result) => raise ExpressionFactsCompilerDefect(result)
  }
}

///|
fn expression_facts(
  facts : @buslane.ExpressionFactsQuery,
  expression : @buslane.Expr,
) -> @buslane.ExpressionFacts raise CoreOptimizeError {
  match facts.synthesize(expression) {
    Ok(result) => result
    Err(result) => raise ExpressionFactsCompilerDefect(result)
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
fn core_program_call_count(program : @buslane.Program) -> Int {
  let mut count = 0
  for term in program.terms {
    match term {
      Let(_, expression) => count += core_expression_call_count(expression)
      LetRec(bindings) =>
        for binding in bindings {
          count += core_expression_call_count(binding.rhs)
        }
      External(_) => ()
    }
  }
  count
}

///|
fn core_expression_call_count(expression : @buslane.Expr) -> Int {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => 0
    Function(function) => core_expression_call_count(function.body)
    Call(callee, arguments) => {
      let mut count = 1 + core_expression_call_count(callee)
      for argument in arguments {
        count += core_expression_call_count(argument)
      }
      count
    }
    TypeLambda(_, body) | TypeApply(body, _) => core_expression_call_count(body)
    Construct(construct) =>
      construct.payloads.fold(init=0, fn(count, payload) {
        count + core_expression_call_count(payload)
      })
    Let(_, initializer, body) =>
      core_expression_call_count(initializer) + core_expression_call_count(body)
    LetRec(bindings, body) => {
      let mut count = core_expression_call_count(body)
      for binding in bindings {
        count += core_expression_call_count(binding.rhs)
      }
      count
    }
    Match(match_) => {
      let mut count = core_expression_call_count(match_.scrutinee)
      for alternative in match_.alternatives {
        count += core_expression_call_count(alternative.body)
      }
      count
    }
    Perform(perform) =>
      perform.payloads.fold(init=0, fn(count, payload) {
        count + core_expression_call_count(payload)
      })
    Handle(handle) => {
      let mut count = core_expression_call_count(handle.body) +
        core_expression_call_count(handle.final_body)
      for table in handle.handlers {
        for operation in table.operations {
          count += core_expression_call_count(operation.body)
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
