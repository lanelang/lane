///|
pub(all) struct DiagnosticContext {
  source_id : String?
} derive(Debug, Eq)

///|
pub fn DiagnosticContext::DiagnosticContext(
  source_id? : String,
) -> DiagnosticContext {
  { source_id, }
}

///|
pub(open) trait ToCompilerDiagnostic {
  fn to_compiler_diagnostic(Self, DiagnosticContext) -> CompilerDiagnostic
}

///|
pub fn compiler_diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompilerDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
  context? : DiagnosticContext = DiagnosticContext(),
) -> CompilerDiagnostic {
  let diagnostic : CompilerDiagnostic = {
    source_id: None,
    message,
    span: span.map(compiler_local_span),
    severity,
    code,
    labels,
    notes,
    helps,
    facts,
    suggestions,
  }
  match context.source_id {
    Some(source_id) => diagnostic.with_source_id(source_id)
    None => diagnostic
  }
}

///|
pub fn compiler_error(
  message : String,
  span~ : @basic.SourceSpan?,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
  context? : DiagnosticContext = DiagnosticContext(),
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity=Error,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
    context~,
  )
}

///|
pub fn compiler_warning(
  message : String,
  span~ : @basic.SourceSpan?,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
  context? : DiagnosticContext = DiagnosticContext(),
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity=Warning,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
    context~,
  )
}

///|
pub fn compiler_primary_label(
  span : @basic.SourceSpan,
  message : String,
) -> CompilerDiagnosticLabel {
  { span: compiler_local_span(span), message, style: Primary }
}

///|
pub fn compiler_secondary_label(
  span : @basic.SourceSpan,
  message : String,
) -> CompilerDiagnosticLabel {
  { span: compiler_local_span(span), message, style: Secondary }
}

///|
pub fn compiler_primary_labels(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompilerDiagnosticLabel] {
  match span {
    Some(span) => [compiler_primary_label(span, message)]
    None => []
  }
}
