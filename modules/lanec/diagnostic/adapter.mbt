///|
pub struct CompilerDiagnosticSources {
  database : @diag_source.SourceDatabase
  source_ids : Array[String]
  diagnostic_ids : Array[@diag_core.SourceId]
}

///|
pub fn CompilerDiagnosticSources::CompilerDiagnosticSources() -> CompilerDiagnosticSources {
  { database: SourceDatabase(), source_ids: [], diagnostic_ids: [] }
}

///|
pub fn CompilerDiagnosticSources::add(
  self : CompilerDiagnosticSources,
  source_id : String,
  text : String,
  path : String?,
) -> Unit {
  let diagnostic_id = match path {
    Some(path) => self.database.add(text, path~)
    None => self.database.add(text)
  }
  self.source_ids.push(source_id)
  self.diagnostic_ids.push(diagnostic_id)
}

///|
pub fn CompilerDiagnosticSources::find(
  self : CompilerDiagnosticSources,
  source_id : String,
) -> @diag_core.SourceId? {
  for index, candidate in self.source_ids {
    if candidate == source_id {
      return self.diagnostic_ids.get(index)
    }
  }
  None
}

///|
pub fn CompilerDiagnosticSources::source_database(
  self : CompilerDiagnosticSources,
) -> @diag_source.SourceDatabase {
  self.database
}

///|
pub fn CompilerDiagnostic::to_diagnostic(
  self : CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> @diag_core.Diagnostic {
  {
    severity: self.severity.to_diagnostic_severity(),
    code: self.code,
    message: self.message,
    labels: self.labels_to_diagnostic_labels(sources),
    notes: self.unmapped_label_notes(sources) + self.notes,
    helps: self.helps,
    facts: self.facts_to_diagnostic_facts(sources),
    suggestions: self.suggestions_to_diagnostic_suggestions(sources),
    related_locations: [],
    related: [],
  }
}

///|
fn CompilerDiagnosticSeverity::to_diagnostic_severity(
  self : CompilerDiagnosticSeverity,
) -> @diag_core.Severity {
  match self {
    Error => Error
    Warning => Warning
  }
}

///|
fn CompilerDiagnostic::labels_to_diagnostic_labels(
  self : CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> Array[@diag_core.Label] {
  guard self.source_id is Some(source_id) else { return [] }
  guard sources.find(source_id) is Some(diagnostic_source_id) else { return [] }
  let labels : Array[@diag_core.Label] = []
  for label in self.labels {
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
fn CompilerDiagnostic::unmapped_label_notes(
  self : CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> Array[String] {
  if self.source_id is Some(source_id) {
    if sources.find(source_id) is Some(_) {
      return []
    }
  }
  self.labels.map(fn(label) { label.message })
}

///|
fn CompilerDiagnostic::facts_to_diagnostic_facts(
  self : CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> Array[@diag_core.DiagnosticFact] {
  self.facts.map(fn(fact) {
    {
      name: fact.name,
      value: fact.value,
      span: self.optional_span_to_diagnostic_span(fact.span, sources),
    }
  })
}

///|
fn CompilerDiagnostic::suggestions_to_diagnostic_suggestions(
  self : CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> Array[@diag_core.Suggestion] {
  self.suggestions.map(fn(suggestion) {
    {
      message: suggestion.message,
      edits: suggestion.edits.filter_map(fn(edit) {
        match self.span_to_diagnostic_span(edit.span, sources) {
          Some(span) => Some({ span, replacement: edit.replacement })
          None => None
        }
      }),
      applicability: suggestion.applicability.to_diagnostic_applicability(),
    }
  })
}

///|
fn CompilerDiagnostic::optional_span_to_diagnostic_span(
  self : CompilerDiagnostic,
  span : @basic.SourceSpan?,
  sources : CompilerDiagnosticSources,
) -> @diag_core.SourceSpan? {
  match span {
    Some(span) => self.span_to_diagnostic_span(span, sources)
    None => None
  }
}

///|
fn CompilerDiagnostic::span_to_diagnostic_span(
  self : CompilerDiagnostic,
  span : @basic.SourceSpan,
  sources : CompilerDiagnosticSources,
) -> @diag_core.SourceSpan? {
  guard self.source_id is Some(source_id) else { return None }
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
fn CompilerDiagnosticLabelStyle::to_diagnostic_label_style(
  self : CompilerDiagnosticLabelStyle,
) -> @diag_core.LabelStyle {
  match self {
    Primary => Primary
    Secondary => Secondary
  }
}

///|
fn CompilerDiagnosticApplicability::to_diagnostic_applicability(
  self : CompilerDiagnosticApplicability,
) -> @diag_core.Applicability {
  match self {
    MachineApplicable => MachineApplicable
    MaybeIncorrect => MaybeIncorrect
    HasPlaceholders => HasPlaceholders
    Unspecified => Unspecified
  }
}
