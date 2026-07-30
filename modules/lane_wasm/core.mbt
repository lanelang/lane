///|
let status_ok : Int = 0

///|
let status_diagnostics : Int = 1

///|
let status_transport_error : Int = 2

///|
let status_invalid_request : Int = 3

///|
priv struct ExploreResult {
  status : Int
  json : String
}

///|
fn explore_request(request_text : String) -> ExploreResult {
  let request = match parse_explore_request(request_text) {
    Ok(request) => request
    Err(reason) => {
      let status = status_invalid_request
      return { status, json: invalid_request_response(reason).stringify() }
    }
  }
  let report = @driver.explore(request)
  let status = match report.status {
    Succeeded => status_ok
    Failed(_) => status_diagnostics
  }
  { status, json: report_json(report).stringify() }
}

///|
fn entries_request(request_text : String) -> ExploreResult {
  let sources = match parse_entry_request(request_text) {
    Ok(sources) => sources
    Err(reason) => {
      let status = status_invalid_request
      return { status, json: invalid_request_response(reason).stringify() }
    }
  }
  let report = @driver.list_entries(sources.0, sources.1)
  let status = if report.diagnostics.any(diagnostic => {
      diagnostic.severity is Error
    }) {
    status_diagnostics
  } else {
    status_ok
  }
  let response : Json = {
    "schemaVersion": report.schema_version,
    "status": status,
    "diagnostics": report.diagnostics.map(compile_diagnostic_json),
    "entries": report.entries.map(entry => {
      "module": entry.module_path_text,
      "name": entry.name,
      "type": entry.type_text,
    }),
  }
  { status, json: response.stringify() }
}

///|
fn parse_explore_request(
  request_text : String,
) -> Result[@driver.ExploreRequest, String] {
  let json = @json.parse(request_text) catch {
    _ => return Err("expected JSON request")
  }
  match json {
    { "entry": String(entry), .. } => {
      let sources = match parse_source_set(json) {
        Ok(sources) => sources
        Err(message) => return Err(message)
      }
      if entry.is_empty() {
        return Err("entry must not be empty")
      }
      Ok({ root_source: sources.0, library_sources: sources.1, entry })
    }
    _ =>
      Err(
        "expected `root`, `libraries`, and `entry` fields in the request object",
      )
  }
}

///|
fn parse_entry_request(
  request_text : String,
) -> Result[
  (@module_frontend.SourceInput, Array[@module_frontend.SourceInput]),
  String,
] {
  let json = @json.parse(request_text) catch {
    _ => return Err("expected JSON request")
  }
  parse_source_set(json)
}

///|
fn parse_source_set(
  json : Json,
) -> Result[
  (@module_frontend.SourceInput, Array[@module_frontend.SourceInput]),
  String,
] {
  guard json is { "root": root_json, "libraries": Array(library_jsons), .. } else {
    return Err("expected `root` and `libraries` fields in the request object")
  }
  let root_source = match parse_source_input(root_json) {
    Ok(source) => source
    Err(message) => return Err("invalid root source: \{message}")
  }
  let library_sources = []
  for library_json in library_jsons {
    match parse_source_input(library_json) {
      Ok(source) => library_sources.push(source)
      Err(message) => return Err("invalid library source: \{message}")
    }
  }
  Ok((root_source, library_sources))
}

///|
fn parse_source_input(
  json : Json,
) -> Result[@module_frontend.SourceInput, String] {
  match json {
    { "sourceId": String(source_id), "text": String(text), .. } =>
      if source_id.is_empty() {
        Err("sourceId must not be empty")
      } else {
        Ok({ source_id, text })
      }
    _ => Err("expected string fields `sourceId` and `text`")
  }
}

///|
fn invalid_request_response(reason : String) -> Json {
  {
    "schemaVersion": 1,
    "status": status_invalid_request,
    "diagnostics": [
      {
        "source": "lane_wasm",
        "severity": "error",
        "message": reason,
        "range": range_json(@basic.SourceSpan::dummy()),
      },
    ],
    "stages": [],
  }
}

