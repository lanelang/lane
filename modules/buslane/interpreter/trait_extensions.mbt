///|
pub extend BuslaneRuntimeError with @prettyprinter.Pretty::{pretty}

///|
pub extend BuslaneRuntimeError with Debug::{to_repr}

///|
pub extend BuslaneRuntimeError with Eq::{not_equal, equal}

///|
pub extend BuslaneRuntimeProgram with @prettyprinter.Pretty::{pretty}

///|
pub extend BuslaneRuntimeValue with @prettyprinter.Pretty::{pretty}
