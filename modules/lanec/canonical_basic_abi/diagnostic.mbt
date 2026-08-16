///|
pub(all) struct CanonicalBasicAbiDiagnostic {
  error : CanonicalBasicAbiError
  loc : @basic.SourceSpan
} derive(Debug, Eq)

///|
pub fn CanonicalBasicAbiError::at(
  self : CanonicalBasicAbiError,
  loc : @basic.SourceSpan,
) -> CanonicalBasicAbiDiagnostic {
  { error: self, loc }
}

///|
pub impl @compiler_diag.ToCompilerDiagnostic for CanonicalBasicAbiDiagnostic with fn to_compiler_diagnostic(
  diagnostic : CanonicalBasicAbiDiagnostic,
  context : @compiler_diag.DiagnosticContext,
) -> @compiler_diag.CompilerDiagnostic {
  let span = Some(diagnostic.loc)
  match diagnostic.error {
    InvalidProvider(provider~, reason~) =>
      @compiler_diag.compiler_error(
        "invalid canonical Basic provider `\{provider.qualified_name()}`",
        span~,
        code=Some("E3039"),
        labels=[@compiler_diag.compiler_primary_label(diagnostic.loc, reason)],
        notes=[
          "compiler-owned language features require the declared canonical Basic ABI",
        ],
        helps=[
          "provide the canonical Basic module and declaration with the required public shape",
        ],
        context~,
      )
    InvalidStructuralDerivation(reason~) =>
      @compiler_diag.compiler_error(
        "invalid structural derivation interface",
        span~,
        code=Some("E3032"),
        labels=[@compiler_diag.compiler_primary_label(diagnostic.loc, reason)],
        notes=[],
        helps=[
          "provide the canonical structural derivation interfaces required by the language",
        ],
        context~,
      )
  }
}

///|
pub impl @prettyprinter.Pretty for CanonicalBasicAbiError with fn pretty(
  error : CanonicalBasicAbiError,
) {
  match error {
    InvalidProvider(provider~, reason~) =>
      @prettyprinter.text("invalid_canonical_basic_provider") +
      @prettyprinter.space +
      @prettyprinter.text(provider.qualified_name()) +
      @prettyprinter.space +
      @prettyprinter.text(reason)
    InvalidStructuralDerivation(reason~) =>
      @prettyprinter.text("invalid_structural_derivation_interface") +
      @prettyprinter.space +
      @prettyprinter.text(reason)
  }
}
