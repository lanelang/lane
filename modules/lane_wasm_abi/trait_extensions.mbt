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
pub extend WasiPreview1Import with Eq::{not_equal, equal}
