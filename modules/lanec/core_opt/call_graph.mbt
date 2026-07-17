///|
priv struct CoreDefinition {
  value : @buslane.ValueId
  expression : @buslane.Expr
  top_level : Bool
}

///|
priv struct CoreFunctionSummary {
  value : @buslane.ValueId
  callees : Array[@buslane.ValueId?]
  expression_size : Int
  occurrence : @occurrence.ValueOccurrenceFact
  is_recursive : Bool
}

///|
priv struct CoreAnalysis {
  definitions : Array[CoreDefinition]
  functions : Array[CoreFunctionSummary]
}

///|
fn analyze_core(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> CoreAnalysis {
  let definitions = collect_core_definitions(program)
  let callable_definitions = definitions.filter(definition => {
    callable_function(definition.expression) is Some(_)
  })
  let occurrence = @occurrence.analyze({ program, entry, roots })
  let functions = callable_definitions.map(definition => {
    guard callable_function(definition.expression) is Some(function) else {
      abort("callable definition lost its function body")
    }
    let callees = []
    summarize_calls(function.body, definitions, callees)
    let fact = occurrence.facts[definition.value.index]
    {
      value: definition.value,
      callees,
      expression_size: core_expression_size(function.body),
      occurrence: fact,
      is_recursive: false,
    }
  })
  for index, summary in functions {
    functions[index] = {
      ..summary,
      is_recursive: summary.callees.any(callee => {
        guard callee is Some(callee) else { return false }
        callee == summary.value ||
        call_graph_reaches(functions, callee, summary.value, [])
      }),
    }
  }
  { definitions, functions }
}

///|
fn collect_core_definitions(
  program : @buslane.Program,
) -> Array[CoreDefinition] {
  let definitions = []
  for term in program.terms {
    match term {
      Let(value, expression) => {
        push_core_definition(definitions, value, expression, top_level=true)
        collect_local_definitions(expression, definitions)
      }
      LetRec(bindings) => {
        for binding in bindings {
          push_core_definition(
            definitions,
            binding.id,
            binding.rhs,
            top_level=true,
          )
        }
        for binding in bindings {
          collect_local_definitions(binding.rhs, definitions)
        }
      }
      External(_) => ()
    }
  }
  definitions
}

///|
fn push_core_definition(
  definitions : Array[CoreDefinition],
  value : @buslane.ValueId,
  expression : @buslane.Expr,
  top_level~ : Bool,
) -> Unit {
  if !definitions.any(definition => definition.value == value) {
    definitions.push({ value, expression, top_level })
  }
}

///|
fn collect_local_definitions(
  expression : @buslane.Expr,
  definitions : Array[CoreDefinition],
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) => collect_local_definitions(function.body, definitions)
    Call(callee, arguments) => {
      collect_local_definitions(callee, definitions)
      for argument in arguments {
        collect_local_definitions(argument, definitions)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      collect_local_definitions(body, definitions)
    Construct(construct) =>
      for payload in construct.payloads {
        collect_local_definitions(payload, definitions)
      }
    Let(value, initializer, body) => {
      push_core_definition(definitions, value, initializer, top_level=false)
      collect_local_definitions(initializer, definitions)
      collect_local_definitions(body, definitions)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        push_core_definition(
          definitions,
          binding.id,
          binding.rhs,
          top_level=false,
        )
      }
      for binding in bindings {
        collect_local_definitions(binding.rhs, definitions)
      }
      collect_local_definitions(body, definitions)
    }
    Match(match_) => {
      collect_local_definitions(match_.scrutinee, definitions)
      for alternative in match_.alternatives {
        collect_local_definitions(alternative.body, definitions)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        collect_local_definitions(payload, definitions)
      }
    Handle(handle) => {
      collect_local_definitions(handle.body, definitions)
      collect_local_definitions(handle.final_body, definitions)
      for table in handle.handlers {
        for operation in table.operations {
          collect_local_definitions(operation.body, definitions)
        }
      }
    }
  }
}

///|
fn callable_function(expression : @buslane.Expr) -> @buslane.FunctionExpr? {
  match expression {
    Function(function) => Some(function)
    TypeLambda(_, body) => callable_function(body)
    _ => None
  }
}

///|
fn CoreAnalysis::find_top_definition(
  self : CoreAnalysis,
  value : @buslane.ValueId,
) -> @buslane.Expr? {
  for definition in self.definitions {
    if definition.value == value && definition.top_level {
      return Some(definition.expression)
    }
  }
  None
}

///|
fn CoreAnalysis::find_function(
  self : CoreAnalysis,
  value : @buslane.ValueId,
) -> CoreFunctionSummary? {
  for function in self.functions {
    if function.value == value {
      return Some(function)
    }
  }
  None
}

///|
fn summarize_calls(
  expression : @buslane.Expr,
  definitions : Array[CoreDefinition],
  callees : Array[@buslane.ValueId?],
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) | Function(_) => ()
    Call(callee, arguments) => {
      match resolve_callable_target(callee, definitions) {
        Some(value) =>
          if !callees.contains(Some(value)) {
            callees.push(Some(value))
          }
        _ => if !callees.contains(None) { callees.push(None) }
      }
      summarize_call_operand(callee, definitions, callees)
      for argument in arguments {
        summarize_calls(argument, definitions, callees)
      }
    }
    TypeLambda(_, body) =>
      if callable_function(expression) is None {
        summarize_calls(body, definitions, callees)
      }
    TypeApply(callee, _) => summarize_calls(callee, definitions, callees)
    Construct(construct) =>
      for payload in construct.payloads {
        summarize_calls(payload, definitions, callees)
      }
    Let(_, initializer, body) => {
      summarize_calls(initializer, definitions, callees)
      summarize_calls(body, definitions, callees)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        summarize_calls(binding.rhs, definitions, callees)
      }
      summarize_calls(body, definitions, callees)
    }
    Match(match_) => {
      summarize_calls(match_.scrutinee, definitions, callees)
      for alternative in match_.alternatives {
        summarize_calls(alternative.body, definitions, callees)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        summarize_calls(payload, definitions, callees)
      }
    Handle(handle) => {
      summarize_calls(handle.body, definitions, callees)
      summarize_calls(handle.final_body, definitions, callees)
      for table in handle.handlers {
        for operation in table.operations {
          summarize_calls(operation.body, definitions, callees)
        }
      }
    }
  }
}

