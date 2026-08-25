///|
pub(all) struct ParsedModuleInput {
  source_id : String
  text : String
  concrete : @lexer.ConcreteSyntax
  identifiers : @syntax.SyntacticIdentifierIndex
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  header : ModuleHeader
  source : @syntax.SourceFile
}

///|
pub(all) struct UnavailableParsedSource {
  source_id : String
  text : String
  concrete : @lexer.ConcreteSyntax
  identifiers : @syntax.SyntacticIdentifierIndex
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  recovered_header : ModuleInputHeader?
}

///|
pub(all) enum ParsedSource {
  Available(ParsedModuleInput)
  Unavailable(UnavailableParsedSource)
}

///|
pub(all) struct ParseModuleInputsResult {
  sources : Array[ParsedSource]
}

///|
pub(all) struct ModuleHeader {
  module_path_text : String
  module_span : @basic.SourceSpan
  imports : Array[ImportHeader]
}

///|
pub(all) struct ImportHeader {
  module_path_text : String
  import_span : @basic.SourceSpan
}

///|
pub(all) struct ModuleInputHeader {
  source_id : String
  module_path_text : String
  imports : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct SourceInput {
  source_id : String
  text : String
} derive(Debug, Eq)

///|
pub fn parse_import_reachable_module_graph_from_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> Result[ModuleGraph, Array[@compiler_diag.CompilerDiagnostic]] {
  parse_import_reachable_module_graph_from_inputs_observed(
    root_source,
    library_sources,
    _ => (),
  )
}

///|
pub fn parse_import_reachable_module_graph_from_inputs_observed(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
  observe_root : (ParsedModuleInput) -> Unit,
) -> Result[ModuleGraph, Array[@compiler_diag.CompilerDiagnostic]] {
  let parsed = parse_module_inputs(root_source, library_sources)
  match parsed.sources[0] {
    Unavailable(root) => Err(root.diagnostics)
    Available(root) => {
      observe_root(root)
      build_strict_module_graph(parsed.sources, root.header.module_path_text)
    }
  }
}

///|
pub fn import_reachable_source_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> Result[Array[SourceInput], Array[@compiler_diag.CompilerDiagnostic]] {
  match
    parse_import_reachable_module_graph_from_inputs(
      root_source, library_sources,
    ) {
    Err(diagnostics) => Err(diagnostics)
    Ok(graph) => {
      let inputs = [root_source]
      for module_ in graph.modules() {
        if module_.source_id != root_source.source_id {
          inputs.push({ source_id: module_.source_id, text: module_.text, })
        }
      }
      Ok(inputs)
    }
  }
}

///|
pub fn parse_module_inputs(
  root_source : SourceInput,
  library_sources : Array[SourceInput],
) -> ParseModuleInputsResult {
  { sources: [parse_source(root_source)] + library_sources.map(parse_source), }
}

///|
pub fn parse_source(source : SourceInput) -> ParsedSource {
  let parsed = @parser.parse_string(source.text)
  let identifiers = parsed.syntactic_identifier_index()
  let concrete = match parsed {
    Parsed({ concrete, .. }) => concrete
    Failed(Grammar(concrete, _, _)) => concrete
    Failed(Lexical(concrete, _)) => concrete
  }
  let diagnostics = parse_diagnostics(parsed).map(fn(diagnostic) {
    diagnostic.with_source_id(source.source_id)
  })
  match parsed {
    Parsed({ syntax: file, concrete, .. }) =>
      Available({
        source_id: source.source_id,
        text: source.text,
        concrete,
        identifiers,
        diagnostics,
        header: module_header(file),
        source: file,
      })
    Failed(_) => {
      if diagnostics.is_empty() {
        diagnostics.push(
          parser_produced_no_source_file_diagnostic().with_source_id(
            source.source_id,
          ),
        )
      }
      Unavailable({
        source_id: source.source_id,
        text: source.text,
        concrete,
        identifiers,
        diagnostics,
        recovered_header: source_module_header(source),
      })
    }
  }
}

///|
pub fn ParsedSource::source_input(self : ParsedSource) -> SourceInput {
  match self {
    Available(source) => { source_id: source.source_id, text: source.text, }
    Unavailable(source) => { source_id: source.source_id, text: source.text, }
  }
}

///|
pub fn ParsedSource::source_id(self : ParsedSource) -> String {
  match self {
    Available(source) => source.source_id
    Unavailable(source) => source.source_id
  }
}

///|
pub fn ParsedSource::text(self : ParsedSource) -> String {
  match self {
    Available(source) => source.text
    Unavailable(source) => source.text
  }
}

///|
pub fn ParsedSource::concrete(self : ParsedSource) -> @lexer.ConcreteSyntax {
  match self {
    Available(source) => source.concrete
    Unavailable(source) => source.concrete
  }
}

///|
pub fn ParsedSource::identifiers(
  self : ParsedSource,
) -> @syntax.SyntacticIdentifierIndex {
  match self {
    Available(source) => source.identifiers
    Unavailable(source) => source.identifiers
  }
}

///|
pub fn ParsedSource::diagnostics(
  self : ParsedSource,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  match self {
    Available(source) => source.diagnostics
    Unavailable(source) => source.diagnostics
  }
}

///|
pub fn ParsedSource::available_module(
  self : ParsedSource,
) -> ParsedModuleInput? {
  match self {
    Available(module_) => Some(module_)
    Unavailable(_) => None
  }
}

///|
pub fn ParsedSource::module_header(self : ParsedSource) -> ModuleInputHeader? {
  match self {
    Available(module_) =>
      Some({
        source_id: module_.source_id,
        module_path_text: module_.header.module_path_text,
        imports: module_.header.imports.map(fn(import_) {
          import_.module_path_text
        }),
      })
    Unavailable(source) => source.recovered_header
  }
}

///|
pub fn ParsedSource::module_path_text(self : ParsedSource) -> String? {
  self.module_header().map(fn(header) { header.module_path_text })
}

///|
fn module_header(source : @syntax.SourceFile) -> ModuleHeader {
  let imports = source.imports.map(import_header)
  let current_module_path = module_path_text(source.module_path)
  if source.first_derive_loc() is Some(import_span) {
    for
      dependency in ["Basic.Trait.Derive", "Basic.Trait.Iso", "Basic.Data.Void"] {
      if current_module_path != dependency &&
        !imports.any(fn(import_) { import_.module_path_text == dependency }) {
        imports.push({ module_path_text: dependency, import_span, })
      }
    }
  }
  {
    module_path_text: current_module_path,
    module_span: source.module_path.loc,
    imports,
  }
}

///|
fn import_header(import_ : @syntax.ImportDeclaration) -> ImportHeader {
  match import_ {
    Qualified(module_path~, ..)
    | Open(module_path~, ..)
    | Selective(module_path~, ..) =>
      {
        module_path_text: module_path_text(module_path),
        import_span: module_path.loc,
      }
  }
}

///|
fn module_path_text(path : @syntax.ModulePath) -> String {
  path.components.join(".")
}

///|
fn source_module_header(source : SourceInput) -> ModuleInputHeader? {
  let tokens = @lexer.tokens_from_string(source.text).concrete.tokens
  guard tokens.get(0) is Some((MODULE, _)) else { return None }
  let components = []
  let mut index = 1
  let mut expect_identifier = true
  while index < tokens.length() {
    let token = tokens[index].0
    if expect_identifier {
      guard token is IDENT(name) else { break }
      components.push(name)
      expect_identifier = false
    } else {
      guard token is DOT else { break }
      expect_identifier = true
    }
    index += 1
  }
  guard !components.is_empty() && !expect_identifier else { return None }
  Some({
    source_id: source.source_id,
    module_path_text: components.join("."),
    imports: [],
  })
}
