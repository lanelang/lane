///|
fn SemanticChecker::fork_for_probe(self : SemanticChecker) -> SemanticChecker {
  {
    resolved_source: self.resolved_source,
    source: self.source,
    imported_environment: self.imported_environment,
    declarations: self.declarations,
    diagnostics: [],
    values: self.values.copy(),
    value_types: self.value_types.copy(),
    ordered_value_types: self.ordered_value_types.copy(),
    offers: self.offers.copy(),
    ordered_offers: self.ordered_offers.copy(),
  }
}

///|
fn SemanticChecker::probe_expr_type(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
) -> @types.Type? {
  let probe = self.fork_for_probe()
  let checked = probe.synthesize_checked_expr(scope.copy(), expression)
  if probe.diagnostics.is_empty() {
    Some(checked.type_)
  } else {
    None
  }
}

///|
fn SemanticChecker::probe_checked_expr_effect(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
  expected : @types.Type,
) -> @types.Effect {
  let probe = self.fork_for_probe()
  probe.check_checked_expr(scope.copy(), expression, expected).effect
}
