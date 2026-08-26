///|
pub extend EntryAdmissionFailure with Debug::{to_repr}

///|
pub extend EntryAdmissionFailure with Eq::{not_equal, equal}

///|
pub extend ExecutableElaborationError with Debug::{to_repr}

///|
pub extend ExecutableElaborationError with Eq::{not_equal, equal}

///|
pub extend ExecutableProgram with @prettyprinter.Pretty::{pretty}

///|
pub extend ExecutableProgram with Debug::{to_repr}

///|
pub extend ExecutableProgram with Eq::{not_equal, equal}

///|
pub extend ExecutionProfile with Debug::{to_repr}

///|
pub extend ExecutionProfile with Eq::{not_equal, equal}
