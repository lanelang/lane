///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticLabel,
  compiler_error,
  compiler_local_span,
}

///|
pub(all) struct FormatOptions {
  width : Int
} derive(Debug, Eq)

///|
pub fn default_options() -> FormatOptions {
  { width: 100 }
}

///|
pub fn format_source(
  source : String,
) -> Result[String, Array[CompilerDiagnostic]] {
  format_source_with_options(source, default_options())
}

///|
pub fn format_source_with_options(
  source : String,
  options : FormatOptions,
) -> Result[String, Array[CompilerDiagnostic]] {
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
fn parse_diagnostic(error : @parser.ParseError) -> CompilerDiagnostic {
  error.to_compiler_diagnostic(DiagnosticContext())
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
) -> CompilerDiagnostic {
  compiler_error(message, span~, code~, labels~, notes~, helps~)
}
