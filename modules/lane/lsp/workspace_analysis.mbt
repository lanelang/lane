///|
priv struct LspWorkspaceAnalysis {
  workspace_root : String?
  documents : Map[String, DocumentSnapshot]
}

///|
priv struct LspAnalysisSources {
  root : @module_frontend.SourceInput
  libraries : Array[@module_frontend.SourceInput]
  scan_issues : Array[WorkspaceScanIssue]
}

///|
priv struct WorkspaceInitialization {
  publications : Array[DiagnosticPublication]
  scan_issues : Array[WorkspaceScanIssue]
}

///|
priv enum WorkspaceScanOperation {
  ReadDirectory
  InspectEntry
  ReadSource
}

///|
priv struct WorkspaceScanIssue {
  operation : WorkspaceScanOperation
  path : String
}

///|
priv struct WorkspaceScanResult {
  sources : Array[@module_frontend.SourceInput]
  issues : Array[WorkspaceScanIssue]
}

///|
priv suberror WorkspaceScanError {
  WorkspaceRootReadFailed(path~ : String)
}

///|
fn LspWorkspaceAnalysis::LspWorkspaceAnalysis(
  workspace_root : String?,
  documents : Map[String, DocumentSnapshot],
) -> LspWorkspaceAnalysis {
  { workspace_root, documents }
}

///|
async fn LspWorkspaceAnalysis::initialize_workspace(
  self : LspWorkspaceAnalysis,
  workspace : @analysis.SemanticWorkspace,
  document : DocumentSnapshot,
) -> WorkspaceInitialization {
  let sources = self.analysis_sources(document)
  ignore(workspace.replace_sources(sources.all_inputs()))
  {
    publications: self.workspace_diagnostics(workspace, document.uri),
    scan_issues: sources.scan_issues,
  }
}

///|
fn LspWorkspaceAnalysis::update_document(
  self : LspWorkspaceAnalysis,
  workspace : @analysis.SemanticWorkspace,
  document : DocumentSnapshot,
) -> Array[DiagnosticPublication] {
  let previous_revision = workspace.revision()
  guard workspace.upsert_source({ source_id: document.uri, text: document.text })
    is Some(snapshot) else {
    return []
  }
  if workspace.revision() == previous_revision {
    return []
  }
  self.incremental_workspace_diagnostics(snapshot, document.uri)
}

///|
fn LspWorkspaceAnalysis::incremental_workspace_diagnostics(
  _self : LspWorkspaceAnalysis,
  snapshot : @analysis.SemanticSnapshot,
  fallback_uri : String,
) -> Array[DiagnosticPublication] {
  let inputs = []
  let diagnostics = []
  for entry in snapshot.diagnostic_delta() {
    let (source, source_diagnostics) = entry
    inputs.push(source)
    diagnostics.append(source_diagnostics)
  }
  inputs.sort_by(fn(left, right) {
    if left.source_id == fallback_uri {
      -1
    } else if right.source_id == fallback_uri {
      1
    } else {
      String::compare(left.source_id, right.source_id)
    }
  })
  diagnostic_publications(inputs, diagnostics, fallback_uri~)
}

///|
fn LspWorkspaceAnalysis::workspace_diagnostics(
  _self : LspWorkspaceAnalysis,
  workspace : @analysis.SemanticWorkspace,
  fallback_uri : String,
) -> Array[DiagnosticPublication] {
  let diagnostics = match workspace.snapshot() {
    Some(snapshot) => snapshot.diagnostics()
    None => []
  }
  let sources = workspace.sources()
  let ordered = sources.filter(fn(source) { source.source_id == fallback_uri })
  ordered.append(
    sources.filter(fn(source) { source.source_id != fallback_uri }),
  )
  diagnostic_publications(ordered, diagnostics, fallback_uri~)
}

///|
fn LspAnalysisSources::all_inputs(
  self : LspAnalysisSources,
) -> Array[@module_frontend.SourceInput] {
  [self.root] + self.libraries
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
      let libraries = self.workspace_sources(root)
      {
        root: root_input,
        libraries: libraries.sources.without_source_id(document.uri),
        scan_issues: libraries.issues,
      }
    }
    None => { root: root_input, libraries: [], scan_issues: [] }
  }
}

///|
async fn LspWorkspaceAnalysis::workspace_sources(
  self : LspWorkspaceAnalysis,
  root : String,
) -> WorkspaceScanResult {
  let library_identities : @hashset.HashSet[String] = @hashset.HashSet([])
  let sources = self.open_document_library_sources(root, library_identities)
  let issues = []
  append_lane_sources(
    root,
    library_identities,
    sources,
    issues,
    is_workspace_root=true,
  )
  sources.sort_by(fn(left, right) {
    String::compare(left.source_id, right.source_id)
  })
  { sources, issues }
}

///|
async fn LspWorkspaceAnalysis::open_document_library_sources(
  self : LspWorkspaceAnalysis,
  root : String,
  library_identities : @hashset.HashSet[String],
) -> Array[@module_frontend.SourceInput] {
  let sources : Array[@module_frontend.SourceInput] = []
  for _, document in self.documents {
    guard file_uri_to_path(document.uri) is Some(path) else { continue }
    let identity = lsp_source_identity(path)
    if path.has_suffix(".lane") &&
      path_is_under_workspace(path, root) &&
      library_identities.add_and_check(identity) {
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
  library_identities : @hashset.HashSet[String],
  sources : Array[@module_frontend.SourceInput],
  issues : Array[WorkspaceScanIssue],
  is_workspace_root~ : Bool,
) -> Unit {
  let entries = @fs.readdir(path, sort=true) catch {
    _ =>
      if is_workspace_root {
        raise WorkspaceRootReadFailed(path~)
      } else {
        issues.push({ operation: ReadDirectory, path })
        return
      }
  }
  for entry in entries {
    if should_skip_workspace_entry(entry) {
      continue
    }
    let child = "\{path}/\{entry}"
    let kind = @fs.kind(child) catch {
      _ => {
        issues.push({ operation: InspectEntry, path: child })
        continue
      }
    }
    match kind {
      Directory =>
        append_lane_sources(
          child,
          library_identities,
          sources,
          issues,
          is_workspace_root=false,
        )
      Regular if child.has_suffix(".lane") => {
        let identity = lsp_source_identity(child)
        if library_identities.contains(identity) {
          continue
        }
        let text = @fs.read_file(child).text() catch {
          _ => {
            issues.push({ operation: ReadSource, path: child })
            continue
          }
        }
        if library_identities.add_and_check(identity) {
          sources.push({ source_id: path_to_file_uri(child), text })
        }
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
