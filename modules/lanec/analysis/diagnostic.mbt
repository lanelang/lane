///|
using @compiler_diag { type CompilerDiagnostic }

///|
fn resolve_diagnostic(
  diagnostic_ : @resolve.ResolveDiagnostic,
  _display : @typecheck.TypeDisplayContext,
) -> @compiler_diag.CompilerDiagnostic {
  ignore(_display)
  diagnostic_.to_compiler_diagnostic(DiagnosticContext())
}

///|
fn typecheck_diagnostic(
  diagnostic_ : @typecheck.TypeCheckDiagnostic,
  display : @typecheck.TypeDisplayContext,
) -> @compiler_diag.CompilerDiagnostic {
  diagnostic_.with_display(display).to_compiler_diagnostic(DiagnosticContext())
}
