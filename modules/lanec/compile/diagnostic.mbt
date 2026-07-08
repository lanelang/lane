///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticFact,
  type CompilerDiagnosticLabel,
  type CompilerDiagnosticSeverity,
  type CompilerDiagnosticSuggestion,
  compiler_diagnostic,
  compiler_primary_labels,
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompilerDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity~,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
  )
}

///|
fn primary_label(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompilerDiagnosticLabel] {
  compiler_primary_labels(span, message)
}

///|
fn compile_report(
  title : String,
  span : @basic.SourceSpan?,
  code~ : String,
  label~ : String,
  note~ : String,
  help~ : String,
) -> CompilerDiagnostic {
  diagnostic(
    title,
    span~,
    severity=Error,
    code=Some(code),
    labels=primary_label(span, label),
    notes=[note],
    helps=[help],
  )
}

///|
fn resolve_diagnostic(
  diagnostic_ : @resolve.ResolveDiagnostic,
  _display : @typecheck.TypeDisplayContext,
) -> CompilerDiagnostic {
  ignore(_display)
  diagnostic_.to_compiler_diagnostic(DiagnosticContext())
}

///|
fn typecheck_diagnostic(
  diagnostic_ : @typecheck.TypeCheckDiagnostic,
  display : @typecheck.TypeDisplayContext,
) -> CompilerDiagnostic {
  diagnostic_.with_display(display).to_compiler_diagnostic(DiagnosticContext())
}
