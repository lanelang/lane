///|
pub extend ExpectedSyntax with Debug::{to_repr}

///|
pub extend ExpectedSyntax with Eq::{not_equal, equal}

///|
pub extend ParseError with @compiler_diag.ToCompilerDiagnostic::{
  to_compiler_diagnostic,
}

///|
pub extend ParseError with Debug::{to_repr}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
pub extend ParseErrorKind with Debug::{to_repr}

///|
pub extend ParseErrorKind with Eq::{not_equal, equal}

///|
pub extend ParseFailure with Debug::{to_repr}

///|
pub extend ParseFailure with Eq::{not_equal, equal}

///|
pub extend ParseResult with Debug::{to_repr}

///|
pub extend ParseResult with Eq::{not_equal, equal}

///|
pub extend ParsedSource with Debug::{to_repr}

///|
pub extend ParsedSource with Eq::{not_equal, equal}

///|
pub extend TokenSummary with Debug::{to_repr}

///|
pub extend TokenSummary with Eq::{not_equal, equal}
