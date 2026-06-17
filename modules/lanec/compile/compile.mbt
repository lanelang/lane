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
fn combined_source(prelude_source : String, user_source : String) -> String {
  prelude_source + "\n" + user_source
}

///|
/// Checks a single-file Lane program after prepending the standard prelude
/// source supplied by the caller.
pub fn check_with_prelude(
  prelude_source : String,
  user_source : String,
) -> CheckResult {
  match checked_source_with_prelude(prelude_source, user_source) {
    Ok(source) => { source: Some(source), diagnostics: [] }
    Err(diagnostics) => { source: None, diagnostics }
  }
}

///|
/// Compiles a single-file Lane program with prelude loading into Buslane plus
/// compiler-owned side tables needed by tools and runtimes.
pub fn compile_with_prelude(
  prelude_source : String,
  user_source : String,
) -> CompileResult {
  match checked_source_with_prelude(prelude_source, user_source) {
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
fn checked_source_with_prelude(
  prelude_source : String,
  user_source : String,
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let source = combined_source(prelude_source, user_source)
  let parsed = @parser.parse_string(source)
  let parse_diagnostics = parse_diagnostics(parsed)
  if !parse_diagnostics.is_empty() {
    return Err(parse_diagnostics)
  }
  guard parsed.source is Some(file) else {
    return Err([make_error("parser produced no source file", span=None)])
  }
  let resolved = @resolve.resolve_source_file_result(file)
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
