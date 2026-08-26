///|
pub extend Applicability with Debug::{to_repr}

///|
pub extend Applicability with Eq::{not_equal, equal}

///|
pub extend Diagnostic with Debug::{to_repr}

///|
pub extend Diagnostic with Eq::{not_equal, equal}

///|
pub extend DiagnosticFact with Debug::{to_repr}

///|
pub extend DiagnosticFact with Eq::{not_equal, equal}

///|
pub extend Label with Debug::{to_repr}

///|
pub extend Label with Eq::{not_equal, equal}

///|
pub extend LabelStyle with Debug::{to_repr}

///|
pub extend LabelStyle with Eq::{not_equal, equal}

///|
pub extend RelatedLocation with Debug::{to_repr}

///|
pub extend RelatedLocation with Eq::{not_equal, equal}

///|
pub extend Severity with Debug::{to_repr}

///|
pub extend Severity with Eq::{not_equal, equal}

///|
pub extend SourceId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend SourceId with Debug::{to_repr}

///|
pub extend SourceId with Eq::{not_equal, equal}

///|
pub extend SourceSpan with Debug::{to_repr}

///|
pub extend SourceSpan with Eq::{not_equal, equal}

///|
pub extend Suggestion with Debug::{to_repr}

///|
pub extend Suggestion with Eq::{not_equal, equal}

///|
pub extend TextEdit with Debug::{to_repr}

///|
pub extend TextEdit with Eq::{not_equal, equal}
