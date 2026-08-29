///|
pub extend CanonicalBasicAbiDemand with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiDemand with Eq::{not_equal, equal}

///|
pub extend CanonicalBasicAbiDiagnostic with @compiler_diag.ToCompilerDiagnostic::{
  to_compiler_diagnostic,
}

///|
pub extend CanonicalBasicAbiDiagnostic with @prettyprinter.Pretty::{pretty}

///|
pub extend CanonicalBasicAbiDiagnostic with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiDiagnostic with Eq::{not_equal, equal}

///|
pub extend CanonicalBasicAbiError with @prettyprinter.Pretty::{pretty}

///|
pub extend CanonicalBasicAbiError with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiError with Eq::{not_equal, equal}

///|
pub extend CanonicalBasicAbiIdentityCatalog with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiIdentityCatalog with Eq::{not_equal, equal}

///|
pub extend CanonicalBasicAbiObjectTypeDeclaration with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiObjectTypeDeclaration with Eq::{not_equal, equal}

///|
pub extend CanonicalBasicAbiRuntimeContract with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiRuntimeContract with Eq::{not_equal, equal}

///|
pub extend CanonicalBasicAbiRuntimeContractError with Debug::{to_repr}

///|
pub extend CanonicalBasicAbiRuntimeContractError with Eq::{not_equal, equal}

///|
pub extend CertifiedCanonicalBasicAbiRuntimeContract with Debug::{to_repr}

///|
pub extend CertifiedCanonicalBasicAbiRuntimeContract with Eq::{not_equal, equal}
