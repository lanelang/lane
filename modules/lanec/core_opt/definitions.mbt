///|
priv struct CoreDefinition {
  value : @buslane.ValueId
  expression : @buslane.Expr
}

///|
priv struct CoreAnalysis {
  definitions : Array[CoreDefinition]
}

///|
fn analyze_core(program : @buslane.Program) -> CoreAnalysis {
  let definitions = []
  for term in program.terms {
    match term {
      Let(value, expression) => definitions.push({ value, expression })
      LetRec(bindings) =>
        for binding in bindings {
          definitions.push({ value: binding.id, expression: binding.rhs })
        }
      External(_) => ()
    }
  }
  { definitions, }
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
