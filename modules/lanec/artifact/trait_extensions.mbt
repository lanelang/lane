///|
pub extend ArtifactBinaryDecodeError with Debug::{to_repr}

///|
pub extend CompiledModuleArtifact with Debug::{to_repr}

///|
pub extend CompiledModuleArtifact with Eq::{not_equal, equal}

///|
pub extend CompiledModuleSetArtifact with Debug::{to_repr}

///|
pub extend CompiledModuleSetArtifact with Eq::{not_equal, equal}

///|
pub extend ModuleInterfaceArtifact with @prettyprinter.Pretty::{pretty}

///|
pub extend ModuleInterfaceArtifact with Debug::{to_repr}

///|
pub extend ModuleInterfaceArtifact with Eq::{not_equal, equal}

///|
pub extend ModuleObjectArtifact with @prettyprinter.Pretty::{pretty}

///|
pub extend ModuleObjectArtifact with Debug::{to_repr}

///|
pub extend ModuleObjectArtifact with Eq::{not_equal, equal}

///|
pub extend WasmExecutableError with Debug::{to_repr}

///|
pub extend WasmExecutableError with Eq::{not_equal, equal}

///|
pub extend WasmArtifactCertificationError with Debug::{to_repr}

///|
pub extend WasmArtifactCertificationError with Eq::{not_equal, equal}

///|
pub extend VerifiedWasmExecutable with Debug::{to_repr}

///|
pub extend VerifiedWasmExecutable with Eq::{not_equal, equal}
