///|
priv struct InlineExecution {
  program : @buslane.Program
  changed : Bool
}

///|
priv struct InlineExecutor {
  program : @buslane.Program
  plan : InlinePlan
  observe : (CoreOptimizationObservation) -> Unit
  mut changed : Bool
}

///|
fn execute_inline_pipeline(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Program raise CoreOptimizeError {
  for current = program {
    let plan = build_inline_plan(current, entry, roots)
    let execution = execute_inline_plan(current, plan, observe)
    if !execution.changed {
      return execution.program
    }
    continue cleanup_core(execution.program, entry, roots, observe)
  }
}

///|
fn execute_inline_plan(
  program : @buslane.Program,
  plan : InlinePlan,
  observe : (CoreOptimizationObservation) -> Unit,
) -> InlineExecution raise CoreOptimizeError {
  let executor : InlineExecutor = { program, plan, observe, changed: false }
  let terms = program.terms.map(term => {
    match term {
      Let(value, expression) => {
        let cursor : CallSiteCursor = { next: 0 }
        @buslane.TopTerm::Let(
          value,
          executor.rewrite_expr(value, cursor, expression),
        )
      }
      LetRec(bindings) =>
        LetRec(
          bindings.map(binding => {
            let cursor : CallSiteCursor = { next: 0 }
            {
              ..binding,
              rhs: executor.rewrite_expr(binding.id, cursor, binding.rhs),
            }
          }),
        )
      External(_) => term
    }
  })
  { program: { ..program, terms, }, changed: executor.changed }
}

///|
fn InlineExecutor::rewrite_expr(
  self : InlineExecutor,
  caller : @buslane.ValueId,
  cursor : CallSiteCursor,
  expression : @buslane.Expr,
) -> @buslane.Expr raise CoreOptimizeError {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => expression
    Function(function) =>
      Function({
        ..function,
        body: self.rewrite_expr(caller, cursor, function.body),
      })
    Call(callee, arguments) => {
      let callee = self.rewrite_expr(caller, cursor, callee)
      let arguments = arguments.map(argument => {
        self.rewrite_expr(caller, cursor, argument)
      })
      let key = cursor.allocate(caller)
      self.rewrite_call(key, callee, arguments)
    }
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, self.rewrite_expr(caller, cursor, body))
    TypeApply(callee, arguments) =>
      TypeApply(self.rewrite_expr(caller, cursor, callee), arguments)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => {
          self.rewrite_expr(caller, cursor, payload)
        }),
      })
    Let(value, initializer, body) =>
      Let(
        value,
        self.rewrite_expr(caller, cursor, initializer),
        self.rewrite_expr(caller, cursor, body),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: self.rewrite_expr(caller, cursor, binding.rhs),
        }),
        self.rewrite_expr(caller, cursor, body),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: self.rewrite_expr(caller, cursor, match_.scrutinee),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: self.rewrite_expr(caller, cursor, alternative.body),
        }),
      })
    Perform(perform) =>
      Perform({
        ..perform,
        payloads: perform.payloads.map(payload => {
          self.rewrite_expr(caller, cursor, payload)
        }),
      })
    Handle(handle) =>
      Handle({
        ..handle,
        body: self.rewrite_expr(caller, cursor, handle.body),
        final_body: self.rewrite_expr(caller, cursor, handle.final_body),
        handlers: handle.handlers.map(table => {
          ..table,
          operations: table.operations.map(operation => {
            ..operation,
            body: self.rewrite_expr(caller, cursor, operation.body),
          }),
        }),
      })
  }
}

///|
fn InlineExecutor::rewrite_call(
  self : InlineExecutor,
  key : CallSiteKey,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
) -> @buslane.Expr raise CoreOptimizeError {
  guard self.plan.find_site(key) is Some(site) else {
    return Call(callee, arguments)
  }
  let observation_site = ApplicationReductionSite::KnownCallable(
    site.callable.value,
  )
  (self.observe)(ApplicationConsidered(observation_site))
  match site.decision {
    Reject(reason) => {
      (self.observe)(ApplicationRejected(observation_site, reason))
      Call(callee, arguments)
    }
    Accept => {
      guard InlineCloneContext::from_application(
          self.program.metadata,
          site.callable.type_parameters,
          site.generic_arguments,
        )
        is Some(clone_context) else {
        (self.observe)(ApplicationRejected(observation_site, Profitability))
        return Call(callee, arguments)
      }
      let cloned = clone_context.clone_function(site.callable.function)
      let facts = @buslane.ExpressionFactsQuery::new(self.program)
      let reduced = reduce_application(
        self.program,
        facts,
        self.plan.analysis.core,
        [],
        cloned.parameters,
        arguments,
        cloned.body,
        self.observe,
      )
      (self.observe)(
        ApplicationAccepted(
          site=observation_site,
          empty_arguments=reduced.empty_argument_count,
          materialized_arguments=reduced.materialized_argument_count,
        ),
      )
      self.changed = true
      reduced.expression
    }
  }
}
