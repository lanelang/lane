///|
fn deduplicate_typecheck_diagnostics(
  diagnostics : Array[TypeCheckDiagnostic],
) -> Array[TypeCheckDiagnostic] {
  let result : Array[TypeCheckDiagnostic] = []
  for diagnostic in diagnostics {
    if !result.contains(diagnostic) {
      result.push(diagnostic)
    }
  }
  result
}

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
