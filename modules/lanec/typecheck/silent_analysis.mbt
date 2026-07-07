///|
fn SemanticChecker::copy_for_silent_analysis(
  self : SemanticChecker,
) -> SemanticChecker {
  // Silent analysis reuses the normal typing rules for bounded local
  // measurements, such as handler residual effects. Diagnostics and mutations
  // stay in the copied checker.
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
    expected_effects: self.expected_effects.copy(),
  }
}
