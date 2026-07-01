///|
priv struct ParsedModuleInput {
  source_id : String
  text : String
  header : ModuleHeader
  source : @syntax.SourceFile
}

///|
priv struct ModuleInputSet {
  root_module_path_text : String
  modules : Array[ParsedModuleInput]
}

///|
priv struct ModuleHeader {
  module_path_text : String
  module_span : @basic.SourceSpan
  imports : Array[ImportHeader]
}

///|
priv struct ImportHeader {
  module_path_text : String
  import_span : @basic.SourceSpan
}

///|
pub(all) struct SourceInput {
  source_id : String
  text : String
} derive(Debug, Eq)

///|
fn parse_module_input_set(
  root_source : String,
  library_sources : Array[String],
) -> Result[ModuleInputSet, Array[CompileDiagnostic]] {
  let library_inputs = []
  for index, source in library_sources {
    library_inputs.push({ source_id: "<library:\{index}>", text: source })
  }
  parse_module_input_set_from_inputs(
    { source_id: "<root>", text: root_source },
    library_inputs,
  )
}

///|
fn parse_module_input_set_from_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> Result[ModuleInputSet, Array[CompileDiagnostic]] {
  let parsed = parse_module_inputs(root_source, library_sources)
  if !parsed.diagnostics.is_empty() {
    return Err(parsed.diagnostics)
  }
  guard parsed.modules.get(0) is Some(root) else {
    return Err([CompileErrorKind::to_diagnostic(NoRootSourceModule, None)])
  }
  Ok({
    root_module_path_text: root.header.module_path_text,
    modules: parsed.modules,
  })
}

///|
pub fn import_reachable_source_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> Result[Array[SourceInput], Array[CompileDiagnostic]] {
  let parsed = parse_module_inputs(root_source, library_sources)
  let root_diagnostics = parsed.diagnostics.filter(fn(diagnostic) {
    diagnostic.source_id == Some(root_source.source_id)
  })
  if !root_diagnostics.is_empty() {
    return Err(root_diagnostics)
  }
  guard parsed.modules.get(0) is Some(root) else {
    return Err([CompileErrorKind::to_diagnostic(NoRootSourceModule, None)])
  }
  let reachable = reachable_modules(
    parsed.modules,
    root.header.module_path_text,
  )
  let inputs = [{ source_id: root.source_id, text: root.text }]
  for module_ in reachable.modules {
    if module_.source_id != root.source_id {
      inputs.push({ source_id: module_.source_id, text: module_.text })
    }
  }
  Ok(inputs)
}

///|
priv struct ParseModuleInputsResult {
  modules : Array[ParsedModuleInput]
  diagnostics : Array[CompileDiagnostic]
}

///|
fn parse_module_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> ParseModuleInputsResult {
  let modules = []
  let diagnostics = []
  let sources = [root_source] + library_sources
  for source in sources {
    let parsed = @parser.parse_string(source.text)
    let source_diagnostics = parse_diagnostics(parsed)
    if source_diagnostics.is_empty() {
      match parsed.source {
        Some(file) =>
          modules.push({
            source_id: source.source_id,
            text: source.text,
            header: module_header(file),
            source: file,
          })
        None => {
          let diagnostic = CompileErrorKind::to_diagnostic(
            ParserProducedNoSourceFile,
            None,
          ).with_source_id(source.source_id)
          diagnostics.push(diagnostic)
        }
      }
    } else {
      diagnostics.append(
        source_diagnostics.map(fn(diagnostic) {
          diagnostic.with_source_id(source.source_id)
        }),
      )
    }
  }
  { modules, diagnostics }
}

///|
fn module_header(source : @syntax.SourceFile) -> ModuleHeader {
  {
    module_path_text: module_path_text(source.module_path),
    module_span: source.module_path.loc,
    imports: source.imports.map(import_header),
  }
}

///|
fn import_header(import_ : @syntax.ImportDeclaration) -> ImportHeader {
  match import_ {
    Qualified(module_path~, loc~) =>
      { module_path_text: module_path_text(module_path), import_span: loc }
    Open(module_path~, loc~) =>
      { module_path_text: module_path_text(module_path), import_span: loc }
    Selective(module_path~, loc~, ..) =>
      { module_path_text: module_path_text(module_path), import_span: loc }
  }
}

///|
fn module_path_text(path : @syntax.ModulePath) -> String {
  path.components.join(".")
}
