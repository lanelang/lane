///|
priv struct DiagnosticSourceBinding {
  source_id : String
  diagnostic_id : @diag_core.SourceId
}

///|
priv struct DiagnosticSources {
  database : @diag_source.SourceDatabase
  bindings : Array[DiagnosticSourceBinding]
}

///|
fn DiagnosticSources::DiagnosticSources() -> DiagnosticSources {
  { database: SourceDatabase(), bindings: [] }
}

///|
fn DiagnosticSources::add(
  self : DiagnosticSources,
  source_id : String,
  text : String,
  path : String?,
) -> Unit {
  let diagnostic_id = match path {
    Some(path) => self.database.add(text, path~)
    None => self.database.add(text)
  }
  self.bindings.push({ source_id, diagnostic_id })
}

///|
fn DiagnosticSources::add_input(
  self : DiagnosticSources,
  input : LaneSourceInput,
) -> Unit {
  self.add(input.source_id, input.text, input.path)
}

///|
fn DiagnosticSources::find(
  self : DiagnosticSources,
  source_id : String,
) -> @diag_core.SourceId? {
  for binding in self.bindings {
    if binding.source_id == source_id {
      return Some(binding.diagnostic_id)
    }
  }
  None
}

///|
fn print_diagnostics_with_sources(
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  sources : DiagnosticSources,
) -> Unit {
  for diagnostic in diagnostics {
    println(render_compile_diagnostic(diagnostic, sources))
  }
}

///|
fn render_compile_diagnostic(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : DiagnosticSources,
) -> String {
  @diag_render.render_diagnostic(
    compile_diagnostic_to_diagnostic(diagnostic, sources),
    sources.database,
    config=@terminal.diagnostic_render_config(),
  )
}

///|
fn compile_diagnostic_to_diagnostic(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : DiagnosticSources,
) -> @diag_core.Diagnostic {
  {
    severity: diagnostic.severity.to_diagnostic_severity(),
    code: diagnostic.code,
    message: diagnostic.message,
    labels: compile_diagnostic_labels_to_diagnostic_labels(diagnostic, sources),
    notes: compile_diagnostic_unmapped_label_notes(diagnostic, sources) +
    diagnostic.notes,
    helps: diagnostic.helps,
    facts: compile_diagnostic_facts_to_diagnostic_facts(diagnostic, sources),
    suggestions: compile_diagnostic_suggestions_to_diagnostic_suggestions(
      diagnostic, sources,
    ),
    related_locations: [],
    related: [],
  }
}

///|
fn @compiler_diag.CompilerDiagnosticSeverity::to_diagnostic_severity(
  self : @compiler_diag.CompilerDiagnosticSeverity,
) -> @diag_core.Severity {
  match self {
    Error => Error
    Warning => Warning
  }
}

///|
fn compile_diagnostic_labels_to_diagnostic_labels(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : DiagnosticSources,
) -> Array[@diag_core.Label] {
  guard diagnostic.source_id is Some(source_id) else { return [] }
  guard sources.find(source_id) is Some(diagnostic_source_id) else { return [] }
  let labels : Array[@diag_core.Label] = []
  for label in diagnostic.labels {
    labels.push({
      style: label.style.to_diagnostic_label_style(),
      span: sources.database.span_from_text_offsets(
        diagnostic_source_id,
        label.span.start_offset,
        label.span.end_offset,
      ),
      message: Some(label.message),
    })
  }
  labels
}

///|
fn compile_diagnostic_unmapped_label_notes(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : DiagnosticSources,
) -> Array[String] {
  match diagnostic.source_id {
    Some(source_id) if sources.find(source_id) is Some(_) => []
    _ => diagnostic.labels.map(fn(label) { label.message })
  }
}

///|
fn compile_diagnostic_facts_to_diagnostic_facts(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : DiagnosticSources,
) -> Array[@diag_core.DiagnosticFact] {
  diagnostic.facts.map(fn(fact) {
    {
      name: fact.name,
      value: fact.value,
      span: compile_optional_span_to_diagnostic_span(
        diagnostic,
        fact.span,
        sources,
      ),
    }
  })
}

///|
fn compile_diagnostic_suggestions_to_diagnostic_suggestions(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : DiagnosticSources,
) -> Array[@diag_core.Suggestion] {
  diagnostic.suggestions.map(fn(suggestion) {
    {
      message: suggestion.message,
      edits: suggestion.edits.filter_map(fn(edit) {
        match compile_span_to_diagnostic_span(diagnostic, edit.span, sources) {
          Some(span) => Some({ span, replacement: edit.replacement })
          None => None
        }
      }),
      applicability: suggestion.applicability.to_diagnostic_applicability(),
    }
  })
}

///|
fn compile_optional_span_to_diagnostic_span(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  span : @basic.SourceSpan?,
  sources : DiagnosticSources,
) -> @diag_core.SourceSpan? {
  match span {
    Some(span) => compile_span_to_diagnostic_span(diagnostic, span, sources)
    None => None
  }
}

///|
fn compile_span_to_diagnostic_span(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  span : @basic.SourceSpan,
  sources : DiagnosticSources,
) -> @diag_core.SourceSpan? {
  guard diagnostic.source_id is Some(source_id) else { return None }
  guard sources.find(source_id) is Some(diagnostic_source_id) else {
    return None
  }
  Some(
    sources.database.span_from_text_offsets(
      diagnostic_source_id,
      span.start_offset,
      span.end_offset,
    ),
  )
}

///|
fn @compiler_diag.CompilerDiagnosticLabelStyle::to_diagnostic_label_style(
  self : @compiler_diag.CompilerDiagnosticLabelStyle,
) -> @diag_core.LabelStyle {
  match self {
    Primary => Primary
    Secondary => Secondary
  }
}

///|
fn @compiler_diag.CompilerDiagnosticApplicability::to_diagnostic_applicability(
  self : @compiler_diag.CompilerDiagnosticApplicability,
) -> @diag_core.Applicability {
  match self {
    MachineApplicable => MachineApplicable
    MaybeIncorrect => MaybeIncorrect
    HasPlaceholders => HasPlaceholders
    Unspecified => Unspecified
  }
}

///|
fn denied_diagnostics(
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  deny : Bool,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  diagnostics.filter(fn(diagnostic) { deny || diagnostic.severity is Error })
}
