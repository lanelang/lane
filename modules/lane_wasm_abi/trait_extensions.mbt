///|
pub extend CoreValueType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend CoreValueType with Debug::{to_repr}

///|
pub extend CoreValueType with Eq::{not_equal, equal}

///|
pub extend ImportParameter with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ImportParameter with Debug::{to_repr}

///|
pub extend ImportParameter with Eq::{not_equal, equal}

///|
pub extend ImportResult with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ImportResult with Debug::{to_repr}

///|
pub extend ImportResult with Eq::{not_equal, equal}

///|
pub extend ImportContract with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ImportContract with Debug::{to_repr}

///|
pub extend ImportContract with Eq::{not_equal, equal}

///|
pub extend WasiPreview1Import with Debug::{to_repr}

///|
pub extend LaneRuntimeV1Import with Debug::{to_repr}

///|
pub extend LaneRuntimeV1Import with Eq::{equal, not_equal}

///|
pub extend RunCommandEnvironmentEntry with Debug::{to_repr}

///|
pub extend RunCommandEnvironmentEntry with Eq::{equal, not_equal}

///|
pub extend RunCommandRequest with Debug::{to_repr}

///|
pub extend RunCommandRequest with Eq::{equal, not_equal}

///|
pub extend RunCommandFrameError with Debug::{to_repr}

///|
pub extend RunCommandFrameError with Eq::{equal, not_equal}

///|
pub extend RunCommandTermination with Debug::{to_repr}

///|
pub extend RunCommandTermination with Eq::{equal, not_equal}

///|
pub extend RunCommandHostStatus with Debug::{to_repr}

///|
pub extend RunCommandHostStatus with Eq::{equal, not_equal}

///|
pub extend WasiPreview1Import with Eq::{not_equal, equal}
