///|
priv struct KnownCall {
  value : @buslane.ValueId
  generic_arguments : Array[@buslane.GenericArgument]
}

///|
priv struct PartialEvaluator {
  program : @buslane.Program
  analysis : InterproceduralAnalysis
  preserved_roots : Array[@buslane.ValueId]
  budget : PartialEvaluationBudget
  observations : Array[CoreOptimizationObservation]
}

///|
fn partially_evaluate_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Program raise CoreOptimizeError {
  let initial_size = core_program_size(program)
  let budget = PartialEvaluationBudget::new(initial_size)
  let mut current = program
  let preserved_roots = roots.copy()
  preserved_roots.push(entry)
  let pending : Array[@buslane.ValueId] = []
  let queued = Array::make(program.metadata.values.length(), false)
  let mut analysis = analyze_interprocedural(current, entry, roots)
  enqueue_definition_order(analysis.core, pending, queued)
  while pending.pop() is Some(value) {
    queued[value.index] = false
    guard analysis.core.find_top_definition(value) is Some(expression) else {
      continue
    }
    if !budget.consume(core_expression_size(expression)) {
      break
    }
    let observations : Array[CoreOptimizationObservation] = []
    let evaluator : PartialEvaluator = {
      program: current,
      analysis,
      preserved_roots,
      budget,
      observations,
    }
    let rewritten = evaluator.rewrite_expr(expression)
    if rewritten == expression {
      for observation in observations {
        observe(observation)
      }
      continue
    }
    let candidate = replace_top_definition(current, value, rewritten)
    let candidate = prune_unreachable(candidate, entry, roots)
    if !budget.accepts_program_size(core_program_size(candidate)) {
      for observation in observations {
        match observation {
          ApplicationAccepted(site~, ..) =>
            observe(ApplicationRejected(site, ResourceBudget))
          _ => observe(observation)
        }
      }
      continue
    }
    for observation in observations {
      observe(observation)
    }
    current = candidate
    analysis = analyze_interprocedural(current, entry, roots)
    enqueue_changed_definition(analysis.core, value, pending, queued)
  }
  current
}

///|
fn PartialEvaluator::rewrite_expr(
  self : PartialEvaluator,
  expression : @buslane.Expr,
) -> @buslane.Expr raise CoreOptimizeError {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => expression
    Function(function) =>
      Function({ ..function, body: self.rewrite_expr(function.body) })
    Call(callee, arguments) => self.rewrite_call(callee, arguments)
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, self.rewrite_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(self.rewrite_expr(callee), arguments)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => self.rewrite_expr(payload)),
      })
    Let(value, initializer, body) =>
      Let(value, self.rewrite_expr(initializer), self.rewrite_expr(body))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: self.rewrite_expr(binding.rhs),
        }),
        self.rewrite_expr(body),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: self.rewrite_expr(match_.scrutinee),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: self.rewrite_expr(alternative.body),
        }),
      })
    Perform(perform) =>
      Perform({
        ..perform,
        payloads: perform.payloads.map(payload => self.rewrite_expr(payload)),
      })
    Handle(handle) =>
      Handle({
        ..handle,
        body: self.rewrite_expr(handle.body),
        final_body: self.rewrite_expr(handle.final_body),
        handlers: handle.handlers.map(table => {
          ..table,
          operations: table.operations.map(operation => {
            ..operation,
            body: self.rewrite_expr(operation.body),
          }),
        }),
      })
  }
}

///|
fn PartialEvaluator::rewrite_call(
  self : PartialEvaluator,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
) -> @buslane.Expr raise CoreOptimizeError {
  let callee = self.rewrite_expr(callee)
  let arguments = arguments.map(argument => self.rewrite_expr(argument))
  match self.try_inline_known_call(callee, arguments) {
    Some(inlined) => inlined
    None => Call(callee, arguments)
  }
}

///|
fn PartialEvaluator::try_inline_known_call(
  self : PartialEvaluator,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
) -> @buslane.Expr? raise CoreOptimizeError {
  guard known_call(callee) is Some(call) &&
    self.analysis.find_callable(call.value) is Some(callable) else {
    return None
  }
  if callable.type_parameters.length() != call.generic_arguments.length() {
    return None
  }
  let site = ApplicationReductionSite::KnownCallable(call.value)
  self.observations.push(ApplicationConsidered(site))
  if callable.recursive {
    self.observations.push(ApplicationRejected(site, Recursive))
    return None
  }
  if !self.budget.consume(callable.expression_size) {
    self.observations.push(ApplicationRejected(site, ResourceBudget))
    return None
  }
  let nested_observation_start = self.observations.length()
  guard InlineCloneContext::from_application(
      self.program.metadata,
      callable.type_parameters,
      call.generic_arguments,
    )
    is Some(clone_context) else {
    return None
  }
  let cloned = clone_context.clone_function(callable.function)
  let facts = @buslane.ExpressionFactsQuery::new(self.program)
  let reduced = reduce_application(
    self.program,
    facts,
    self.analysis.core,
    [],
    cloned.parameters,
    arguments,
    cloned.body,
    observation => self.observations.push(observation),
  )
  let candidate = self.rewrite_expr(reduced.expression)
  let original = @buslane.Expr::Call(callee, arguments)
  if !partial_evaluation_is_profitable(
      original,
      candidate,
      callable,
      self.analysis,
      self.preserved_roots,
    ) {
    while self.observations.length() > nested_observation_start {
      ignore(self.observations.pop())
    }
    self.observations.push(ApplicationRejected(site, Profitability))
    return None
  }
  self.observations.push(
    ApplicationAccepted(
      site~,
      empty_arguments=reduced.empty_argument_count,
      materialized_arguments=reduced.materialized_argument_count,
    ),
  )
  Some(candidate)
}

///|
fn known_call(expression : @buslane.Expr) -> KnownCall? {
  match expression {
    Ref(value) => Some({ value, generic_arguments: [] })
    TypeApply(callee, arguments) => {
      guard known_call(callee) is Some(call) else { return None }
      Some({
        value: call.value,
        generic_arguments: call.generic_arguments + arguments,
      })
    }
    _ => None
  }
}

///|
