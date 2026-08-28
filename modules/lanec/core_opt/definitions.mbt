///|
priv struct CoreDefinition {
  value : @buslane.ValueId
  expression : @buslane.Expr
}

///|
priv enum StaticValueSummary {
  StaticLiteral(@buslane.Literal)
  StaticConstructor(@buslane.ConstructExpr)
}

///|
priv enum StaticValueState {
  Unvisited
  Visiting
  Known(StaticValueSummary)
  Unknown
}

///|
priv struct StaticLocalBinding {
  local_value : @buslane.ValueId
  local_replacement : @buslane.Expr
}

///|
priv struct CoreAnalysis {
  definitions : Array[CoreDefinition]
  static_values : Array[StaticValueState]
}

///|
fn analyze_core(
  program : @buslane.Program,
) -> CoreAnalysis raise CoreOptimizeError {
  let definitions = []
  for term in program.terms {
    match term {
      Let(value, expression) => definitions.push({ value, expression, })
      LetRec(bindings) =>
        for binding in bindings {
          definitions.push({ value: binding.id, expression: binding.rhs, })
        }
      External(_) => ()
    }
  }
  let static_values = Array::makei(definitions.length(), _ => Unvisited)
  let facts = @buslane.ExpressionFactsQuery::new(program)
  for index = 0; index < definitions.length(); index = index + 1 {
    resolve_static_definition(definitions, static_values, facts, index)
    |> ignore
  }
  { definitions, static_values, }
}

///|
fn CoreAnalysis::find_top_definition(
  self : CoreAnalysis,
  value : @buslane.ValueId,
) -> @buslane.Expr? {
  for definition in self.definitions {
    if definition.value == value {
      return Some(definition.expression)
    }
  }
  None
}

///|
fn CoreAnalysis::find_static_value(
  self : CoreAnalysis,
  value : @buslane.ValueId,
) -> StaticValueSummary? {
  guard definition_index(self.definitions, value) is Some(index) else {
    return None
  }
  match self.static_values[index] {
    Known(summary) => Some(summary)
    Unvisited | Visiting | Unknown => None
  }
}

///|
fn definition_index(
  definitions : Array[CoreDefinition],
  value : @buslane.ValueId,
) -> Int? {
  for index, definition in definitions {
    if definition.value == value {
      return Some(index)
    }
  }
  None
}

///|
fn resolve_static_definition(
  definitions : Array[CoreDefinition],
  states : Array[StaticValueState],
  facts : @buslane.ExpressionFactsQuery,
  index : Int,
) -> StaticValueSummary? raise CoreOptimizeError {
  match states[index] {
    Known(summary) => return Some(summary)
    Visiting | Unknown => return None
    Unvisited => ()
  }
  states[index] = Visiting
  let summary = summarize_static_expression(
    definitions,
    states,
    facts,
    [],
    definitions[index].expression,
  )
  states[index] = match summary {
    Some(summary) => Known(summary)
    None => Unknown
  }
  summary
}

///|
fn summarize_static_expression(
  definitions : Array[CoreDefinition],
  states : Array[StaticValueState],
  facts : @buslane.ExpressionFactsQuery,
  locals : Array[StaticLocalBinding],
  expression : @buslane.Expr,
) -> StaticValueSummary? raise CoreOptimizeError {
  match expression {
    Literal(literal) => Some(StaticLiteral(literal))
    Construct(construct) => {
      let payloads = []
      for payload in construct.payloads {
        guard expression_has_empty_effect(facts, payload) else { return None }
        guard close_static_payload(payload, locals) is Some(payload) else {
          return None
        }
        payloads.push(payload)
      }
      Some(StaticConstructor({ ..construct, payloads, }))
    }
    Ref(value) => {
      for binding in locals.rev_iter() {
        if binding.local_value == value {
          return static_summary_from_closed_expression(
            binding.local_replacement,
          )
        }
      }
      guard definition_index(definitions, value) is Some(index) else {
        return None
      }
      resolve_static_definition(definitions, states, facts, index)
    }
    Let(value, initializer, body) => {
      guard expression_has_empty_effect(facts, initializer) else { return None }
      guard summarize_static_expression(
          definitions, states, facts, locals, initializer,
        )
        is Some(initializer) else {
        return None
      }
      let nested = locals.copy()
      nested.push({
        local_value: value,
        local_replacement: initializer.to_expression(),
      })
      summarize_static_expression(definitions, states, facts, nested, body)
    }
    Function(_)
    | Call(_, _)
    | TypeLambda(_, _)
    | TypeApply(_, _)
    | LetRec(_, _)
    | Match(_)
    | Perform(_)
    | Handle(_)
    | Resume(_) => None
  }
}

///|
fn close_static_payload(
  expression : @buslane.Expr,
  locals : Array[StaticLocalBinding],
) -> @buslane.Expr? {
  let mut closed = expression
  for binding in locals.rev_iter() {
    if count_value_uses(closed, binding.local_value) == 0 {
      continue
    }
    guard closed is Ref(value) && value == binding.local_value else {
      return None
    }
    closed = binding.local_replacement
  }
  Some(closed)
}

///|
fn static_summary_from_closed_expression(
  expression : @buslane.Expr,
) -> StaticValueSummary? {
  match expression {
    Literal(literal) => Some(StaticLiteral(literal))
    Construct(construct) => Some(StaticConstructor(construct))
    _ => None
  }
}

///|
fn StaticValueSummary::to_expression(
  self : StaticValueSummary,
) -> @buslane.Expr {
  match self {
    StaticLiteral(literal) => Literal(literal)
    StaticConstructor(construct) => Construct(construct)
  }
}
