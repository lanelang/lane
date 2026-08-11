///|
/// Seeds a deterministic dependency-first worklist.
fn enqueue_definition_order(
  core : CoreAnalysis,
  pending : Array[@buslane.ValueId],
  queued : Array[Bool],
) -> Unit {
  let states = Array::make(queued.length(), 0)
  let order = []
  for definition in core.definitions {
    visit_definition_dependencies(definition.value, core, states, order)
  }
  for value in order.rev_iter() {
    enqueue_definition(value, pending, queued)
  }
}

///|
fn visit_definition_dependencies(
  value : @buslane.ValueId,
  core : CoreAnalysis,
  states : Array[Int],
  order : Array[@buslane.ValueId],
) -> Unit {
  if states[value.index] != 0 {
    return
  }
  states[value.index] = 1
  guard core.find_top_definition(value) is Some(expression) else { return }
  let dependencies = []
  collect_top_dependencies(expression, core, dependencies)
  for dependency in dependencies {
    if states[dependency.index] == 0 {
      visit_definition_dependencies(dependency, core, states, order)
    }
  }
  states[value.index] = 2
  order.push(value)
}

///|
/// Reconsiders the changed definition and every direct dependent. Transitive
/// dependents enter the worklist when their immediate dependency changes.
fn enqueue_changed_definition(
  core : CoreAnalysis,
  value : @buslane.ValueId,
  pending : Array[@buslane.ValueId],
  queued : Array[Bool],
) -> Unit {
  for definition in core.definitions.rev_iter() {
    if definition.value != value &&
      expression_references_top_value(definition.expression, value, core) {
      enqueue_definition(definition.value, pending, queued)
    }
  }
  if core.find_top_definition(value) is Some(_) {
    enqueue_definition(value, pending, queued)
  }
}

///|
fn enqueue_definition(
  value : @buslane.ValueId,
  pending : Array[@buslane.ValueId],
  queued : Array[Bool],
) -> Unit {
  if !queued[value.index] {
    queued[value.index] = true
    pending.push(value)
  }
}

///|
fn expression_references_top_value(
  expression : @buslane.Expr,
  value : @buslane.ValueId,
  core : CoreAnalysis,
) -> Bool {
  let dependencies = []
  collect_top_dependencies(expression, core, dependencies)
  dependencies.contains(value)
}

///|
fn collect_top_dependencies(
  expression : @buslane.Expr,
  core : CoreAnalysis,
  dependencies : Array[@buslane.ValueId],
) -> Unit {
  match expression {
    Ref(value) | Resume(value) =>
      if core.find_top_definition(value) is Some(_) &&
        !dependencies.contains(value) {
        dependencies.push(value)
      }
    Literal(_) => ()
    Function(function) =>
      collect_top_dependencies(function.body, core, dependencies)
    Call(callee, arguments) => {
      collect_top_dependencies(callee, core, dependencies)
      for argument in arguments {
        collect_top_dependencies(argument, core, dependencies)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      collect_top_dependencies(body, core, dependencies)
    Construct(construct) =>
      for payload in construct.payloads {
        collect_top_dependencies(payload, core, dependencies)
      }
    Let(_, initializer, body) => {
      collect_top_dependencies(initializer, core, dependencies)
      collect_top_dependencies(body, core, dependencies)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_top_dependencies(binding.rhs, core, dependencies)
      }
      collect_top_dependencies(body, core, dependencies)
    }
    Match(match_) => {
      collect_top_dependencies(match_.scrutinee, core, dependencies)
      for alternative in match_.alternatives {
        collect_top_dependencies(alternative.body, core, dependencies)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        collect_top_dependencies(payload, core, dependencies)
      }
    Handle(handle) => {
      collect_top_dependencies(handle.body, core, dependencies)
      collect_top_dependencies(handle.final_body, core, dependencies)
      for table in handle.handlers {
        for operation in table.operations {
          collect_top_dependencies(operation.body, core, dependencies)
        }
      }
    }
  }
}

///|
fn replace_top_definition(
  program : @buslane.Program,
  value : @buslane.ValueId,
  replacement : @buslane.Expr,
) -> @buslane.Program {
  let terms = program.terms.map(term => {
    match term {
      Let(id, _) if id == value => @buslane.TopTerm::Let(id, replacement)
      LetRec(bindings) =>
        @buslane.TopTerm::LetRec(
          bindings.map(binding => {
            if binding.id == value {
              { ..binding, rhs: replacement }
            } else {
              binding
            }
          }),
        )
      _ => term
    }
  })
  { ..program, terms, }
}
