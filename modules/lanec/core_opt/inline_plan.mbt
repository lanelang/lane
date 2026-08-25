///|
priv struct KnownCall {
  value : @buslane.ValueId
  generic_arguments : Array[@buslane.GenericArgument]
}

///|
priv struct CallSiteKey {
  caller : @buslane.ValueId
  ordinal : Int
}

///|
priv enum InlinePlanDecision {
  Accept
  Reject(ApplicationReductionRejection)
}

///|
priv struct PlannedInlineSite {
  callable : KnownCallable
  generic_arguments : Array[@buslane.GenericArgument]
  decision : InlinePlanDecision
}

///|
priv struct InlinePlan {
  analysis : InterproceduralAnalysis
  sites_by_caller : Array[Array[PlannedInlineSite?]]
}

///|
priv struct CallSiteCursor {
  mut next : Int
}

///|
fn CallSiteCursor::allocate(
  self : CallSiteCursor,
  caller : @buslane.ValueId,
) -> CallSiteKey {
  let key = { caller, ordinal: self.next, }
  self.next = self.next + 1
  key
}

///|
priv struct InlinePlanner {
  planning_program : @buslane.Program
  analysis : InterproceduralAnalysis
  preserved_roots : Array[@buslane.ValueId]
  sites_by_caller : Array[Array[PlannedInlineSite?]]
}

///|
fn build_inline_plan(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> InlinePlan raise CoreOptimizeError {
  let analysis = analyze_interprocedural(program, entry, roots)
  let preserved_roots = roots.copy()
  preserved_roots.push(entry)
  let planner : InlinePlanner = {
    planning_program: {
      metadata: program.metadata.snapshot(),
      terms: program.terms,
    },
    analysis,
    preserved_roots,
    sites_by_caller: Array::makei(program.metadata.values.length(), _ => []),
  }
  for definition in analysis.core.definitions {
    let cursor : CallSiteCursor = { next: 0, }
    planner.visit_expr(definition.value, cursor, definition.expression)
  }
  { analysis, sites_by_caller: planner.sites_by_caller, }
}

///|
fn InlinePlanner::visit_expr(
  self : InlinePlanner,
  caller : @buslane.ValueId,
  cursor : CallSiteCursor,
  expression : @buslane.Expr,
) -> Unit raise CoreOptimizeError {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) => self.visit_expr(caller, cursor, function.body)
    Call(callee, arguments) => {
      self.visit_expr(caller, cursor, callee)
      for argument in arguments {
        self.visit_expr(caller, cursor, argument)
      }
      let key = cursor.allocate(caller)
      self.plan_call(key, callee, arguments)
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      self.visit_expr(caller, cursor, body)
    Construct(construct) =>
      for payload in construct.payloads {
        self.visit_expr(caller, cursor, payload)
      }
    Let(_, initializer, body) => {
      self.visit_expr(caller, cursor, initializer)
      self.visit_expr(caller, cursor, body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.visit_expr(caller, cursor, binding.rhs)
      }
      self.visit_expr(caller, cursor, body)
    }
    Match(match_) => {
      self.visit_expr(caller, cursor, match_.scrutinee)
      for alternative in match_.alternatives {
        self.visit_expr(caller, cursor, alternative.body)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.visit_expr(caller, cursor, payload)
      }
    Handle(handle) => {
      self.visit_expr(caller, cursor, handle.body)
      self.visit_expr(caller, cursor, handle.final_body)
      for table in handle.handlers {
        for operation in table.operations {
          self.visit_expr(caller, cursor, operation.body)
        }
      }
    }
  }
}

///|
fn InlinePlanner::plan_call(
  self : InlinePlanner,
  key : CallSiteKey,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
) -> Unit raise CoreOptimizeError {
  let caller_sites = self.sites_by_caller[key.caller.index]
  while caller_sites.length() <= key.ordinal {
    caller_sites.push(None)
  }
  guard known_call(callee) is Some(call) &&
    self.analysis.find_callable(call.value) is Some(callable) &&
    callable.type_parameters.length() == call.generic_arguments.length() else {
    return
  }
  let decision = if self.analysis.sccs[callable.scc].recursive {
    InlinePlanDecision::Reject(Recursive)
  } else {
    self.plan_nonrecursive_call(callee, arguments, call, callable)
  }
  caller_sites[key.ordinal] = Some({
    callable,
    generic_arguments: call.generic_arguments,
    decision,
  })
}

///|
fn InlinePlanner::plan_nonrecursive_call(
  self : InlinePlanner,
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
  call : KnownCall,
  callable : KnownCallable,
) -> InlinePlanDecision raise CoreOptimizeError {
  guard InlineCloneContext::from_application(
      self.planning_program.metadata,
      callable.type_parameters,
      call.generic_arguments,
    )
    is Some(clone_context) else {
    return Reject(Profitability)
  }
  let cloned = clone_context.clone_function(callable.function)
  let facts = @buslane.ExpressionFactsQuery::new(self.planning_program)
  let reduced = reduce_application(
    self.planning_program,
    facts,
    self.analysis.core,
    [],
    cloned.parameters,
    arguments,
    cloned.body,
    _ => (),
  )
  let original = @buslane.Expr::Call(callee, arguments)
  if inline_is_profitable(
      original,
      reduced.expression,
      callable,
      self.analysis,
      self.preserved_roots,
    ) {
    Accept
  } else {
    Reject(Profitability)
  }
}

///|
fn InlinePlan::find_site(
  self : InlinePlan,
  key : CallSiteKey,
) -> PlannedInlineSite? {
  if key.caller.index >= self.sites_by_caller.length() {
    return None
  }
  let caller_sites = self.sites_by_caller[key.caller.index]
  if key.ordinal >= caller_sites.length() {
    return None
  }
  caller_sites[key.ordinal]
}

///|
fn known_call(expression : @buslane.Expr) -> KnownCall? {
  match expression {
    Ref(value) => Some({ value, generic_arguments: [], })
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
