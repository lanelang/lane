///|
using @prettyprinter {type Document, line, separate, space, text}

///|
fn span_text(span : @basic.SourceSpan) -> String {
  "\{span.start_line}:\{span.start_column}-\{span.end_line}:\{span.end_column}"
}

///|
pub impl @prettyprinter.Pretty for CompilerDiagnostic with fn pretty(
  diagnostic : CompilerDiagnostic,
) -> Document {
  let header = diagnostic.header_doc()
  let body = diagnostic.body_doc()
  if body is Some(body) {
    header + line + body
  } else {
    header
  }
}

///|
fn CompilerDiagnostic::header_doc(self : CompilerDiagnostic) -> Document {
  self.severity.to_doc() +
  self.code_doc() +
  text(":") +
  space +
  text(self.message)
}

///|
fn CompilerDiagnosticSeverity::to_doc(
  self : CompilerDiagnosticSeverity,
) -> Document {
  match self {
    Error => text("error")
    Warning => text("warning")
  }
}

///|
fn CompilerDiagnostic::code_doc(self : CompilerDiagnostic) -> Document {
  match self.code {
    Some(code) => text("[") + text(code) + text("]")
    None => text("")
  }
}

///|
fn CompilerDiagnostic::body_doc(self : CompilerDiagnostic) -> Document? {
  let docs : Array[Document] = []
  match self.span {
    Some(span) => docs.push(text("  span:") + space + text(span_text(span)))
    None => ()
  }
  for label in self.labels {
    docs.push(label.to_doc())
  }
  for note in self.notes {
    docs.push(text("  note:") + space + text(note))
  }
  for fact in self.facts {
    docs.push(fact.to_doc())
  }
  for help in self.helps {
    docs.push(text("  help:") + space + text(help))
  }
  for suggestion in self.suggestions {
    docs.push(suggestion.to_doc())
  }
  if docs.is_empty() {
    None
  } else {
    Some(separate(line, docs))
  }
}

///|
fn CompilerDiagnosticLabel::to_doc(self : CompilerDiagnosticLabel) -> Document {
  let prefix = match self.style {
    Primary => text("  primary:")
    Secondary => text("  secondary:")
  }
  prefix +
  space +
  text(span_text(self.span)) +
  text(":") +
  space +
  text(self.message)
}

///|
fn CompilerDiagnosticFact::to_doc(self : CompilerDiagnosticFact) -> Document {
  match self.span {
    Some(span) =>
      text("  ") +
      text(self.name) +
      text(":") +
      space +
      text(self.value) +
      space +
      text("at") +
      space +
      text(span_text(span))
    None => text("  ") + text(self.name) + text(":") + space + text(self.value)
  }
}

///|
fn CompilerDiagnosticSuggestion::to_doc(
  self : CompilerDiagnosticSuggestion,
) -> Document {
  text("  suggestion:") +
  space +
  text(self.message) +
  space +
  text("(\{self.applicability.as_text()})")
}

///|
fn CompilerDiagnosticApplicability::as_text(
  self : CompilerDiagnosticApplicability,
) -> String {
  match self {
    MachineApplicable => "machine-applicable"
    MaybeIncorrect => "maybe-incorrect"
    HasPlaceholders => "has-placeholders"
    Unspecified => "unspecified"
  }
}

///|
pub fn CompilerDiagnostic::list_doc(
  diagnostics : Array[CompilerDiagnostic],
) -> Document {
  if diagnostics.is_empty() {
    text("diagnostics") + space + text("{}")
  } else {
    text("diagnostics") +
    space +
    separate(line, diagnostics.map(CompilerDiagnostic::pretty))
  }
}
