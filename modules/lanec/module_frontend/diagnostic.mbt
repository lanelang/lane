///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticFact,
  type CompilerDiagnosticLabel,
  type CompilerDiagnosticSeverity,
  type CompilerDiagnosticSuggestion,
  compiler_diagnostic,
  compiler_local_span,
  compiler_primary_labels,
}

///|
priv enum ModuleFrontendDiagnosticKind {
  NoRootSourceModule
  DuplicateModuleInput(String)
  MissingImportWithCandidates(
    module_~ : String,
    source_modules~ : Array[String],
    interface_modules~ : Array[String]
  )
  ImportCycle(String)
  ParserProducedNoSourceFile
}

///|
priv struct ModuleFrontendDiagnostic {
  kind : ModuleFrontendDiagnosticKind
  span : @basic.SourceSpan?
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompilerDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity~,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
  )
}

///|
fn primary_label(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompilerDiagnosticLabel] {
  compiler_primary_labels(span, message)
}

///|
fn module_frontend_diagnostic(
  kind : ModuleFrontendDiagnosticKind,
  span : @basic.SourceSpan?,
) -> CompilerDiagnostic {
  let diagnostic : ModuleFrontendDiagnostic = { kind, span }
  diagnostic.to_compiler_diagnostic(DiagnosticContext())
}

///|
impl @compiler_diag.ToCompilerDiagnostic for ModuleFrontendDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : ModuleFrontendDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    NoRootSourceModule =>
      module_frontend_report(
        "no root source module",
        diagnostic_.span,
        code="E4000",
        label="the compiler did not receive a root Lane module",
        note="Lane compile/check needs exactly one root source module",
        help="pass a source file that starts with a `module` declaration",
      )
    DuplicateModuleInput(module_) =>
      module_frontend_report(
        "duplicate module input `\{module_}`",
        diagnostic_.span,
        code="E4001",
        label="this module was supplied more than once",
        note="a module input set cannot contain two sources with the same module name",
        help="remove one source file or rename one of the modules",
      )
    MissingImportWithCandidates(module_~, source_modules~, interface_modules~) =>
      missing_import_diagnostic(
        module_,
        diagnostic_.span,
        source_modules,
        interface_modules,
      )
    ImportCycle(module_) =>
      module_frontend_report(
        "import cycle involving `\{module_}`",
        diagnostic_.span,
        code="E4003",
        label="module imports must form an acyclic graph",
        note="cyclic module dependencies cannot be typechecked in a stable order",
        help="move shared declarations into a separate module imported by both sides",
      )
    ParserProducedNoSourceFile =>
      module_frontend_report(
        "parser produced no source file",
        diagnostic_.span,
        code="E1102",
        label="parser produced no source file",
        note="the parser returned neither a source tree nor a concrete parse error",
        help="report this as a compiler bug with the input that triggered it",
      )
  }
}

///|
fn missing_import_diagnostic(
  module_ : String,
  span : @basic.SourceSpan?,
  source_modules : Array[String],
  interface_modules : Array[String],
) -> CompilerDiagnostic {
  let facts : Array[CompilerDiagnosticFact] = []
  for source_module in source_modules {
    facts.push({
      name: "considered source module",
      value: "`\{source_module}`",
      span: None,
    })
  }
  for interface_module in interface_modules {
    facts.push({
      name: "considered interface artifact",
      value: "declares module `\{interface_module}`",
      span: None,
    })
  }
  if source_modules.is_empty() && interface_modules.is_empty() {
    facts.push({
      name: "considered inputs",
      value: "no library source or interface artifact was available",
      span: None,
    })
  }
  diagnostic(
    "missing imported module `\{module_}`",
    span~,
    severity=Error,
    code=Some("E4002"),
    labels=primary_label(span, "no explicit input provides this module"),
    notes=[
      "Lane only compiles explicitly provided source files and interface artifacts",
    ],
    helps=[
      "pass an input whose declared module is `\{module_}`, or change the import to one of the listed modules",
    ],
    facts~,
    suggestions=[
      {
        message: "check the imported module name against the listed explicit inputs",
        edits: [],
        applicability: MaybeIncorrect,
      },
    ],
  )
}

///|
fn module_frontend_report(
  title : String,
  span : @basic.SourceSpan?,
  code~ : String,
  label~ : String,
  note~ : String,
  help~ : String,
) -> CompilerDiagnostic {
  diagnostic(
    title,
    span~,
    severity=Error,
    code=Some(code),
    labels=primary_label(span, label),
    notes=[note],
    helps=[help],
  )
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompilerDiagnostic] {
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
fn lex_diagnostic(error : @lexer.LexError) -> CompilerDiagnostic {
  let span = Some(error.span)
  diagnostic(
    lex_error_title(error.error),
    span~,
    severity=Error,
    code=Some(lex_error_code(error.error)),
    labels=[
      {
        span: compiler_local_span(error.span),
        message: lex_error_label(error.error),
        style: Primary,
      },
    ],
    notes=lex_error_notes(error.error),
    helps=lex_error_helps(error.error),
  )
}

///|
fn lex_error_code(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "E1000"
    UnterminatedString => "E1002"
    InvalidStringEscape(_) => "E1003"
    InvalidHexEscape(_) => "E1004"
    NonAsciiStringCharacter => "E1005"
  }
}

///|
fn lex_error_title(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "illegal character in source"
    UnterminatedString => "unterminated string literal"
    InvalidStringEscape(_) => "invalid string escape"
    InvalidHexEscape(_) => "invalid hexadecimal escape"
    NonAsciiStringCharacter => "non-ASCII character in string literal"
  }
}

///|
fn lex_error_label(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(value) => "`\{value}` is not valid Lane syntax"
    UnterminatedString => "this string literal is never closed"
    InvalidStringEscape(value) =>
      "`\{value}` is not a supported escape sequence"
    InvalidHexEscape(value) => "`\{value}` is not a valid hexadecimal escape"
    NonAsciiStringCharacter =>
      "Lane string literals currently accept ASCII characters only"
  }
}

///|
fn lex_error_notes(error : @lexer.LexicalError) -> Array[String] {
  match error {
    NonAsciiStringCharacter =>
      [
        "the lexer rejects non-ASCII bytes inside string literals in the current language version",
      ]
    _ => []
  }
}

///|
fn lex_error_helps(error : @lexer.LexicalError) -> Array[String] {
  match error {
    IllegalCharacter(_) =>
      ["remove this character or replace it with a valid Lane token"]
    UnterminatedString => ["add a closing `\"` before the end of the line"]
    InvalidStringEscape(_) =>
      ["use a supported escape such as `\\n`, `\\t`, `\\\"`, or `\\\\`"]
    InvalidHexEscape(_) =>
      ["write hexadecimal escapes with exactly two hexadecimal digits"]
    NonAsciiStringCharacter =>
      ["replace the character with ASCII text or an explicit supported escape"]
  }
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompilerDiagnostic {
  error.to_compiler_diagnostic(DiagnosticContext())
}
