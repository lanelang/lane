///|
/// Bounds optimizer work and whole-program growth in units of the input program.
/// It deliberately does not count expansions or impose a per-callee quota.
priv struct PartialEvaluationBudget {
  maximum_program_size : Int
  mut remaining_work : Int
}

///|
fn PartialEvaluationBudget::new(
  initial_program_size : Int,
) -> PartialEvaluationBudget {
  {
    maximum_program_size: initial_program_size +
    max_int(256, initial_program_size / 4),
    remaining_work: max_int(4096, initial_program_size * 128),
  }
}

///|
fn PartialEvaluationBudget::consume(
  self : PartialEvaluationBudget,
  work : Int,
) -> Bool {
  if work > self.remaining_work {
    self.remaining_work = 0
    return false
  }
  self.remaining_work = self.remaining_work - work
  true
}

///|
fn PartialEvaluationBudget::accepts_program_size(
  self : PartialEvaluationBudget,
  program_size : Int,
) -> Bool {
  program_size <= self.maximum_program_size
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
/// A relative compile-time and run-time cost used only after complete contextual
/// reduction. Semantic eligibility is decided before this model is consulted.
priv struct PartialEvaluationCost {
  nodes : Int
  call_overhead : Int
  branch_overhead : Int
  allocation_overhead : Int
}

///|
fn PartialEvaluationCost::plus(
  self : PartialEvaluationCost,
  other : PartialEvaluationCost,
) -> PartialEvaluationCost {
  {
    nodes: self.nodes + other.nodes,
    call_overhead: self.call_overhead + other.call_overhead,
    branch_overhead: self.branch_overhead + other.branch_overhead,
    allocation_overhead: self.allocation_overhead + other.allocation_overhead,
  }
}

///|
fn PartialEvaluationCost::score(self : PartialEvaluationCost) -> Int {
  self.nodes +
  self.call_overhead +
  self.branch_overhead +
  self.allocation_overhead
}

///|
fn partial_evaluation_is_profitable(
  original : @buslane.Expr,
  candidate : @buslane.Expr,
  callable : KnownCallable,
  analysis : InterproceduralAnalysis,
  preserved_roots : Array[@buslane.ValueId],
) -> Bool {
  let mut original_cost = partial_evaluation_cost(original, analysis)
  if callable.occurrence.use_count == 1 &&
    !preserved_roots.contains(callable.value) &&
    analysis.core.find_top_definition(callable.value) is Some(definition) {
    original_cost = original_cost.plus(
      partial_evaluation_cost(definition, analysis),
    )
  }
  partial_evaluation_cost(candidate, analysis).score() < original_cost.score()
}

///|
fn partial_evaluation_cost(
  expression : @buslane.Expr,
  analysis : InterproceduralAnalysis,
) -> PartialEvaluationCost {
  let own : PartialEvaluationCost = {
    nodes: 1,
    call_overhead: 0,
    branch_overhead: 0,
    allocation_overhead: 0,
  }
  match expression {
    Ref(_) | Literal(_) | Resume(_) => own
    Function(function) =>
      own.plus(partial_evaluation_cost(function.body, analysis))
    Call(callee, arguments) => {
      let mut cost = own.plus(partial_evaluation_cost(callee, analysis))
      for argument in arguments {
        cost = cost.plus(partial_evaluation_cost(argument, analysis))
      }
      let call_overhead = match known_call(callee) {
        Some(call) if analysis.find_callable(call.value) is Some(_) => 8
        _ => 16
      }
      { ..cost, call_overhead: cost.call_overhead + call_overhead }
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      own.plus(partial_evaluation_cost(body, analysis))
    Construct(construct) => {
      let mut cost = own
      for payload in construct.payloads {
        cost = cost.plus(partial_evaluation_cost(payload, analysis))
      }
      { ..cost, allocation_overhead: cost.allocation_overhead + 2 }
    }
    Let(_, initializer, body) =>
      own
      .plus(partial_evaluation_cost(initializer, analysis))
      .plus(partial_evaluation_cost(body, analysis))
    LetRec(bindings, body) => {
      let mut cost = own.plus(partial_evaluation_cost(body, analysis))
      for binding in bindings {
        cost = cost.plus(partial_evaluation_cost(binding.rhs, analysis))
      }
      cost
    }
    Match(match_) => {
      let mut cost = own.plus(
        partial_evaluation_cost(match_.scrutinee, analysis),
      )
      for alternative in match_.alternatives {
        cost = cost.plus(partial_evaluation_cost(alternative.body, analysis))
      }
      { ..cost, branch_overhead: cost.branch_overhead + 2 }
    }
    Perform(perform) => {
      let mut cost = own
      for payload in perform.payloads {
        cost = cost.plus(partial_evaluation_cost(payload, analysis))
      }
      { ..cost, call_overhead: cost.call_overhead + 16 }
    }
    Handle(handle) => {
      let mut cost = own
        .plus(partial_evaluation_cost(handle.body, analysis))
        .plus(partial_evaluation_cost(handle.final_body, analysis))
      for table in handle.handlers {
        for operation in table.operations {
          cost = cost.plus(partial_evaluation_cost(operation.body, analysis))
        }
      }
      { ..cost, branch_overhead: cost.branch_overhead + 2 }
    }
  }
}

///|
fn core_program_size(program : @buslane.Program) -> Int {
  let mut size = 0
  for term in program.terms {
    match term {
      Let(_, expression) => size = size + core_expression_size(expression)
      LetRec(bindings) =>
        for binding in bindings {
          size = size + core_expression_size(binding.rhs)
        }
      External(_) => ()
    }
  }
  size
}
