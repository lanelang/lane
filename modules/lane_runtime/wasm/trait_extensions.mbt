///|
pub extend ExecutionMode with Debug::{to_repr}

///|
pub extend ExecutionMode with Eq::{not_equal, equal}

///|
pub extend WasmLoadError with Debug::{to_repr}

///|
pub extend WasmLoadError with Eq::{not_equal, equal}
