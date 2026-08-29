///|
/// A source-order semantic result that stopped after name resolution.
pub struct SourceResolutionFailure {
  priv resolved : @resolve.ResolvedSourceFile
  priv diagnostics : Array[@compiler_diag.CompilerDiagnostic]
}

///|
/// A source-order semantic result that stopped after type checking.
pub struct SourceTypecheckFailure {
  priv resolved : @resolve.ResolvedSourceFile
  priv diagnostics : Array[@compiler_diag.CompilerDiagnostic]
}

///|
/// The complete source-order semantic result shared by batch compilation and
/// incremental analysis. Its private construction keeps resolved source,
/// checked source, certified interface, and exported symbols inseparable.
pub struct SuccessfulSourceElaboration {
  priv resolved : @resolve.ResolvedSourceFile
  priv checked : @checked.CheckedSourceFile
  priv interface : @module_interface.ModuleInterface
  priv exported_symbols : @symbol.SymbolMetadataArena
  priv warnings : Array[@compiler_diag.CompilerDiagnostic]
}

///|
/// A resolver/typechecker contract violation, retained as a typed compiler
/// defect rather than reclassified as a source diagnostic.
pub(all) enum SourceElaborationCompilerDefectCause {
  InvalidTypecheckInput(@typecheck.TypeCheckError)
  IncompleteTypecheckOutput
} derive(Debug, Eq)

///|
pub struct SourceElaborationCompilerDefect {
  priv source_id : String
  priv resolved : @resolve.ResolvedSourceFile
  priv cause : SourceElaborationCompilerDefectCause
}

///|
/// The complete outcome of elaborating one parsed module in source order.
pub(all) enum SourceElaborationOutcome {
  ResolutionFailed(SourceResolutionFailure)
  TypecheckFailed(SourceTypecheckFailure)
  Succeeded(SuccessfulSourceElaboration)
  CompilerDefect(SourceElaborationCompilerDefect)
}

///|
pub fn SuccessfulSourceElaboration::checked_source(
  self : SuccessfulSourceElaboration,
) -> @checked.CheckedSourceFile {
  self.checked
}

///|
pub fn SuccessfulSourceElaboration::module_interface(
  self : SuccessfulSourceElaboration,
) -> @module_interface.ModuleInterface {
  self.interface
}

///|
pub fn SuccessfulSourceElaboration::exported_symbols(
  self : SuccessfulSourceElaboration,
) -> @symbol.SymbolMetadataArena {
  self.exported_symbols
}

///|
pub fn SuccessfulSourceElaboration::warnings(
  self : SuccessfulSourceElaboration,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  self.warnings.copy()
}

///|
pub fn SourceElaborationCompilerDefect::cause(
  self : SourceElaborationCompilerDefect,
) -> SourceElaborationCompilerDefectCause {
  self.cause
}

///|
pub fn SourceElaborationCompilerDefect::diagnostic(
  self : SourceElaborationCompilerDefect,
) -> @compiler_diag.CompilerDiagnostic {
  source_elaboration_compiler_defect_diagnostic(self.cause).with_source_id(
    self.source_id,
  )
}

///|
pub fn SourceElaborationOutcome::resolved_source(
  self : SourceElaborationOutcome,
) -> @resolve.ResolvedSourceFile {
  match self {
    ResolutionFailed(failure) => failure.resolved
    TypecheckFailed(failure) => failure.resolved
    Succeeded(success) => success.resolved
    CompilerDefect(defect) => defect.resolved
  }
}

///|
pub fn SourceElaborationOutcome::diagnostics(
  self : SourceElaborationOutcome,
) -> Array[@compiler_diag.CompilerDiagnostic] {
  match self {
    ResolutionFailed(failure) => failure.diagnostics.copy()
    TypecheckFailed(failure) => failure.diagnostics.copy()
    Succeeded(success) => success.warnings()
    CompilerDefect(defect) => [defect.diagnostic()]
  }
}
