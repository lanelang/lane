///|
fn SemanticChecker::copy_for_silent_analysis(
  self : SemanticChecker,
) -> SemanticChecker {
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
