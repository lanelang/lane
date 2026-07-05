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
  let type_ = probe.synthesize_expr(scope.copy(), expression)
  if probe.diagnostics.is_empty() {
    Some(type_)
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
  let probe_scope = scope.copy()
  probe.check_expr(probe_scope, expression, expected)
  probe.synthesize_expr_effect(probe_scope, expression)
}
