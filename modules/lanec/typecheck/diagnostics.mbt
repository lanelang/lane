///|
priv struct DiagnosticCheckpoint {
  length : Int
}

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

///|
fn SemanticChecker::diagnostic_checkpoint(
  self : SemanticChecker,
) -> DiagnosticCheckpoint {
  { length: self.diagnostics.length() }
}

///|
fn SemanticChecker::rollback_diagnostics(
  self : SemanticChecker,
  checkpoint : DiagnosticCheckpoint,
) -> Unit {
  self.diagnostics.truncate(checkpoint.length)
}
