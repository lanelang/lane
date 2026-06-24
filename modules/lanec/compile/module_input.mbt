///|
priv struct ParsedModuleInput {
  path : String
  source : @syntax.SourceFile
}

///|
priv struct ModuleInputSet {
  root_path : String
  modules : Array[ParsedModuleInput]
}

///|
fn parse_module_input_set(
  root_source : String,
  library_sources : Array[String],
) -> Result[ModuleInputSet, Array[CompileDiagnostic]] {
  let parsed = parse_module_inputs(root_source, library_sources)
  if !parsed.diagnostics.is_empty() {
    return Err(parsed.diagnostics)
  }
  guard parsed.modules.get(0) is Some(root) else {
    return Err([make_error("no root source module", span=None)])
  }
  Ok({ root_path: root.path, modules: parsed.modules })
}

///|
priv struct ParseModuleInputsResult {
  modules : Array[ParsedModuleInput]
  diagnostics : Array[CompileDiagnostic]
}

///|
fn parse_module_inputs(
  root_source : String,
  library_sources : Array[String],
) -> ParseModuleInputsResult {
  let modules = []
  let diagnostics = []
  let sources = [root_source] + library_sources
  for source in sources {
    let parsed = @parser.parse_string(source)
    let source_diagnostics = parse_diagnostics(parsed)
    if source_diagnostics.is_empty() {
      match parsed.source {
        Some(file) =>
          modules.push({
            path: module_path_text(file.module_path),
            source: file,
          })
        None =>
          diagnostics.push(
            make_error("parser produced no source file", span=None),
          )
      }
    } else {
      diagnostics.append(source_diagnostics)
    }
  }
  { modules, diagnostics }
}

///|
fn module_path_text(path : @syntax.ModulePath) -> String {
  path.components.join(".")
}
