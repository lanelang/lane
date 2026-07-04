///|
pub(all) struct CompilerDiagnostic {
  source_id : String?
  message : String
  span : @basic.SourceSpan?
  severity : CompilerDiagnosticSeverity
  code : String?
  labels : Array[CompilerDiagnosticLabel]
  notes : Array[String]
  helps : Array[String]
  facts : Array[CompilerDiagnosticFact]
  suggestions : Array[CompilerDiagnosticSuggestion]
} derive(Debug, Eq)

///|
pub(all) enum CompilerDiagnosticSeverity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub(all) struct CompilerDiagnosticLabel {
  span : @basic.SourceSpan
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
  span : @basic.SourceSpan?
} derive(Debug, Eq)

///|
pub(all) struct CompilerDiagnosticTextEdit {
  span : @basic.SourceSpan
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
  { ..self, source_id: Some(source_id) }
}
