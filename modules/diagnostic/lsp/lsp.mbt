///|
pub fn diagnostic_to_lsp_json(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
  source? : String,
) -> Json {
  let fields : Map[String, Json] = {
    "severity": severity_to_lsp_number(diagnostic.severity).to_json(),
    "message": diagnostic_message(diagnostic).to_json(),
  }
  if source is Some(source) {
    fields["source"] = source.to_json()
  }
  if diagnostic.code is Some(code) {
    fields["code"] = code.to_json()
  }
  fields["range"] = diagnostic_range_to_lsp_json(diagnostic, sources)
  if diagnostic_data_json(diagnostic) is Some(data) {
    fields["data"] = data
  }
  let related = related_information_json(diagnostic, sources)
  if !related.is_empty() {
    fields["relatedInformation"] = related.to_json()
  }
  fields.to_json()
}

///|
pub fn suggestions_to_code_actions_json(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
) -> Array[Json] {
  diagnostic.suggestions.map(fn(suggestion) {
    suggestion_to_code_action_json(diagnostic, suggestion, sources)
  })
}

///|
fn suggestion_to_code_action_json(
  diagnostic : @core.Diagnostic,
  suggestion : @core.Suggestion,
  sources : @source.SourceDatabase,
) -> Json {
  {
    "title": suggestion.message,
    "kind": "quickfix",
    "diagnostics": [diagnostic_to_lsp_json(diagnostic, sources)],
    "edit": { "changes": edits_by_uri_json(suggestion.edits, sources) },
  }
}

///|
fn edits_by_uri_json(
  edits : Array[@core.TextEdit],
  sources : @source.SourceDatabase,
) -> Json {
  let changes : Map[String, Json] = Map([])
  for edit in edits {
    guard sources.file(edit.span.source_id) is Some(file) else { continue }
    let uri = file.display_name()
    let items = match changes.get(uri) {
      Some(Array(items)) => items
      _ => []
    }
    items.push({
      "range": range_to_lsp_json(edit.span, sources),
      "newText": edit.replacement,
    })
    changes[uri] = items.to_json()
  }
  changes.to_json()
}

///|
fn related_to_lsp_json(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
) -> Json? {
  guard diagnostic.labels.get(0) is Some(label) else { return None }
  Some({
    "location": {
      "uri": source_uri(label.span.source_id, sources),
      "range": range_to_lsp_json(label.span, sources),
    },
    "message": diagnostic.message,
  })
}

///|
fn diagnostic_message(diagnostic : @core.Diagnostic) -> String {
  let lines = [diagnostic.message]
  for label in diagnostic.labels {
    if label.style == Primary {
      if label.message is Some(message) {
        push_diagnostic_message_line(lines, message)
      }
    }
  }
  lines.join("\n")
}

///|
fn push_diagnostic_message_line(lines : Array[String], line : String) -> Unit {
  if !line.is_empty() && !lines.contains(line) {
    lines.push(line)
  }
}

///|
fn related_information_json(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
) -> Array[Json] {
  let items : Array[Json] = []
  for label in diagnostic.labels {
    if label.style == Secondary && label.message is Some(message) {
      items.push(location_message_json(label.span, message, sources))
    }
  }
  for related in diagnostic.related_locations {
    items.push(location_message_json(related.span, related.message, sources))
  }
  for related in diagnostic.related {
    if related_to_lsp_json(related, sources) is Some(item) {
      items.push(item)
    }
  }
  items
}

///|
fn diagnostic_data_json(diagnostic : @core.Diagnostic) -> Json? {
  if diagnostic.facts.is_empty() &&
    diagnostic.suggestions.is_empty() &&
    diagnostic.notes.is_empty() &&
    diagnostic.helps.is_empty() {
    return None
  }
  let fields : Map[String, Json] = Map([])
  if !diagnostic.notes.is_empty() {
    fields["notes"] = diagnostic.notes.to_json()
  }
  if !diagnostic.helps.is_empty() {
    fields["helps"] = diagnostic.helps.to_json()
  }
  if !diagnostic.facts.is_empty() {
    fields["facts"] = diagnostic.facts.map(fact_to_json).to_json()
  }
  if !diagnostic.suggestions.is_empty() {
    fields["suggestions"] = diagnostic.suggestions
      .map(suggestion_data_json)
      .to_json()
  }
  Some(fields.to_json())
}

///|
fn fact_to_json(fact : @core.DiagnosticFact) -> Json {
  let has_span = match fact.span {
    Some(_) => true
    None => false
  }
  { "name": fact.name, "value": fact.value, "hasSpan": has_span }
}

///|
fn suggestion_data_json(suggestion : @core.Suggestion) -> Json {
  {
    "message": suggestion.message,
    "applicability": suggestion.applicability.as_text(),
  }
}

///|
fn location_message_json(
  span : @core.SourceSpan,
  message : String,
  sources : @source.SourceDatabase,
) -> Json {
  {
    "location": {
      "uri": source_uri(span.source_id, sources),
      "range": range_to_lsp_json(span, sources),
    },
    "message": message,
  }
}

///|
fn source_uri(
  source_id : @core.SourceId,
  sources : @source.SourceDatabase,
) -> String {
  match sources.file(source_id) {
    Some(file) => file.display_name()
    None => "<source#\{source_id.value}>"
  }
}

///|
fn diagnostic_range_to_lsp_json(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
) -> Json {
  match diagnostic.labels.get(0) {
    Some(label) => range_to_lsp_json(label.span, sources)
    None => empty_range_to_lsp_json()
  }
}

///|
fn range_to_lsp_json(
  span : @core.SourceSpan,
  sources : @source.SourceDatabase,
) -> Json {
  match sources.range(span) {
    Some(range) =>
      {
        "start": position_to_lsp_json(range.start),
        "end": position_to_lsp_json(range.end),
      }
    None => empty_range_to_lsp_json()
  }
}

///|
fn empty_range_to_lsp_json() -> Json {
  {
    "start": { "line": 0, "character": 0 },
    "end": { "line": 0, "character": 0 },
  }
}

///|
fn position_to_lsp_json(position : @source.SourcePosition) -> Json {
  { "line": position.line - 1, "character": position.column - 1 }
}

///|
fn severity_to_lsp_number(severity : @core.Severity) -> Int {
  match severity {
    Error => 1
    Warning => 2
    Info => 3
    Hint => 4
  }
}
