///|
using @prettyprinter {type Document, line, separate, space, text}

///|
pub(all) struct CompileDiagnostic {
  message : String
  span : @basic.SourceSpan?
  severity : CompileDiagnosticSeverity
  code : String?
  labels : Array[CompileDiagnosticLabel]
  notes : Array[String]
  helps : Array[String]
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticSeverity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub(all) struct CompileDiagnosticLabel {
  span : @basic.SourceSpan
  message : String
  style : CompileDiagnosticLabelStyle
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticLabelStyle {
  Primary
  Secondary
} derive(Debug, Eq)

///|
fn make_error(
  message : String,
  span~ : @basic.SourceSpan?,
) -> CompileDiagnostic {
  diagnostic(
    message,
    span~,
    severity=Error,
    code=None,
    labels=primary_label(span, message),
    notes=[],
    helps=[],
  )
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompileDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompileDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
) -> CompileDiagnostic {
  { message, span, severity, code, labels, notes, helps }
}

///|
fn primary_label(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompileDiagnosticLabel] {
  match span {
    Some(span) => [{ span, message, style: Primary }]
    None => []
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
pub impl @prettyprinter.Pretty for CompileDiagnostic with fn pretty(
  diagnostic : CompileDiagnostic,
) -> Document {
  let header = severity_doc(diagnostic.severity) +
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
fn severity_doc(severity : CompileDiagnosticSeverity) -> Document {
  match severity {
    Error => text("error")
    Warning => text("warning")
  }
}

///|
fn code_doc(code : String?) -> Document {
  match code {
    Some(code) => text("[") + text(code) + text("]")
    None => text("")
  }
}

///|
fn diagnostic_body_doc(diagnostic : CompileDiagnostic) -> Document? {
  let docs : Array[Document] = []
  match diagnostic.span {
    Some(span) => docs.push(text("  -->") + space + text(span_text(span)))
    None => ()
  }
  for label in diagnostic.labels {
    docs.push(label_doc(label))
  }
  for note in diagnostic.notes {
    docs.push(text("  = note:") + space + text(note))
  }
  for help in diagnostic.helps {
    docs.push(text("  = help:") + space + text(help))
  }
  if docs.is_empty() {
    None
  } else {
    Some(separate(line, docs))
  }
}

///|
fn label_doc(label : CompileDiagnosticLabel) -> Document {
  let prefix = match label.style {
    Primary => text("  = label:")
    Secondary => text("  = note:")
  }
  prefix + space + text(span_text(label.span)) + space + text(label.message)
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
