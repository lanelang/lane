///|
let status_ok : Int = 0

///|
let status_diagnostics : Int = 1

///|
let status_overflow : Int = 2

///|
let status_invalid_request : Int = 3

///|
priv struct ExploreResult {
  status : Int
  json : String
}

///|
fn explore_request(request_text : String) -> ExploreResult {
  let source = match parse_request_source(request_text) {
    Ok(source) => source
    Err(reason) => {
      let status = status_invalid_request
      return { status, json: invalid_request_response(reason).stringify() }
    }
  }
  let response = explore_source(source)
  let status = response_status(response)
  { status, json: response.stringify() }
}

///|
fn parse_request_source(request_text : String) -> Result[String, String] {
  let json = @json.parse(request_text) catch {
    _ => return Err("expected JSON request")
  }
  match json {
    { "source": String(source), .. } => Ok(source)
    _ => Err("expected request object with string field `source`")
  }
}

///|
fn response_status(response : Json) -> Int {
  match response {
    { "status": Number(status, ..), .. } => status.to_int()
    _ => status_ok
  }
}

///|
fn explore_source(source : String) -> Json {
  let checked = @compile.check_source(source)
  match checked.source {
    None =>
      response_json(
        status_diagnostics,
        checked.diagnostics.map(compile_diagnostic_json),
        [],
      )
    Some(source) => {
      let buslane = @elaborate.lower_checked_source_file_to_buslane(source)
      let anf = @anf.lower_buslane_program_to_anf(buslane)
      let diagnostics = checked.diagnostics.map(compile_diagnostic_json)
      let status = if diagnostics.is_empty() {
        status_ok
      } else {
        status_diagnostics
      }
      response_json(status, diagnostics, [
        pane_json("checked", @prettyprinter.render(source, width=100)),
        pane_json("buslane", @prettyprinter.render(buslane, width=100)),
        pane_json("buslane-anf", @prettyprinter.render(anf, width=100)),
      ])
    }
  }
}

///|
fn invalid_request_response(reason : String) -> Json {
  response_json(
    status_invalid_request,
    [
      {
        "source": "lane_wasm",
        "severity": "error",
        "message": reason,
        "range": range_json(@basic.SourceSpan::dummy()),
      },
    ],
    [],
  )
}

///|
fn response_json(
  status : Int,
  diagnostics : Array[Json],
  panes : Array[Json],
) -> Json {
  { "status": status, "diagnostics": diagnostics, "panes": panes }
}

///|
fn pane_json(name : String, text : String) -> Json {
  { "name": name, "text": text }
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
