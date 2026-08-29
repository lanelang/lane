///|
pub extend BuiltinEffect with Debug::{to_repr}

///|
pub extend BuiltinEffect with Eq::{not_equal, equal}

///|
pub extend Effect with @prettyprinter.Pretty::{pretty}

///|
pub extend Effect with Debug::{to_repr}

///|
pub extend Effect with Eq::{not_equal, equal}

///|
pub extend GenericArgument with @prettyprinter.Pretty::{pretty}

///|
pub extend GenericArgument with Debug::{to_repr}

///|
pub extend GenericArgument with Eq::{not_equal, equal}

///|
pub extend Kind with @prettyprinter.Pretty::{pretty}

///|
pub extend Kind with Debug::{to_repr}

///|
pub extend Kind with Eq::{not_equal, equal}

///|
pub extend PrimitiveType with @prettyprinter.Pretty::{pretty}

///|
pub extend PrimitiveType with Debug::{to_repr}

///|
pub extend PrimitiveType with Eq::{not_equal, equal}

///|
pub extend Type with @prettyprinter.Pretty::{pretty}

///|
pub extend Type with Debug::{to_repr}

///|
pub extend Type with Eq::{not_equal, equal}

///|
pub extend TypeComputationError with Debug::{to_repr}

///|
pub extend TypeComputationError with Eq::{not_equal, equal}

///|
pub extend TypeParameter with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeParameter with Debug::{to_repr}

///|
pub extend TypeParameter with Eq::{not_equal, equal}

///|
pub extend TypeSubstitution with @prettyprinter.Pretty::{pretty}

///|
pub extend TypeSubstitution with Debug::{to_repr}

///|
pub extend TypeSubstitution with Eq::{not_equal, equal}

///|
pub extend TypeSubstitutionEntry with Debug::{to_repr}

///|
pub extend TypeSubstitutionEntry with Eq::{not_equal, equal}
