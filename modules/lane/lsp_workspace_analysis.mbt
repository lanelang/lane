///|
priv struct LspWorkspaceAnalysis {
  workspace_root : String?
  documents : Map[String, DocumentSnapshot]
}

///|
priv struct DiagnosticPublication {
  uri : String
  diagnostics : Array[@compile.CompileDiagnostic]
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
  let inputs = self.analysis_inputs(document)
  let analysis = @compile.analyze_source_inputs(
    inputs[0],
    inputs[1:].to_owned(),
  )
  diagnostic_publications(
    inputs,
    analysis.diagnostics,
    fallback_uri=document.uri,
  )
}

///|
async fn LspWorkspaceAnalysis::analyze(
  self : LspWorkspaceAnalysis,
  document : DocumentSnapshot,
) -> @compile.AnalysisResult {
  let inputs = self.analysis_inputs(document)
  @compile.analyze_source_inputs(inputs[0], inputs[1:].to_owned())
}

///|
async fn LspWorkspaceAnalysis::analysis_inputs(
  self : LspWorkspaceAnalysis,
  document : DocumentSnapshot,
) -> Array[@compile.SourceInput] {
  let root_input : @compile.SourceInput = {
    source_id: document.uri,
    text: document.text,
  }
  match self.workspace_root {
    Some(root) => {
      let libraries = self
        .workspace_sources(root)
        .without_source_id(document.uri)
      match @compile.import_reachable_source_inputs(root_input, libraries) {
        Ok(inputs) => inputs
        Err(_) => [root_input]
      }
    }
    None => [root_input]
  }
}

///|
async fn LspWorkspaceAnalysis::workspace_sources(
  self : LspWorkspaceAnalysis,
  root : String,
) -> Array[@compile.SourceInput] {
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
) -> Array[@compile.SourceInput] {
  let sources : Array[@compile.SourceInput] = []
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
  self : Array[@compile.SourceInput],
  source_id : String,
) -> Array[@compile.SourceInput] {
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
  sources : Array[@compile.SourceInput],
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
