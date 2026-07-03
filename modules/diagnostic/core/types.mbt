///|
pub(all) struct SourceId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct SourceSpan {
  source_id : SourceId
  start_offset : Int
  end_offset : Int
} derive(Debug, Eq)

///|
pub(all) enum Severity {
  Error
  Warning
  Info
  Hint
} derive(Debug, Eq)

///|
pub(all) enum LabelStyle {
  Primary
  Secondary
} derive(Debug, Eq)

///|
pub(all) struct Label {
  style : LabelStyle
  span : SourceSpan
  message : String?
} derive(Debug, Eq)

///|
pub(all) enum Applicability {
  MachineApplicable
  MaybeIncorrect
  HasPlaceholders
  Unspecified
} derive(Debug, Eq)

///|
pub(all) struct TextEdit {
  span : SourceSpan
  replacement : String
} derive(Debug, Eq)

///|
pub(all) struct Suggestion {
  message : String
  edits : Array[TextEdit]
  applicability : Applicability
} derive(Debug, Eq)

///|
pub(all) struct DiagnosticFact {
  name : String
  value : String
  span : SourceSpan?
} derive(Debug, Eq)

///|
pub(all) struct RelatedLocation {
  span : SourceSpan
  message : String
} derive(Debug, Eq)

///|
pub(all) struct Diagnostic {
  severity : Severity
  code : String?
  message : String
  labels : Array[Label]
  notes : Array[String]
  helps : Array[String]
  facts : Array[DiagnosticFact]
  suggestions : Array[Suggestion]
  related_locations : Array[RelatedLocation]
  related : Array[Diagnostic]
} derive(Debug, Eq)

///|
pub fn SourceSpan::SourceSpan(
  source_id : SourceId,
  start_offset : Int,
  end_offset : Int,
) -> SourceSpan {
  { source_id, start_offset, end_offset }
}

///|
pub fn Label::primary(span : SourceSpan, message? : String) -> Label {
  { style: Primary, span, message }
}

///|
pub fn Label::secondary(span : SourceSpan, message? : String) -> Label {
  { style: Secondary, span, message }
}

///|
pub fn Diagnostic::error(
  message : String,
  code? : String,
  labels? : Array[Label] = [],
  notes? : Array[String] = [],
  helps? : Array[String] = [],
  facts? : Array[DiagnosticFact] = [],
  suggestions? : Array[Suggestion] = [],
  related_locations? : Array[RelatedLocation] = [],
  related? : Array[Diagnostic] = [],
) -> Diagnostic {
  {
    severity: Error,
    code,
    message,
    labels,
    notes,
    helps,
    facts,
    suggestions,
    related_locations,
    related,
  }
}

///|
pub fn Severity::as_text(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Info => "info"
    Hint => "hint"
  }
}

///|
pub fn LabelStyle::marker(self : LabelStyle) -> String {
  match self {
    Primary => "^"
    Secondary => "-"
  }
}

///|
pub fn Applicability::as_text(self : Applicability) -> String {
  match self {
    MachineApplicable => "machine-applicable"
    MaybeIncorrect => "maybe-incorrect"
    HasPlaceholders => "has-placeholders"
    Unspecified => "unspecified"
  }
}