///|
fn report_json(report : @driver.ExploreReport) -> Json {
  let root : Map[String, Json] = { "sourceId": report.root.source_id.to_json() }
  if report.root.module_path_text is Some(module_) {
    root["module"] = module_.to_json()
  }
  let fields : Map[String, Json] = {
    "schemaVersion": report.schema_version,
    "compiler": {
      "name": report.compiler.name,
      "version": report.compiler.version,
    },
    "root": root,
    "status": report_status_json(report.status),
    "diagnostics": report.diagnostics.map(compile_diagnostic_json),
    "stages": report.stages.ordered().map(stage_json),
  }
  if report.selected_entry is Some(entry) {
    fields["selectedEntry"] = {
      "module": entry.module_path_text,
      "name": entry.name,
      "type": entry.type_text,
    }
  }
  fields.to_json()
}

///|
fn stage_json(stage : @driver.ExploreStage) -> Json {
  let fields : Map[String, Json] = { "id": stage.id, "title": stage.title }
  match stage.state {
    Completed(snapshot) => {
      fields["status"] = "completed"
      fields["domain"] = snapshot.domain.name().to_json()
      fields["format"] = snapshot.text_format.name().to_json()
      fields["text"] = snapshot.text.to_json()
      fields["diagnostics"] = snapshot.diagnostics
        .map(compile_diagnostic_json)
        .to_json()
    }
    Failed(diagnostics) => {
      fields["status"] = "failed"
      fields["diagnostics"] = diagnostics.map(compile_diagnostic_json).to_json()
    }
    Unavailable => fields["status"] = "unavailable"
  }
  fields.to_json()
}

///|
fn report_status_json(status : @driver.ExploreStatus) -> Json {
  match status {
    Succeeded => { "kind": "succeeded" }
    Failed(stage) => { "kind": "failed", "stage": stage.key() }
  }
}

///|
fn compile_diagnostic_json(
  diagnostic : @compiler_diag.CompilerDiagnostic,
) -> Json {
  let fields : Map[String, Json] = {
    "source": "lane",
    "severity": diagnostic_severity_json(diagnostic.severity),
    "message": diagnostic.message,
    "range": diagnostic_range_json(diagnostic.span),
  }
  if diagnostic.source_id is Some(source_id) {
    fields["sourceId"] = source_id.to_json()
  }
  if diagnostic.code is Some(code) {
    fields["code"] = code.to_json()
  }
  let labels = diagnostic.labels.map(fn(label) {
    let fields : Map[String, Json] = {
      "message": label.message,
      "style": diagnostic_label_style_json(label.style),
      "range": compiler_span_range_json(label.span),
    }
    if label.span.source_id() is Some(source_id) {
      fields["sourceId"] = source_id.to_json()
    }
    fields.to_json()
  })
  if !labels.is_empty() {
    fields["labels"] = labels.to_json()
  }
  if !diagnostic.notes.is_empty() {
    fields["notes"] = diagnostic.notes.to_json()
  }
  if !diagnostic.helps.is_empty() {
    fields["helps"] = diagnostic.helps.to_json()
  }
  fields.to_json()
}

///|
fn diagnostic_range_json(span : @compiler_diag.CompilerSourceSpan?) -> Json {
  match span {
    Some(span) => compiler_span_range_json(span)
    None => range_json(@basic.SourceSpan::dummy())
  }
}

///|
fn compiler_span_range_json(span : @compiler_diag.CompilerSourceSpan) -> Json {
  match span {
    Local(span) | Source(span~, ..) => range_json(span)
  }
}

///|
fn diagnostic_severity_json(
  severity : @compiler_diag.CompilerDiagnosticSeverity,
) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}

///|
fn diagnostic_label_style_json(
  style : @compiler_diag.CompilerDiagnosticLabelStyle,
) -> String {
  match style {
    Primary => "primary"
    Secondary => "secondary"
  }
}

///|
fn range_json(span : @basic.SourceSpan) -> Json {
  {
    "start": {
      "line": span.start_line,
      "column": span.start_column,
      "offset": span.start_offset,
    },
    "end": {
      "line": span.end_line,
      "column": span.end_column,
      "offset": span.end_offset,
    },
  }
}
