///|
pub impl @compiler_diag.ToCompilerDiagnostic for ParseError with fn to_compiler_diagnostic(
  error : ParseError,
  context : @compiler_diag.DiagnosticContext,
) -> @compiler_diag.CompilerDiagnostic {
  @compiler_diag.compiler_error(
    error.kind.diagnostic_title(),
    span=Some(error.loc),
    code=Some(error.kind.diagnostic_code()),
    labels=[
      @compiler_diag.compiler_primary_label(
        error.loc,
        error.kind.diagnostic_label(),
      ),
    ],
    notes=error.kind.diagnostic_notes(),
    helps=error.kind.diagnostic_helps(),
    context~,
  )
}
