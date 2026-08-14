///|
fn SemanticChecker::canonical_basic_struct(
  self : SemanticChecker,
  provider : @abi.BasicTypeProvider,
) -> CheckedStructDeclaration? {
  guard self.canonical_basic_type_symbol(provider) is Some(symbol) else {
    return None
  }
  self.declarations.checked_struct(symbol)
}

///|
fn SemanticChecker::canonical_basic_enum(
  self : SemanticChecker,
  provider : @abi.BasicTypeProvider,
) -> CheckedEnumDeclaration? {
  guard self.canonical_basic_type_symbol(provider) is Some(symbol) else {
    return None
  }
  self.declarations.checked_enum(symbol)
}

///|
fn SemanticChecker::canonical_basic_type_symbol(
  self : SemanticChecker,
  provider : @abi.BasicTypeProvider,
) -> TypeSymbolId? {
  let module_path = provider.module_path()
  let name = provider.type_name()
  if self.resolved_source.module_path.components.join(".") == module_path {
    for declaration in self.resolved_source.declarations {
      match declaration {
        Struct(declaration) if declaration.name == name =>
          return Some(declaration.symbol)
        Enum(declaration) if declaration.name == name =>
          return Some(declaration.symbol)
        ExternalType(declaration) if declaration.name == name =>
          return Some(declaration.symbol)
        _ => ()
      }
    }
    return None
  }
  guard self.imported_environment.find(module_path) is Some(interface) else {
    return None
  }
  for type_ in interface.types {
    match type_ {
      Struct(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      Enum(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      External(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      _ => ()
    }
  }
  None
}

///|
fn SemanticChecker::canonical_basic_void_declaration(
  self : SemanticChecker,
  loc : SourceSpan,
) -> CheckedEnumDeclaration? {
  let provider = @abi.BasicTypeProvider::Void
  guard self.canonical_basic_enum(provider) is Some(declaration) else {
    self.diagnostics.push({
      kind: InvalidCanonicalBasicProvider(
        provider=provider.qualified_name(),
        reason="the required public empty enum is missing",
      ),
      loc,
    })
    return None
  }
  guard declaration.is_public &&
    declaration.type_parameters.is_empty() &&
    declaration.variants.is_empty() else {
    self.diagnostics.push({
      kind: InvalidCanonicalBasicProvider(
        provider=provider.qualified_name(),
        reason="the declaration must be a public enum with no type parameters or variants",
      ),
      loc,
    })
    return None
  }
  Some(declaration)
}

///|
fn SemanticChecker::canonical_basic_void_type(
  self : SemanticChecker,
  loc : SourceSpan,
) -> @types.Type? {
  guard self.canonical_basic_void_declaration(loc) is Some(declaration) else {
    return None
  }
  Some(Constructor(declaration.symbol))
}
