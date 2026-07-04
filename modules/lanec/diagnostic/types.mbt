///|
pub(all) struct CompilerDiagnostic {
  source_id : String?
  message : String
  span : CompilerSourceSpan?
  severity : CompilerDiagnosticSeverity
  code : String?
  labels : Array[CompilerDiagnosticLabel]
  notes : Array[String]
  helps : Array[String]
  facts : Array[CompilerDiagnosticFact]
  suggestions : Array[CompilerDiagnosticSuggestion]
} derive(Debug, Eq)

///|
pub(all) enum CompilerSourceSpan {
  Local(@basic.SourceSpan)
  Source(source_id~ : String, span~ : @basic.SourceSpan)
} derive(Debug, Eq)

///|
pub(all) enum CompilerDiagnosticSeverity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub(all) struct CompilerDiagnosticLabel {
  span : CompilerSourceSpan
  message : String
  style : CompilerDiagnosticLabelStyle
} derive(Debug, Eq)

///|
pub(all) enum CompilerDiagnosticLabelStyle {
  Primary
  Secondary
} derive(Debug, Eq)

///|
pub(all) struct CompilerDiagnosticFact {
  name : String
  value : String
  span : CompilerSourceSpan?
} derive(Debug, Eq)

///|
pub(all) struct CompilerDiagnosticTextEdit {
  span : CompilerSourceSpan
  replacement : String
} derive(Debug, Eq)

///|
pub(all) enum CompilerDiagnosticApplicability {
  MachineApplicable
  MaybeIncorrect
  HasPlaceholders
  Unspecified
} derive(Debug, Eq)

///|
pub(all) struct CompilerDiagnosticSuggestion {
  message : String
  edits : Array[CompilerDiagnosticTextEdit]
  applicability : CompilerDiagnosticApplicability
} derive(Debug, Eq)

///|
pub fn CompilerDiagnostic::with_source_id(
  self : CompilerDiagnostic,
  source_id : String,
) -> CompilerDiagnostic {
  {
    ..self,
    source_id: Some(source_id),
    span: self.span.map(fn(span) { span.with_default_source_id(source_id) }),
    labels: self.labels.map(fn(label) {
      { ..label, span: label.span.with_default_source_id(source_id) }
    }),
    facts: self.facts.map(fn(fact) {
      {
        ..fact,
        span: fact.span.map(fn(span) { span.with_default_source_id(source_id) }),
      }
    }),
    suggestions: self.suggestions.map(fn(suggestion) {
      {
        ..suggestion,
        edits: suggestion.edits.map(fn(edit) {
          { ..edit, span: edit.span.with_default_source_id(source_id) }
        }),
      }
    }),
  }
}

///|
pub fn compiler_local_span(span : @basic.SourceSpan) -> CompilerSourceSpan {
  Local(span)
}

///|
pub fn compiler_source_span(
  source_id : String,
  span : @basic.SourceSpan,
) -> CompilerSourceSpan {
  Source(source_id~, span~)
}

///|
fn CompilerSourceSpan::with_default_source_id(
  self : CompilerSourceSpan,
  source_id : String,
) -> CompilerSourceSpan {
  match self {
    Local(span) => Source(source_id~, span~)
    Source(..) => self
  }
}

///|
pub fn CompilerSourceSpan::source_id(self : CompilerSourceSpan) -> String? {
  match self {
    Local(_) => None
    Source(source_id~, ..) => Some(source_id)
  }
}

///|
pub fn CompilerDiagnostic::primary_source_id(
  self : CompilerDiagnostic,
) -> String? {
  match self.source_id {
    Some(source_id) => Some(source_id)
    None =>
      match self.span {
        Some(span) => span.source_id()
        None =>
          match self.labels.get(0) {
            Some(label) => label.span.source_id()
            None => None
          }
      }
  }
}

///|
pub fn CompilerDiagnostic::source_ids(
  self : CompilerDiagnostic,
) -> Array[String] {
  let source_ids : Array[String] = []
  fn push_unique(source_ids : Array[String], source_id : String) {
    if !source_ids.contains(source_id) {
      source_ids.push(source_id)
    }
  }
  if self.source_id is Some(source_id) {
    push_unique(source_ids, source_id)
  }
  if self.span is Some(span) {
    if span.source_id() is Some(source_id) {
      push_unique(source_ids, source_id)
    }
  }
  for label in self.labels {
    if label.span.source_id() is Some(source_id) {
      push_unique(source_ids, source_id)
    }
  }
  for fact in self.facts {
    if fact.span is Some(span) {
      if span.source_id() is Some(source_id) {
        push_unique(source_ids, source_id)
      }
    }
  }
  for suggestion in self.suggestions {
    for edit in suggestion.edits {
      if edit.span.source_id() is Some(source_id) {
        push_unique(source_ids, source_id)
      }
    }
  }
  source_ids
}
