///|
pub(all) struct CanonicalBasicAbiDiagnostic {
  error : CanonicalBasicAbiError
  loc : @basic.SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CanonicalBasicAbiDemand {
  provider : CanonicalBasicAbiProvider
  loc : @basic.SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum CanonicalBasicAbiProvider {
  TypeProvider(@abi.BasicTypeProvider)
  ValueProvider(@abi.BasicValueProvider)
} derive(Debug, Eq, Hash)

///|
pub fn CanonicalBasicAbiError::at(
  self : CanonicalBasicAbiError,
  loc : @basic.SourceSpan,
) -> CanonicalBasicAbiDiagnostic {
  { error: self, loc, }
}

///|
pub fn CanonicalBasicAbi::diagnose_demands(
  self : CanonicalBasicAbi,
  demands : Array[CanonicalBasicAbiDemand],
) -> Array[CanonicalBasicAbiDiagnostic] {
  let diagnostics = []
  let seen : @hashset.HashSet[CanonicalBasicAbiProvider] = HashSet([])
  for demand in demands {
    if seen.contains(demand.provider) {
      continue
    }
    seen.add(demand.provider)
    let error = match demand.provider {
      TypeProvider(provider) =>
        match self.validate_provider(provider) {
          Ok(_) => None
          Err(error) => Some(error)
        }
      ValueProvider(provider) =>
        match self.validate_value_provider(provider) {
          Ok(_) => None
          Err(error) => Some(error)
        }
    }
    if error is Some(error) {
      diagnostics.push(error.at(demand.loc))
    }
  }
  diagnostics
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
    InvalidValueProvider(provider~, reason~) =>
      @compiler_diag.compiler_error(
        "invalid canonical Basic provider `\{provider.qualified_name()}`",
        span~,
        code=Some("E3039"),
        labels=[@compiler_diag.compiler_primary_label(diagnostic.loc, reason)],
        notes=[
          "compiler-owned operator syntax requires the named public Basic value",
        ],
        helps=[
          "import `Basic.Ops` or a facade that re-exports the required operator value",
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
    InvalidValueProvider(provider~, reason~) =>
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

///|
pub impl @prettyprinter.Pretty for CanonicalBasicAbiDiagnostic with fn pretty(
  diagnostic : CanonicalBasicAbiDiagnostic,
) {
  diagnostic.error.pretty()
}
