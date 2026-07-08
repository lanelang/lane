///|
priv struct LspWorkspaceAnalysis {
  workspace_root : String?
  documents : Map[String, DocumentSnapshot]
}

///|
priv struct LspAnalysisSources {
  root : @module_frontend.SourceInput
  libraries : Array[@module_frontend.SourceInput]
}

///|
fn LspWorkspaceAnalysis::LspWorkspaceAnalysis(
  workspace_root : String?,
  documents : Map[String, DocumentSnapshot],
) -> LspWorkspaceAnalysis {
  { workspace_root, documents }
}

///|
async fn LspWorkspaceAnalysis::check(
  self : LspWorkspaceAnalysis,
  document : DocumentSnapshot,
) -> Array[DiagnosticPublication] {
  let sources = self.analysis_sources(document)
  let analysis = self.analyze_sources(sources)
  diagnostic_publications(
    self.diagnostic_publication_inputs(sources, analysis.diagnostics),
    analysis.diagnostics,
    fallback_uri=document.uri,
  )
}

///|
async fn LspWorkspaceAnalysis::analyze(
  self : LspWorkspaceAnalysis,
  document : DocumentSnapshot,
) -> @analysis.AnalysisResult {
  self.analyze_sources(self.analysis_sources(document))
}

///|
async fn LspWorkspaceAnalysis::complete(
  self : LspWorkspaceAnalysis,
  document : DocumentSnapshot,
  line : Int,
  column : Int,
  trigger : @analysis.CompletionTrigger,
) -> Array[@analysis.CompletionEntry] {
  let sources = self.analysis_sources(document)
  match self.workspace_root {
    Some(_) =>
      @analysis.complete_import_reachable_source_inputs(
        sources.root,
        sources.libraries,
        document.uri,
        line,
        column,
        trigger,
      )
    None =>
      @analysis.complete_source_inputs(
        sources.root,
        sources.libraries,
        document.uri,
        line,
        column,
        trigger,
      )
  }
}

///|
fn LspWorkspaceAnalysis::analyze_sources(
  self : LspWorkspaceAnalysis,
  sources : LspAnalysisSources,
) -> @analysis.AnalysisResult {
  match self.workspace_root {
    Some(_) =>
      @analysis.analyze_import_reachable_source_inputs(
        sources.root,
        sources.libraries,
      )
    None => @analysis.analyze_source_inputs(sources.root, sources.libraries)
  }
}

///|
fn LspWorkspaceAnalysis::diagnostic_publication_inputs(
  self : LspWorkspaceAnalysis,
  sources : LspAnalysisSources,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
) -> Array[@module_frontend.SourceInput] {
  match self.workspace_root {
    Some(_) =>
      match
        @module_frontend.import_reachable_source_inputs(
          sources.root,
          sources.libraries,
        ) {
        Ok(inputs) => inputs
        Err(_) => sources.inputs_with_diagnostics(diagnostics)
      }
    None => [sources.root]
  }
}

///|
fn LspAnalysisSources::inputs_with_diagnostics(
  self : LspAnalysisSources,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
) -> Array[@module_frontend.SourceInput] {
  let source_ids : Array[String] = []
  for diagnostic in diagnostics {
    for source_id in diagnostic.source_ids() {
      if !source_ids.contains(source_id) {
        source_ids.push(source_id)
      }
    }
  }
  [self.root] +
  self.libraries.filter(fn(input) { source_ids.contains(input.source_id) })
}

///|
async fn LspWorkspaceAnalysis::analysis_sources(
  self : LspWorkspaceAnalysis,
  document : DocumentSnapshot,
) -> LspAnalysisSources {
  let root_input : @module_frontend.SourceInput = {
    source_id: document.uri,
    text: document.text,
  }
  match self.workspace_root {
    Some(root) => {
      let libraries = self
        .workspace_sources(root)
        .without_source_id(document.uri)
      { root: root_input, libraries }
    }
    None => { root: root_input, libraries: [] }
  }
}

///|
async fn LspWorkspaceAnalysis::workspace_sources(
  self : LspWorkspaceAnalysis,
  root : String,
) -> Array[@module_frontend.SourceInput] {
  let library_identities = []
  let sources = self.open_document_library_sources(root, library_identities)
  append_lane_sources(root, library_identities, sources) catch {
    _ => ()
  }
  sources.sort_by(fn(left, right) {
    String::compare(left.source_id, right.source_id)
  })
  sources
}

///|
async fn LspWorkspaceAnalysis::open_document_library_sources(
  self : LspWorkspaceAnalysis,
  root : String,
  library_identities : Array[String],
) -> Array[@module_frontend.SourceInput] {
  let sources : Array[@module_frontend.SourceInput] = []
  for _, document in self.documents {
    guard file_uri_to_path(document.uri) is Some(path) else { continue }
    let identity = lsp_source_identity(path)
    if !library_identities.contains(identity) &&
      path.has_suffix(".lane") &&
      path_is_under_workspace(path, root) {
      library_identities.push(identity)
      sources.push({ source_id: document.uri, text: document.text })
    }
  }
  sources
}

///|
fn Array::without_source_id(
  self : Array[@module_frontend.SourceInput],
  source_id : String,
) -> Array[@module_frontend.SourceInput] {
  self.filter(fn(input) { input.source_id != source_id })
}

///|
async fn lsp_source_identity(path : String) -> String {
  @fs.realpath(path) catch {
    _ => path
  }
}

///|
async fn append_lane_sources(
  path : String,
  library_identities : Array[String],
  sources : Array[@module_frontend.SourceInput],
) -> Unit {
  let entries = @fs.readdir(path, sort=true)
  for entry in entries {
    if should_skip_workspace_entry(entry) {
      continue
    }
    let child = "\{path}/\{entry}"
    match @fs.kind(child) {
      Directory => append_lane_sources(child, library_identities, sources)
      Regular if child.has_suffix(".lane") => {
        let identity = lsp_source_identity(child)
        if library_identities.contains(identity) {
          continue
        }
        library_identities.push(identity)
        sources.push({
          source_id: path_to_file_uri(child),
          text: @fs.read_file(child).text(),
        })
      }
      _ => ()
    }
  }
}

///|
fn should_skip_workspace_entry(entry : String) -> Bool {
  entry.has_prefix(".") ||
  entry == "_build" ||
  entry == "build" ||
  entry == "dist"
}
