///|
fn SemanticChecker::validate_canonical_basic_abi_demands(
  self : SemanticChecker,
) -> Bool {
  let diagnostics = self.canonical_basic_abi.diagnose_demands(
    self.resolved_source.canonical_basic_abi_demands,
  )
  for diagnostic in diagnostics {
    self.report_canonical_basic_abi_diagnostic(diagnostic)
  }
  diagnostics.is_empty()
}

///|
fn SemanticChecker::canonical_basic_void_type(
  self : SemanticChecker,
  loc : SourceSpan,
) -> @types.Type? {
  match self.canonical_basic_abi.void_type_symbol() {
    Ok(symbol) => Some(Constructor(symbol))
    Err(error) => {
      self.report_canonical_basic_abi_diagnostic(error.at(loc))
      None
    }
  }
}

///|
fn SemanticChecker::structural_derive_abi(
  self : SemanticChecker,
  loc : SourceSpan,
) -> @checked.CheckedDeriveAbi? {
  match self.canonical_basic_abi.derive_abi() {
    Ok(abi) => Some(abi)
    Err(error) => {
      self.report_canonical_basic_abi_diagnostic(error.at(loc))
      None
    }
  }
}

///|
fn SemanticChecker::report_canonical_basic_abi_diagnostic(
  self : SemanticChecker,
  diagnostic : @canonical_basic_abi.CanonicalBasicAbiDiagnostic,
) -> Unit {
  self.diagnostics.push({
    kind: CanonicalBasicAbi(diagnostic),
    loc: diagnostic.loc,
  })
}
