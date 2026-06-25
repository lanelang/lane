///|
priv struct ParsedModuleInput {
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
  Ok({
    root_module_path_text: root.header.module_path_text,
    modules: parsed.modules,
  })
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
          modules.push({ header: module_header(file), source: file })
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
