///|
pub extend BasicTypeProvider with Debug::{to_repr}

///|
pub extend BasicTypeProvider with Eq::{not_equal, equal}

///|
pub extend BasicTypeProvider with Hash::{hash, hash_combine}

///|
pub extend BasicVariantProvider with Debug::{to_repr}

///|
pub extend BasicVariantProvider with Eq::{not_equal, equal}

///|
pub extend BasicVariantProvider with Hash::{hash, hash_combine}

///|
pub extend HostSignature with Debug::{to_repr}

///|
pub extend HostSignature with Eq::{not_equal, equal}

///|
pub extend Intrinsic with Debug::{to_repr}

///|
pub extend Intrinsic with Eq::{not_equal, equal}

///|
pub extend IntrinsicEffect with Debug::{to_repr}

///|
pub extend IntrinsicEffect with Eq::{not_equal, equal}

///|
pub extend IntrinsicFunctionImplementation with Debug::{to_repr}

///|
pub extend IntrinsicFunctionImplementation with Eq::{not_equal, equal}

///|
pub extend IntrinsicSignature with Debug::{to_repr}

///|
pub extend IntrinsicSignature with Eq::{not_equal, equal}

///|
pub extend IntrinsicType with Debug::{to_repr}

///|
pub extend IntrinsicType with Eq::{not_equal, equal}

///|
pub extend IntrinsicTypeConstructor with Debug::{to_repr}

///|
pub extend IntrinsicTypeConstructor with Eq::{not_equal, equal}

///|
pub extend IntrinsicTypeParameterKind with Debug::{to_repr}

///|
pub extend IntrinsicTypeParameterKind with Eq::{not_equal, equal}

///|
pub extend ValueKind with Debug::{to_repr}

///|
pub extend ValueKind with Eq::{not_equal, equal}
