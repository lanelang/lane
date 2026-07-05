///|
fn SemanticChecker::report_ambiguous_variant_reference(
  self : SemanticChecker,
  name : String,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({
    kind: VariantReferenceFailure(label="ambiguous variant reference " + name),
    loc,
  })
}
