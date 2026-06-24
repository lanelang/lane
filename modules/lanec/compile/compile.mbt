///|
using @prettyprinter {type Document, line, separate, space, text}

///|
pub(all) struct CompileDiagnostic {
  message : String
  span : @basic.SourceSpan?
  severity : CompileDiagnosticSeverity
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticSeverity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub(all) struct CheckResult {
  source : @checked.CheckedSourceFile?
  diagnostics : Array[CompileDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct CompileResult {
  program : @buslane.Program?
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  diagnostics : Array[CompileDiagnostic]
} derive(Debug, Eq)

///|
priv struct ParsedModuleInput {
  path : String
  source : @syntax.SourceFile
}

///|
/// Checks one Lane source module.
pub fn check_source(source : String) -> CheckResult {
  check_sources(source, [])
}

///|
/// Checks a root Lane source module against explicitly supplied library modules.
pub fn check_sources(
  root_source : String,
  library_sources : Array[String],
) -> CheckResult {
  match checked_source_from_inputs(root_source, library_sources) {
    Ok(source) => { source: Some(source), diagnostics: [] }
    Err(diagnostics) => { source: None, diagnostics }
  }
}

///|
/// Compiles one Lane source module into Buslane plus compiler-owned side tables
/// needed by tools and runtimes.
pub fn compile_source(source : String) -> CompileResult {
  compile_sources(source, [])
}

///|
/// Compiles a root Lane source module against explicitly supplied library
/// modules.
pub fn compile_sources(
  root_source : String,
  library_sources : Array[String],
) -> CompileResult {
  match checked_source_from_inputs(root_source, library_sources) {
    Ok(source) => {
      let lowered = @elaborate.lower_checked_source_file_to_buslane_result(
        source,
      )
      {
        program: Some(lowered.program),
        externals: lowered.externals,
        entries: lowered.entries,
        diagnostics: [],
      }
    }
    Err(diagnostics) =>
      { program: None, externals: { builtins: [] }, entries: [], diagnostics }
  }
}

///|
fn checked_source_from_inputs(
  root_source : String,
  library_sources : Array[String],
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let parsed = parse_module_inputs(root_source, library_sources)
  if !parsed.diagnostics.is_empty() {
    return Err(parsed.diagnostics)
  }
  guard parsed.modules.get(0) is Some(root) else {
    return Err([make_error("no root source module", span=None)])
  }
  let graph_diagnostics = validate_module_inputs(parsed.modules)
  if !graph_diagnostics.is_empty() {
    return Err(graph_diagnostics)
  }
  let reachable = reachable_modules(parsed.modules, root.path)
  if !reachable.diagnostics.is_empty() {
    return Err(reachable.diagnostics)
  }
  let source = combined_reachable_source(reachable.modules, root.path)
  checked_source(source)
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
fn validate_module_inputs(
  modules : Array[ParsedModuleInput],
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for index in 0..<modules.length() {
    for other_index in (index + 1)..<modules.length() {
      if modules[index].path == modules[other_index].path {
        diagnostics.push(
          make_error(
            "duplicate module input " + modules[index].path,
            span=Some(modules[other_index].source.module_path.loc),
          ),
        )
      }
    }
  }
  for module_ in modules {
    for import_ in module_import_paths(module_.source) {
      if find_module(modules, import_.path) is None {
        diagnostics.push(
          make_error("missing import " + import_.path, span=Some(import_.loc)),
        )
      }
    }
  }
  diagnostics
}

///|
priv struct ImportPath {
  path : String
  loc : @basic.SourceSpan
}

///|
fn module_import_paths(source : @syntax.SourceFile) -> Array[ImportPath] {
  source.imports.map(fn(import_) {
    let path = match import_ {
      Qualified(module_path~, ..)
      | Open(module_path~, ..)
      | Selective(module_path~, ..) => module_path
    }
    { path: module_path_text(path), loc: import_.loc() }
  })
}

///|
priv struct ReachableModulesResult {
  modules : Array[ParsedModuleInput]
  diagnostics : Array[CompileDiagnostic]
}

///|
fn reachable_modules(
  modules : Array[ParsedModuleInput],
  root_path : String,
) -> ReachableModulesResult {
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  let diagnostics = []
  visit_module(modules, root_path, visiting, visited, ordered, diagnostics)
  { modules: ordered, diagnostics }
}

///|
fn visit_module(
  modules : Array[ParsedModuleInput],
  path : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[ParsedModuleInput],
  diagnostics : Array[CompileDiagnostic],
) -> Unit {
  if visited.contains(path) {
    return
  }
  if visiting.contains(path) {
    diagnostics.push(make_error("import cycle " + path, span=None))
    return
  }
  guard find_module(modules, path) is Some(module_) else {
    diagnostics.push(make_error("missing import " + path, span=None))
    return
  }
  visiting.push(path)
  for import_ in module_import_paths(module_.source) {
    visit_module(modules, import_.path, visiting, visited, ordered, diagnostics)
  }
  ignore(visiting.pop())
  visited.push(path)
  ordered.push(module_)
}

///|
fn find_module(
  modules : Array[ParsedModuleInput],
  path : String,
) -> ParsedModuleInput? {
  for module_ in modules {
    if module_.path == path {
      return Some(module_)
    }
  }
  None
}

///|
fn combined_reachable_source(
  modules : Array[ParsedModuleInput],
  root_path : String,
) -> @syntax.SourceFile {
  let declarations = []
  guard modules.last() is Some(root) else {
    return @syntax.SourceFile::{
      module_path: @syntax.ModulePath::{
        components: ["<empty>"],
        loc: @basic.SourceSpan::dummy(),
      },
      imports: [],
      declarations,
      loc: @basic.SourceSpan::dummy(),
    }
  }
  for module_ in modules {
    let keep_public = module_.path == root_path
    for declaration in module_.source.declarations {
      declarations.push(declaration_with_public(declaration, keep_public))
    }
  }
  {
    module_path: root.source.module_path,
    imports: [],
    declarations,
    loc: root.source.loc,
  }
}

///|
fn declaration_with_public(
  declaration : @syntax.TopLevelDeclaration,
  keep_public : Bool,
) -> @syntax.TopLevelDeclaration {
  match declaration {
    Struct(declaration) =>
      Struct({ ..declaration, is_public: keep_public && declaration.is_public })
    Enum(declaration) =>
      Enum({ ..declaration, is_public: keep_public && declaration.is_public })
    TypeAlias(declaration) =>
      TypeAlias({
        ..declaration,
        is_public: keep_public && declaration.is_public,
      })
    Function(declaration) =>
      Function({
        ..declaration,
        is_public: keep_public && declaration.is_public,
      })
    Let(declaration) =>
      Let({ ..declaration, is_public: keep_public && declaration.is_public })
    Offer(declaration) =>
      Offer({ ..declaration, is_public: keep_public && declaration.is_public })
  }
}

///|
fn module_path_text(path : @syntax.ModulePath) -> String {
  path.components.join(".")
}

///|
fn checked_source(
  source : @syntax.SourceFile,
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let resolved = @resolve.resolve_source_file_result(source)
  checked_resolved_source(resolved)
}

///|
fn checked_resolved_source(
  resolved : @resolve.ResolveResult,
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    make_error(
      @prettyprinter.render(diagnostic.kind, width=100),
      span=Some(diagnostic.loc),
    )
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  let checked = @typecheck.typecheck_checked_source_file(resolved.source)
  let typecheck_diagnostics = checked.diagnostics.map(fn(diagnostic) {
    make_error(
      @prettyprinter.render(diagnostic.kind, width=100),
      span=Some(diagnostic.loc),
    )
  })
  if !typecheck_diagnostics.is_empty() {
    return Err(typecheck_diagnostics)
  }
  match checked.source {
    Some(source) => Ok(source)
    None => Err([make_error("checked source construction failed", span=None)])
  }
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for error in result.lexical_errors {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors {
    diagnostics.push(parse_diagnostic(error))
  }
  diagnostics
}

///|
fn lex_diagnostic(error : @lexer.LexError) -> CompileDiagnostic {
  make_error(
    "lexical error: " + lex_error_text(error.error),
    span=Some(error.span),
  )
}

///|
fn lex_error_text(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(value) => "illegal character " + value
    UnterminatedBlockComment => "unterminated block comment"
    UnterminatedString => "unterminated string"
    InvalidStringEscape(value) => "invalid string escape " + value
    InvalidHexEscape(value) => "invalid hex escape " + value
    NonAsciiStringCharacter => "non-ascii string character"
  }
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompileDiagnostic {
  make_error(
    "parse error: " + parse_error_text(error.kind),
    span=Some(error.loc),
  )
}

///|
fn parse_error_text(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(token, expected) =>
      "unexpected " + token.label + expected_text(expected)
    UnexpectedEndOfInput(expected) =>
      "unexpected end of input" + expected_text(expected)
  }
}

///|
fn expected_text(expected : Array[@parser.ExpectedSyntax]) -> String {
  if expected.is_empty() {
    ""
  } else {
    let labels = expected.map(fn(item) { item.label })
    ", expected " + labels.join(", ")
  }
}

///|
fn span_text(span : @basic.SourceSpan) -> String {
  span.start_line.to_string() +
  ":" +
  span.start_column.to_string() +
  "-" +
  span.end_line.to_string() +
  ":" +
  span.end_column.to_string()
}

///|
fn make_error(
  message : String,
  span~ : @basic.SourceSpan?,
) -> CompileDiagnostic {
  { message, span, severity: Error }
}

///|
pub impl @prettyprinter.Pretty for CompileDiagnostic with fn pretty(
  diagnostic : CompileDiagnostic,
) -> Document {
  let message = text(diagnostic.message)
  match diagnostic.span {
    Some(span) => text(span_text(span)) + text(":") + space + message
    None => message
  }
}

///|
pub impl @prettyprinter.Pretty for CheckResult with fn pretty(
  result : CheckResult,
) -> Document {
  diagnostics_doc(result.diagnostics)
}

///|
pub impl @prettyprinter.Pretty for CompileResult with fn pretty(
  result : CompileResult,
) -> Document {
  diagnostics_doc(result.diagnostics)
}

///|
fn diagnostics_doc(diagnostics : Array[CompileDiagnostic]) -> Document {
  if diagnostics.is_empty() {
    text("diagnostics") + space + text("{}")
  } else {
    text("diagnostics") +
    space +
    separate(line, diagnostics.map(CompileDiagnostic::pretty))
  }
}
