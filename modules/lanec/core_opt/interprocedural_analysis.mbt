///|
priv struct KnownCallable {
  value : @buslane.ValueId
  type_parameters : Array[@buslane.TypeParameterId]
  function : @buslane.FunctionExpr
  callees : Array[@buslane.ValueId]
  expression_size : Int
  occurrence : @occurrence.ValueOccurrenceFact
  recursive : Bool
}

///|
priv struct InterproceduralAnalysis {
  core : CoreAnalysis
  callables : Array[KnownCallable]
}

///|
priv struct CallAlias {
  value : @buslane.ValueId
  target : @buslane.ValueId
}

///|
fn analyze_interprocedural(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> InterproceduralAnalysis {
  let core = analyze_core(program)
  let occurrence = @occurrence.analyze({ program, entry, roots })
  let callables = []
  for definition in core.definitions {
    guard callable_parts(definition.expression)
      is Some((type_parameters, function)) else {
      continue
    }
    let callees = []
    collect_known_callees(function.body, core, [], callees)
    let occurrence = match occurrence.facts.get(definition.value.index) {
      Some(fact) => fact
      None => empty_occurrence(definition.value)
    }
    callables.push({
      value: definition.value,
      type_parameters,
      function,
      callees,
      expression_size: core_expression_size(function.body),
      occurrence,
      recursive: false,
    })
  }
  for index, callable in callables {
    callables[index] = {
      ..callable,
      recursive: callable.callees.any(callee => {
        callee == callable.value ||
        call_graph_reaches(callables, callee, callable.value, [])
      }),
    }
  }
  { core, callables }
}

///|
fn empty_occurrence(
  value : @buslane.ValueId,
) -> @occurrence.ValueOccurrenceFact {
  {
    value,
    use_count: 0,
    call_count: 0,
    callee_only: false,
    escapes: false,
    used_in_effectful_context: false,
    reachable_from_entry: false,
  }
}

///|
fn callable_parts(
  expression : @buslane.Expr,
) -> (Array[@buslane.TypeParameterId], @buslane.FunctionExpr)? {
  let type_parameters = []
  let mut current = expression
  while current is TypeLambda(parameters, body) {
    type_parameters.append(parameters)
    current = body
  }
  match current {
    Function(function) => Some((type_parameters, function))
    _ => None
  }
}

///|
fn InterproceduralAnalysis::find_callable(
  self : InterproceduralAnalysis,
  value : @buslane.ValueId,
) -> KnownCallable? {
  for callable in self.callables {
    if callable.value == value {
      return Some(callable)
    }
  }
  None
}

///|
fn collect_known_callees(
  expression : @buslane.Expr,
  core : CoreAnalysis,
  aliases : Array[CallAlias],
  callees : Array[@buslane.ValueId],
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) =>
      collect_known_callees(function.body, core, aliases, callees)
    Call(callee, arguments) => {
      if resolve_known_callee(callee, core, aliases) is Some(target) &&
        !callees.contains(target) {
        callees.push(target)
      }
      collect_known_callees(callee, core, aliases, callees)
      for argument in arguments {
        collect_known_callees(argument, core, aliases, callees)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      collect_known_callees(body, core, aliases, callees)
    Construct(construct) =>
      for payload in construct.payloads {
        collect_known_callees(payload, core, aliases, callees)
      }
    Let(value, initializer, body) => {
      collect_known_callees(initializer, core, aliases, callees)
      let body_aliases = aliases.copy()
      if referenced_value(initializer) is Some(target) {
        body_aliases.push({ value, target })
      }
      collect_known_callees(body, core, body_aliases, callees)
    }
    LetRec(bindings, body) => {
      let body_aliases = aliases.copy()
      for binding in bindings {
        if referenced_value(binding.rhs) is Some(target) {
          body_aliases.push({ value: binding.id, target })
        }
      }
      for binding in bindings {
        collect_known_callees(binding.rhs, core, body_aliases, callees)
      }
      collect_known_callees(body, core, body_aliases, callees)
    }
    Match(match_) => {
      collect_known_callees(match_.scrutinee, core, aliases, callees)
      for alternative in match_.alternatives {
        collect_known_callees(alternative.body, core, aliases, callees)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        collect_known_callees(payload, core, aliases, callees)
      }
    Handle(handle) => {
      collect_known_callees(handle.body, core, aliases, callees)
      collect_known_callees(handle.final_body, core, aliases, callees)
      for table in handle.handlers {
        for operation in table.operations {
          collect_known_callees(operation.body, core, aliases, callees)
        }
      }
    }
  }
}

///|
fn resolve_known_callee(
  expression : @buslane.Expr,
  core : CoreAnalysis,
  aliases : Array[CallAlias],
) -> @buslane.ValueId? {
  guard referenced_value(expression) is Some(value) else { return None }
  resolve_known_value(value, core, aliases, [])
}

///|
fn resolve_known_value(
  value : @buslane.ValueId,
  core : CoreAnalysis,
  aliases : Array[CallAlias],
  visited : Array[@buslane.ValueId],
) -> @buslane.ValueId? {
  if visited.contains(value) {
    return None
  }
  let next_visited = visited.copy()
  next_visited.push(value)
  for binding in aliases.rev_iter() {
    if binding.value == value {
      return resolve_known_value(binding.target, core, aliases, next_visited)
    }
  }
  guard core.find_top_definition(value) is Some(definition) else { return None }
  if callable_parts(definition) is Some(_) {
    return Some(value)
  }
  guard referenced_value(definition) is Some(target) else { return None }
  resolve_known_value(target, core, aliases, next_visited)
}

///|
fn referenced_value(expression : @buslane.Expr) -> @buslane.ValueId? {
  match expression {
    Ref(value) => Some(value)
    TypeApply(callee, _) => referenced_value(callee)
    _ => None
  }
}

///|
fn call_graph_reaches(
  callables : Array[KnownCallable],
  from : @buslane.ValueId,
  target : @buslane.ValueId,
  visited : Array[@buslane.ValueId],
) -> Bool {
  if from == target {
    return true
  }
  if visited.contains(from) {
    return false
  }
  let next_visited = visited.copy()
  next_visited.push(from)
  guard find_known_callable(callables, from) is Some(callable) else {
    return false
  }
  callable.callees.any(callee => {
    call_graph_reaches(callables, callee, target, next_visited)
  })
}

///|
fn find_known_callable(
  callables : Array[KnownCallable],
  value : @buslane.ValueId,
) -> KnownCallable? {
  for callable in callables {
    if callable.value == value {
      return Some(callable)
    }
  }
  None
}

///|
fn core_expression_size(expression : @buslane.Expr) -> Int {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => 1
    Function(function) => 1 + core_expression_size(function.body)
    Call(callee, arguments) =>
      1 +
      core_expression_size(callee) +
      arguments.fold(init=0, fn(size, argument) {
        size + core_expression_size(argument)
      })
    TypeLambda(_, body) | TypeApply(body, _) => 1 + core_expression_size(body)
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(size, payload) {
        size + core_expression_size(payload)
      })
    Let(_, initializer, body) =>
      1 + core_expression_size(initializer) + core_expression_size(body)
    LetRec(bindings, body) =>
      1 +
      bindings.fold(init=0, fn(size, binding) {
        size + core_expression_size(binding.rhs)
      }) +
      core_expression_size(body)
    Match(match_) =>
      1 +
      core_expression_size(match_.scrutinee) +
      match_.alternatives.fold(init=0, fn(size, alternative) {
        size + core_expression_size(alternative.body)
      })
    Perform(perform) =>
      1 +
      perform.payloads.fold(init=0, fn(size, payload) {
        size + core_expression_size(payload)
      })
    Handle(handle) => {
      let mut size = 1 +
        core_expression_size(handle.body) +
        core_expression_size(handle.final_body)
      for table in handle.handlers {
        for operation in table.operations {
          size += core_expression_size(operation.body)
        }
      }
      size
    }
  }
}
