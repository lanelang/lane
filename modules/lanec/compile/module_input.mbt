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
priv struct ModuleInputHeader {
  source_id : String
  module_path_text : String
  imports : Array[String]
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
fn parse_import_reachable_module_input_set_from_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> Result[ModuleInputSet, Array[CompileDiagnostic]] {
  let parsed = parse_module_inputs(root_source, library_sources)
  let root_diagnostics = parsed.diagnostics_for_source(root_source.source_id)
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
  let reachable_headers = reachable_input_headers(
    parsed.headers,
    root.header.module_path_text,
  )
  let reachable_module_path_texts = reachable.modules.map(fn(module_) {
    module_.header.module_path_text
  })
  for header in reachable_headers {
    if !reachable_module_path_texts.contains(header.module_path_text) {
      reachable_module_path_texts.push(header.module_path_text)
    }
  }
  let modules = parsed.modules.filter(fn(module_) {
    reachable_module_path_texts.contains(module_.header.module_path_text)
  })
  let reachable_source_ids = reachable_headers.map(fn(header) {
    header.source_id
  })
  let diagnostics = parsed
    .source_diagnostics()
    .filter(fn(diagnostic) {
      match diagnostic.source_id {
        Some(source_id) => reachable_source_ids.contains(source_id)
        None => false
      }
    })
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  let inputs = { root_module_path_text: root.header.module_path_text, modules }
  match build_module_graph(inputs) {
    Err(diagnostics) => Err(diagnostics)
    Ok(_) => Ok(inputs)
  }
}

///|
pub fn import_reachable_source_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> Result[Array[SourceInput], Array[CompileDiagnostic]] {
  match
    parse_import_reachable_module_input_set_from_inputs(
      root_source, library_sources,
    ) {
    Err(diagnostics) => Err(diagnostics)
    Ok(input_set) => {
      let reachable = reachable_modules(
        input_set.modules,
        input_set.root_module_path_text,
      )
      let inputs = [
        { source_id: root_source.source_id, text: root_source.text },
      ]
      for module_ in reachable.modules {
        if module_.source_id == root_source.source_id {
          continue
        }
        inputs.push({ source_id: module_.source_id, text: module_.text })
      }
      Ok(inputs)
    }
  }
}

///|
priv struct ParseModuleInputsResult {
  modules : Array[ParsedModuleInput]
  headers : Array[ModuleInputHeader]
  diagnostics : Array[CompileDiagnostic]
}

///|
fn ParseModuleInputsResult::diagnostics_for_source(
  self : ParseModuleInputsResult,
  source_id : String,
) -> Array[CompileDiagnostic] {
  self.diagnostics.filter(fn(diagnostic) {
    diagnostic.source_id == Some(source_id)
  })
}

///|
fn ParseModuleInputsResult::source_diagnostics(
  self : ParseModuleInputsResult,
) -> Array[CompileDiagnostic] {
  self.diagnostics.filter(fn(diagnostic) { diagnostic.source_id is Some(_) })
}

///|
fn parse_module_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> ParseModuleInputsResult {
  let modules = []
  let headers = []
  let diagnostics = []
  let sources = [root_source] + library_sources
  for source in sources {
    let parsed = @parser.parse_string(source.text)
    let source_diagnostics = parse_diagnostics(parsed).map(fn(diagnostic) {
      diagnostic.with_source_id(source.source_id)
    })
    diagnostics.append(source_diagnostics)
    match parsed.source {
      Some(file) => {
        let header = module_header(file)
        headers.push({
          source_id: source.source_id,
          module_path_text: header.module_path_text,
          imports: header.imports.map(fn(import_) { import_.module_path_text }),
        })
        modules.push({
          source_id: source.source_id,
          text: source.text,
          header,
          source: file,
        })
      }
      None if source_diagnostics.is_empty() => {
        let diagnostic = CompileErrorKind::to_diagnostic(
          ParserProducedNoSourceFile,
          None,
        ).with_source_id(source.source_id)
        diagnostics.push(diagnostic)
      }
      None =>
        match source_module_header(source) {
          Some(header) => headers.push(header)
          None => ()
        }
    }
  }
  { modules, headers, diagnostics }
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

///|
fn source_module_header(source : SourceInput) -> ModuleInputHeader? {
  for line_view in source.text.split("\n") {
    let line = line_view.trim()
    if line.is_empty() {
      continue
    }
    match line.split_once(" ") {
      Some((keyword, rest)) if keyword == "module" =>
        return Some({
          source_id: source.source_id,
          module_path_text: rest.trim().to_owned(),
          imports: [],
        })
      _ => return None
    }
  }
  None
}

///|
fn reachable_input_headers(
  headers : Array[ModuleInputHeader],
  root_module_path_text : String,
) -> Array[ModuleInputHeader] {
  let reachable = []
  let visiting : Array[String] = []
  visit_input_header(headers, root_module_path_text, visiting, reachable)
  reachable
}

///|
fn visit_input_header(
  headers : Array[ModuleInputHeader],
  path : String,
  visiting : Array[String],
  reachable : Array[ModuleInputHeader],
) -> Unit {
  if visiting.contains(path) {
    return
  }
  guard find_input_header(headers, path) is Some(header) else { return }
  reachable.push(header)
  visiting.push(path)
  for import_ in header.imports {
    visit_input_header(headers, import_, visiting, reachable)
  }
  ignore(visiting.pop())
}

///|
fn find_input_header(
  headers : Array[ModuleInputHeader],
  path : String,
) -> ModuleInputHeader? {
  for header in headers {
    if header.module_path_text == path {
      return Some(header)
    }
  }
  None
}
