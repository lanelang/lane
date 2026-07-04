///|
using @prettyprinter {type Document, line, separate, space, text}

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
  code : String?
  labels : Array[FormatDiagnosticLabel]
  notes : Array[String]
  helps : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct FormatDiagnosticLabel {
  span : @basic.SourceSpan
  message : String
  style : FormatDiagnosticLabelStyle
} derive(Debug, Eq)

///|
pub(all) enum FormatDiagnosticLabelStyle {
  Primary
  Secondary
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
    None =>
      Err([
        diagnostic(
          "parser did not produce a source file",
          span=None,
          code=Some("E1102"),
          labels=[],
          notes=[
            "the parser recovered enough to return no syntax tree but no concrete parse error was reported",
          ],
          helps=["report this as a compiler bug if the input is reproducible"],
        ),
      ])
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
  let span = Some(error.span)
  diagnostic(
    lex_error_title(error.error),
    span~,
    code=Some(lex_error_code(error.error)),
    labels=[
      {
        span: error.span,
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
    UnterminatedBlockComment => "E1001"
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
    UnterminatedBlockComment => "unterminated block comment"
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
    UnterminatedBlockComment => "this block comment is never closed"
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
    UnterminatedBlockComment => ["add a closing `*/` before the end of file"]
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
fn parse_diagnostic(error : @parser.ParseError) -> FormatDiagnostic {
  let span = Some(error.loc)
  diagnostic(
    parse_error_title(error.kind),
    span~,
    code=Some(parse_error_code(error.kind)),
    labels=[
      {
        span: error.loc,
        message: parse_error_label(error.kind),
        style: Primary,
      },
    ],
    notes=parse_error_notes(error.kind),
    helps=parse_error_helps(error.kind),
  )
}

///|
fn parse_error_code(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(_, _) => "E1100"
    UnexpectedEndOfInput(_) => "E1101"
  }
}

///|
fn parse_error_title(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(_, _) => "unexpected token"
    UnexpectedEndOfInput(_) => "unexpected end of input"
  }
}

///|
fn parse_error_label(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(token, _) => "the parser did not expect " + token.label
    UnexpectedEndOfInput(_) =>
      "the source file ended while parsing this construct"
  }
}

///|
fn parse_error_notes(error : @parser.ParseErrorKind) -> Array[String] {
  match error {
    UnexpectedToken(_, expected) | UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        []
      } else {
        ["expected one of: " + expected_list(expected)]
      }
  }
}

///|
fn parse_error_helps(error : @parser.ParseErrorKind) -> Array[String] {
  match error {
    UnexpectedToken(_, expected) =>
      if expected.is_empty() {
        ["remove the unexpected token or rewrite the surrounding expression"]
      } else {
        [
          "rewrite this position so it starts with one of: " +
          expected_list(expected),
        ]
      }
    UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        ["finish the incomplete construct before the end of file"]
      } else {
        [
          "add the missing syntax before the end of file; expected one of: " +
          expected_list(expected),
        ]
      }
  }
}

///|
fn expected_list(expected : Array[@parser.ExpectedSyntax]) -> String {
  expected.map(fn(item) { item.label }).join(", ")
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
) -> Document {
  let header = text("error") +
    code_doc(diagnostic.code) +
    text(":") +
    space +
    text(diagnostic.message)
  let body = diagnostic_body_doc(diagnostic)
  if body is Some(body) {
    header + line + body
  } else {
    header
  }
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  code~ : String?,
  labels~ : Array[FormatDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
) -> FormatDiagnostic {
  { message, span, code, labels, notes, helps }
}

///|
fn code_doc(code : String?) -> Document {
  match code {
    Some(code) => text("[") + text(code) + text("]")
    None => text("")
  }
}

///|
fn diagnostic_body_doc(diagnostic : FormatDiagnostic) -> Document? {
  let docs : Array[Document] = []
  match diagnostic.span {
    Some(span) => docs.push(text("  span:") + space + text(span_text(span)))
    None => ()
  }
  for label in diagnostic.labels {
    docs.push(label_doc(label))
  }
  for note in diagnostic.notes {
    docs.push(text("  note:") + space + text(note))
  }
  for help in diagnostic.helps {
    docs.push(text("  help:") + space + text(help))
  }
  if docs.is_empty() {
    None
  } else {
    Some(separate(line, docs))
  }
}

///|
fn label_doc(label : FormatDiagnosticLabel) -> Document {
  let prefix = match label.style {
    Primary => text("  primary:")
    Secondary => text("  secondary:")
  }
  prefix +
  space +
  text(span_text(label.span)) +
  text(":") +
  space +
  text(label.message)
}
