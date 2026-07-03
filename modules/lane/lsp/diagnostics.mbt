///|
priv struct DiagnosticPublication {
  uri : String
  diagnostics : Array[@compile.CompileDiagnostic]
  sources : LspDiagnosticSources
}

///|
priv struct LspDiagnosticSourceBinding {
  source_id : String
  diagnostic_id : @diag_core.SourceId
}

///|
priv struct LspDiagnosticSources {
  database : @diag_source.SourceDatabase
  bindings : Array[LspDiagnosticSourceBinding]
}

///|
fn LspDiagnosticSources::LspDiagnosticSources() -> LspDiagnosticSources {
  { database: SourceDatabase(), bindings: [] }
}

///|
fn LspDiagnosticSources::from_inputs(
  inputs : Array[@compile.SourceInput],
) -> LspDiagnosticSources {
  let sources = LspDiagnosticSources()
  for input in inputs {
    let diagnostic_id = sources.database.add(input.text, path=input.source_id)
    sources.bindings.push({ source_id: input.source_id, diagnostic_id })
  }
  sources
}

///|
fn LspDiagnosticSources::find(
  self : LspDiagnosticSources,
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
fn publish_diagnostics(
  uri : String,
  diagnostics : Array[@compile.CompileDiagnostic],
  sources? : LspDiagnosticSources = LspDiagnosticSources(),
) -> @jsonrpc.Message {
  @jsonrpc.new_notification("textDocument/publishDiagnostics", {
    "uri": uri,
    "diagnostics": diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(diagnostic, sources)
    }),
  })
}

///|
fn diagnostic_publications(
  inputs : Array[@compile.SourceInput],
  diagnostics : Array[@compile.CompileDiagnostic],
  fallback_uri~ : String,
) -> Array[DiagnosticPublication] {
  let sources = LspDiagnosticSources::from_inputs(inputs)
  let publications = inputs.map(fn(input) {
    { uri: input.source_id, diagnostics: [], sources }
  })
  for diagnostic in diagnostics {
    let uri = match diagnostic.source_id {
      Some(source_id) => source_id
      None => fallback_uri
    }
    add_diagnostic(publications, uri, diagnostic)
  }
  publications
}

///|
fn add_diagnostic(
  publications : Array[DiagnosticPublication],
  uri : String,
  diagnostic : @compile.CompileDiagnostic,
) -> Unit {
  for publication in publications {
    if publication.uri == uri {
      publication.diagnostics.push(diagnostic)
      return
    }
  }
  let empty_sources = LspDiagnosticSources()
  publications.push({ uri, diagnostics: [diagnostic], sources: empty_sources })
}

///|
fn compile_diagnostic_json(
  diagnostic : @compile.CompileDiagnostic,
  sources : LspDiagnosticSources,
) -> Json {
  @diag_lsp.diagnostic_to_lsp_json(
    compile_diagnostic_to_diagnostic(diagnostic, sources),
    sources.database,
    source="lane",
  )
}

///|
fn compile_diagnostic_to_diagnostic(
  diagnostic : @compile.CompileDiagnostic,
  sources : LspDiagnosticSources,
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
fn @compile.CompileDiagnosticSeverity::to_diagnostic_severity(
  self : @compile.CompileDiagnosticSeverity,
) -> @diag_core.Severity {
  match self {
    Error => Error
    Warning => Warning
  }
}

///|
fn compile_diagnostic_labels_to_diagnostic_labels(
  diagnostic : @compile.CompileDiagnostic,
  sources : LspDiagnosticSources,
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
  diagnostic : @compile.CompileDiagnostic,
  sources : LspDiagnosticSources,
) -> Array[String] {
  match diagnostic.source_id {
    Some(source_id) if sources.find(source_id) is Some(_) => []
    _ => diagnostic.labels.map(fn(label) { label.message })
  }
}

///|
fn compile_diagnostic_facts_to_diagnostic_facts(
  diagnostic : @compile.CompileDiagnostic,
  sources : LspDiagnosticSources,
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
  diagnostic : @compile.CompileDiagnostic,
  sources : LspDiagnosticSources,
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
  diagnostic : @compile.CompileDiagnostic,
  span : @basic.SourceSpan?,
  sources : LspDiagnosticSources,
) -> @diag_core.SourceSpan? {
  match span {
    Some(span) => compile_span_to_diagnostic_span(diagnostic, span, sources)
    None => None
  }
}

///|
fn compile_span_to_diagnostic_span(
  diagnostic : @compile.CompileDiagnostic,
  span : @basic.SourceSpan,
  sources : LspDiagnosticSources,
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
fn @compile.CompileDiagnosticLabelStyle::to_diagnostic_label_style(
  self : @compile.CompileDiagnosticLabelStyle,
) -> @diag_core.LabelStyle {
  match self {
    Primary => Primary
    Secondary => Secondary
  }
}

///|
fn @compile.CompileDiagnosticApplicability::to_diagnostic_applicability(
  self : @compile.CompileDiagnosticApplicability,
) -> @diag_core.Applicability {
  match self {
    MachineApplicable => MachineApplicable
    MaybeIncorrect => MaybeIncorrect
    HasPlaceholders => HasPlaceholders
    Unspecified => Unspecified
  }
}
