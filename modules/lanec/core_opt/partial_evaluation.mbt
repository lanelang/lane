///|
priv struct KnownCall {
  value : @buslane.ValueId
  generic_arguments : Array[@buslane.GenericArgument]
}

///|
priv struct PartialEvaluator {
  program : @buslane.Program
  facts : @buslane.ExpressionFactsQuery
  analysis : InterproceduralAnalysis
  preserved_roots : Array[@buslane.ValueId]
  budget : PartialEvaluationBudget
}

///|
fn partially_evaluate_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> @buslane.Program raise CoreOptimizeError {
  let initial_size = core_program_size(program)
  let budget = PartialEvaluationBudget::new(initial_size)
  let mut current = program
  let preserved_roots = roots.copy()
  preserved_roots.push(entry)
  let pending : Array[@buslane.ValueId] = []
  let queued = Array::make(program.metadata.values.length(), false)
  let mut analysis = analyze_interprocedural(current, entry, roots)
  let mut facts = @buslane.ExpressionFactsQuery::new(current)
  enqueue_definition_order(analysis.core, pending, queued)
  while pending.pop() is Some(value) {
    queued[value.index] = false
    guard analysis.core.find_top_definition(value) is Some(expression) else {
      continue
    }
    if !budget.consume(core_expression_size(expression)) {
      break
    }
    let evaluator : PartialEvaluator = {
      program: current,
      facts,
      analysis,
      preserved_roots,
      budget,
    }
    let rewritten = evaluator.rewrite_expr(expression)
    if rewritten == expression {
      continue
    }
    let candidate = replace_top_definition(current, value, rewritten)
    let candidate = prune_unreachable(candidate, entry, roots)
    if !budget.accepts_program_size(core_program_size(candidate)) {
      continue
    }
    current = candidate
    analysis = analyze_interprocedural(current, entry, roots)
    facts = @buslane.ExpressionFactsQuery::new(current)
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
    self.analysis.find_callable(call.value) is Some(callable) &&
    !callable.recursive &&
    callable_effect_is_empty(self.program, callable.value) &&
    callable_body_can_be_cloned(callable.function.body) &&
    arguments.all(is_substitutable_atom) &&
    callable.function.parameters.length() == arguments.length() &&
    callable.type_parameters.length() == call.generic_arguments.length() else {
    return None
  }
  if !self.budget.consume(callable.expression_size) {
    return None
  }
  guard InlineCloneContext::from_application(
      self.program.metadata,
      callable.type_parameters,
      call.generic_arguments,
    )
    is Some(clone_context) else {
    return None
  }
  let cloned = clone_context.clone_function(callable.function)
  let substitutions = []
  for index in 0..<arguments.length() {
    substitutions.push({
      value: cloned.parameters[index],
      replacement: arguments[index],
    })
  }
  let reduced = simplify_expr(
    self.program,
    self.facts,
    self.analysis.core,
    substitutions,
    cloned.body,
  )
  let candidate = self.rewrite_expr(reduced)
  let original = @buslane.Expr::Call(callee, arguments)
  if !partial_evaluation_is_profitable(
      original,
      candidate,
      callable,
      self.analysis,
      self.preserved_roots,
    ) {
    return None
  }
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
fn callable_effect_is_empty(
  program : @buslane.Program,
  value : @buslane.ValueId,
) -> Bool {
  guard program.metadata.value_info(value) is Some(info) else { return false }
  match strip_type_quantifiers(info.type_) {
    Function(_, _, Empty) => true
    _ => false
  }
}

///|
fn strip_type_quantifiers(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Forall(_, body) | TypeLambda(_, body) => strip_type_quantifiers(body)
    _ => type_
  }
}

///|
fn callable_body_can_be_cloned(expression : @buslane.Expr) -> Bool {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => true
    Function(function) => callable_body_can_be_cloned(function.body)
    Call(callee, arguments) =>
      callable_body_can_be_cloned(callee) &&
      arguments.all(callable_body_can_be_cloned)
    TypeLambda(_, _) => false
    TypeApply(body, _) => callable_body_can_be_cloned(body)
    Construct(construct) => construct.payloads.all(callable_body_can_be_cloned)
    Let(_, initializer, body) =>
      callable_body_can_be_cloned(initializer) &&
      callable_body_can_be_cloned(body)
    LetRec(bindings, body) =>
      bindings.all(binding => callable_body_can_be_cloned(binding.rhs)) &&
      callable_body_can_be_cloned(body)
    Match(match_) =>
      match_.alternatives.all(alternative => {
        alternative.type_binders.is_empty() &&
        callable_body_can_be_cloned(alternative.body)
      }) &&
      callable_body_can_be_cloned(match_.scrutinee)
    Perform(perform) => perform.payloads.all(callable_body_can_be_cloned)
    Handle(handle) =>
      callable_body_can_be_cloned(handle.body) &&
      callable_body_can_be_cloned(handle.final_body) &&
      handle.handlers.all(table => {
        table.operations.all(operation => {
          callable_body_can_be_cloned(operation.body)
        })
      })
  }
}
