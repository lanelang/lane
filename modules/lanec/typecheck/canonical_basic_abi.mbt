///|
fn CheckedDeclarationEnvironment::canonical_basic_abi_types(
  self : CheckedDeclarationEnvironment,
) -> Array[@module_interface.ModuleInterfaceType] {
  self.types.filter_map(fn(type_) {
    match type_ {
      Struct(declaration) if declaration.is_public =>
        Some(
          Struct({
            symbol: declaration.symbol,
            name: declaration.name,
            type_parameters: declaration.type_parameters,
            type_members: declaration.type_members.map(fn(type_member) {
              {
                symbol: type_member.symbol,
                type_parameter: type_member.type_parameter,
                name: type_member.name,
                kind: type_member.kind,
                index: type_member.index,
                loc: type_member.loc,
              }
            }),
            fields: declaration.fields.map(fn(field) {
              {
                symbol: field.symbol,
                name: field.name,
                index: field.index,
                type_: field.type_,
                loc: field.loc,
              }
            }),
            loc: declaration.loc,
          }),
        )
      Enum(declaration) if declaration.is_public =>
        Some(
          Enum({
            symbol: declaration.symbol,
            name: declaration.name,
            type_parameters: declaration.type_parameters,
            variants: declaration.variants.map(fn(variant) {
              {
                symbol: variant.symbol,
                name: variant.name,
                index: variant.index,
                type_parameters: variant.type_parameters,
                payload: variant.payload,
                loc: variant.loc,
              }
            }),
            loc: declaration.loc,
          }),
        )
      External(declaration) if declaration.is_public =>
        Some(
          External({
            symbol: declaration.symbol,
            name: declaration.name,
            loc: declaration.loc,
          }),
        )
      _ => None
    }
  })
}

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
