///|
using @compiler_diag {type CompilerDiagnosticSources}

///|
priv struct DiagnosticPublication {
  uri : String
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  sources : CompilerDiagnosticSources
}

///|
fn compiler_diagnostic_sources_from_inputs(
  inputs : Array[@compile.SourceInput],
) -> CompilerDiagnosticSources {
  let sources = @compiler_diag.CompilerDiagnosticSources::CompilerDiagnosticSources()
  for input in inputs {
    sources.add(input.source_id, input.text, Some(input.source_id))
  }
  sources
}

///|
fn publish_diagnostics(
  uri : String,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  sources? : CompilerDiagnosticSources = CompilerDiagnosticSources(),
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
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  fallback_uri~ : String,
) -> Array[DiagnosticPublication] {
  let sources = compiler_diagnostic_sources_from_inputs(inputs)
  let publications = inputs.map(fn(input) {
    { uri: input.source_id, diagnostics: [], sources }
  })
  for diagnostic in diagnostics {
    let uri = match diagnostic.primary_source_id() {
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
  diagnostic : @compiler_diag.CompilerDiagnostic,
) -> Unit {
  for publication in publications {
    if publication.uri == uri {
      publication.diagnostics.push(diagnostic)
      return
    }
  }
  let empty_sources = CompilerDiagnosticSources()
  publications.push({ uri, diagnostics: [diagnostic], sources: empty_sources })
}

///|
fn compile_diagnostic_json(
  diagnostic : @compiler_diag.CompilerDiagnostic,
  sources : CompilerDiagnosticSources,
) -> Json {
  @diag_lsp.diagnostic_to_lsp_json(
    diagnostic.to_diagnostic(sources),
    sources.source_database(),
    source="lane",
  )
}
