///|
fn SemanticChecker::validate_canonical_basic_abi_demands(
  self : SemanticChecker,
) -> Bool {
  let mut valid = true
  for demand in self.resolved_source.canonical_basic_abi_demands {
    if self.canonical_basic_abi.validate_provider(demand.provider) is Err(error) {
      self.report_canonical_basic_abi_error(error, demand.loc)
      valid = false
    }
  }
  valid
}

///|
fn SemanticChecker::canonical_basic_void_type(
  self : SemanticChecker,
  loc : SourceSpan,
) -> @types.Type? {
  match self.canonical_basic_abi.void_type_symbol() {
    Ok(symbol) => Some(Constructor(symbol))
    Err(error) => {
      self.report_canonical_basic_abi_error(error, loc)
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
      self.report_canonical_basic_abi_error(error, loc)
      None
    }
  }
}

///|
fn SemanticChecker::report_canonical_basic_abi_error(
  self : SemanticChecker,
  error : @canonical_basic_abi.CanonicalBasicAbiError,
  loc : SourceSpan,
) -> Unit {
  let kind = match error {
    InvalidProvider(provider~, reason~) =>
      InvalidCanonicalBasicProvider(provider=provider.qualified_name(), reason~)
    InvalidStructuralDerivation(reason~) =>
      InvalidStructuralDerivationInterface(reason~)
  }
  self.diagnostics.push({ kind, loc })
}
