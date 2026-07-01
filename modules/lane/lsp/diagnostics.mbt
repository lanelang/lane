///|
priv struct DiagnosticPublication {
  uri : String
  diagnostics : Array[@compile.CompileDiagnostic]
}

///|
fn publish_diagnostics(
  uri : String,
  diagnostics : Array[@compile.CompileDiagnostic],
) -> @jsonrpc.Message {
  @jsonrpc.new_notification("textDocument/publishDiagnostics", {
    "uri": uri,
    "diagnostics": diagnostics.map(fn(diagnostic) {
      compile_diagnostic_json(uri, diagnostic)
    }),
  })
}

///|
fn diagnostic_publications(
  inputs : Array[@compile.SourceInput],
  diagnostics : Array[@compile.CompileDiagnostic],
  fallback_uri~ : String,
) -> Array[DiagnosticPublication] {
  let publications = inputs.map(fn(input) {
    { uri: input.source_id, diagnostics: [] }
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
  publications.push({ uri, diagnostics: [diagnostic] })
}

///|
fn compile_diagnostic_json(
  uri : String,
  diagnostic : @compile.CompileDiagnostic,
) -> Json {
  let fields : Map[String, Json] = {
    "range": diagnostic_range_json(diagnostic.span),
    "severity": diagnostic_severity_json(diagnostic.severity),
    "source": "lane",
    "message": diagnostic.message,
  }
  match diagnostic.code {
    Some(code) => fields["code"] = code.to_json()
    None => ()
  }
  let related = related_information_json(uri, diagnostic)
  if !related.is_empty() {
    fields["relatedInformation"] = related.to_json()
  }
  fields.to_json()
}

///|
fn related_information_json(
  uri : String,
  diagnostic : @compile.CompileDiagnostic,
) -> Array[Json] {
  let items : Array[Json] = []
  for label in diagnostic.labels {
    items.push({
      "location": { "uri": uri, "range": range_json(label.span) },
      "message": label.message,
    })
  }
  for note in diagnostic.notes {
    items.push({
      "location": {
        "uri": uri,
        "range": diagnostic_range_json(diagnostic.span),
      },
      "message": "note: \{note}",
    })
  }
  for help in diagnostic.helps {
    items.push({
      "location": {
        "uri": uri,
        "range": diagnostic_range_json(diagnostic.span),
      },
      "message": "help: \{help}",
    })
  }
  items
}

///|
fn diagnostic_range_json(span : @basic.SourceSpan?) -> Json {
  match span {
    Some(span) => range_json(span)
    None => range_json(@basic.SourceSpan::dummy())
  }
}

///|
fn diagnostic_severity_json(
  severity : @compile.CompileDiagnosticSeverity,
) -> Json {
  match severity {
    Error => 1
    Warning => 2
  }
}
