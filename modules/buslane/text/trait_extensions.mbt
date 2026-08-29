///|
pub extend ParseError with Debug::{to_repr}

///|
pub extend Token with Debug::{to_repr}

///|
pub extend TokenKind with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend TokenKind with Debug::{to_repr}

///|
pub extend TokenKind with Eq::{not_equal, equal}

///|
pub extend TokenKind with Hash::{hash, hash_combine}

///|
pub extend TokenKind with Show::{to_string, output}
