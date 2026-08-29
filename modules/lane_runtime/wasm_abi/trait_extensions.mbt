///|
pub extend InternalRuntimeFunction with Debug::{to_repr}

///|
pub extend InternalRuntimeFunction with Eq::{not_equal, equal}

///|
pub extend RuntimeControlGlobal with Debug::{to_repr}

///|
pub extend RuntimeControlGlobal with Eq::{not_equal, equal}

///|
pub extend RuntimeFailureCode with Debug::{to_repr}

///|
pub extend RuntimeFailureCode with Eq::{not_equal, equal}