///|
fn summarize_call_operand(
  callee : @buslane.Expr,
  definitions : Array[CoreDefinition],
  callees : Array[@buslane.ValueId?],
) -> Unit {
  match callee {
    Ref(_) => ()
    TypeApply(Ref(_), _) => ()
    _ => summarize_calls(callee, definitions, callees)
  }
}

///|
fn referenced_callee(expression : @buslane.Expr) -> @buslane.ValueId? {
  match expression {
    Ref(value) => Some(value)
    TypeApply(callee, _) => referenced_callee(callee)
    _ => None
  }
}

///|
fn resolve_callable_target(
  expression : @buslane.Expr,
  definitions : Array[CoreDefinition],
) -> @buslane.ValueId? {
  guard referenced_callee(expression) is Some(value) else { return None }
  resolve_callable_alias(value, definitions, [])
}

///|
fn resolve_callable_alias(
  value : @buslane.ValueId,
  definitions : Array[CoreDefinition],
  visited : Array[@buslane.ValueId],
) -> @buslane.ValueId? {
  if visited.contains(value) {
    return None
  }
  let mut found : CoreDefinition? = None
  for definition in definitions {
    if definition.value == value {
      found = Some(definition)
      break
    }
  }
  guard found is Some(definition) else { return None }
  if callable_function(definition.expression) is Some(_) {
    return Some(value)
  }
  guard referenced_callee(definition.expression) is Some(target) else {
    return None
  }
  let visited = visited.copy()
  visited.push(value)
  resolve_callable_alias(target, definitions, visited)
}

///|
fn call_graph_reaches(
  functions : Array[CoreFunctionSummary],
  source : @buslane.ValueId,
  target : @buslane.ValueId,
  visited : Array[@buslane.ValueId],
) -> Bool {
  if source == target {
    return true
  }
  if visited.contains(source) {
    return false
  }
  let visited = visited.copy()
  visited.push(source)
  let mut found : CoreFunctionSummary? = None
  for function in functions {
    if function.value == source {
      found = Some(function)
      break
    }
  }
  guard found is Some(function) else { return false }
  function.callees.any(callee => {
    guard callee is Some(callee) else { return false }
    call_graph_reaches(functions, callee, target, visited)
  })
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
    LetRec(bindings, body) => {
      let mut size = 1 + core_expression_size(body)
      for binding in bindings {
        size = size + core_expression_size(binding.rhs)
      }
      size
    }
    Match(match_) => {
      let mut size = 1 + core_expression_size(match_.scrutinee)
      for alternative in match_.alternatives {
        size = size + core_expression_size(alternative.body)
      }
      size
    }
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
          size = size + core_expression_size(operation.body)
        }
      }
      size
    }
  }
}
