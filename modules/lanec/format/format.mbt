///|
using @prettyprinter {space, text}

///|
pub(all) struct FormatOptions {
  width : Int
} derive(Debug, Eq)

///|
pub fn default_options() -> FormatOptions {
  { width: 100 }
}

///|
pub(all) struct FormatDiagnostic {
  message : String
  span : @basic.SourceSpan?
} derive(Debug, Eq)

///|
pub fn format_source(
  source : String,
) -> Result[String, Array[FormatDiagnostic]] {
  format_source_with_options(source, default_options())
}

///|
pub fn format_source_with_options(
  source : String,
  options : FormatOptions,
) -> Result[String, Array[FormatDiagnostic]] {
  let parsed = @parser.parse_string(source)
  let diagnostics = parse_diagnostics(parsed)
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  match parsed.source {
    Some(file) =>
      Ok(
        leading_comment_block(source) +
        format_source_file_with_options(file, options),
      )
    None => Err([{ message: "parser produced no source file", span: None }])
  }
}

///|
pub fn format_source_file(source : @syntax.SourceFile) -> String {
  format_source_file_with_options(source, default_options())
}

///|
pub fn format_source_file_with_options(
  source : @syntax.SourceFile,
  options : FormatOptions,
) -> String {
  @prettyprinter.render(source, width=options.width) + "\n"
}

///|
fn leading_comment_block(source : String) -> String {
  let lines = source.split("\n").collect()
  let kept = []
  let mut saw_comment = false
  for line in lines {
    if line.has_prefix("//") {
      kept.push(line)
      saw_comment = true
      continue
    }
    if saw_comment && line.is_empty() {
      kept.push(line)
      continue
    }
    break
  }
  if kept.is_empty() {
    ""
  } else {
    kept.join("\n") + "\n"
  }
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[FormatDiagnostic] {
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
fn lex_diagnostic(error : @lexer.LexError) -> FormatDiagnostic {
  {
    message: "lexical error: " + lex_error_text(error.error),
    span: Some(error.span),
  }
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
fn parse_diagnostic(error : @parser.ParseError) -> FormatDiagnostic {
  {
    message: "parse error: " + parse_error_text(error.kind),
    span: Some(error.loc),
  }
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
pub impl @prettyprinter.Pretty for FormatDiagnostic with fn pretty(
  diagnostic : FormatDiagnostic,
) {
  let message = text(diagnostic.message)
  match diagnostic.span {
    Some(span) => text(span_text(span)) + text(":") + space + message
    None => message
  }
}
