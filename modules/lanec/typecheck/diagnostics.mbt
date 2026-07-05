///|
fn SemanticChecker::report_ambiguous_variant_reference(
  self : SemanticChecker,
  name : String,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({
    kind: CannotInferExpression(
      label="ambiguous variant reference " + name,
      reason=Generic,
    ),
    loc,
  })
}
