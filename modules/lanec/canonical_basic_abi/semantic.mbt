///|
pub(all) enum CanonicalBasicAbiError {
  InvalidProvider(provider~ : @abi.BasicTypeProvider, reason~ : String)
  InvalidStructuralDerivation(reason~ : String)
} derive(Debug, Eq)

///|
pub struct CanonicalBasicAbi {
  tuple : Result[@symbol.TypeSymbolId, CanonicalBasicAbiError]
  list : Result[@symbol.TypeSymbolId, CanonicalBasicAbiError]
  void_declaration : Result[
    @module_interface.ModuleInterfaceEnum,
    CanonicalBasicAbiError,
  ]
  structural_derive : Result[@checked.CheckedDeriveAbi, CanonicalBasicAbiError]
}

///|
pub fn CanonicalBasicAbi::from_module_input(
  identities : CanonicalBasicAbiIdentityCatalog,
  imported : @module_interface.ModuleInterfaceCatalog,
  current : Array[@module_interface.ModuleInterfaceType],
) -> CanonicalBasicAbi {
  let declarations = []
  for interface in imported.modules {
    declarations.append(interface.types)
  }
  declarations.append(current)
  let void_declaration = validate_canonical_void(identities, declarations)
  {
    tuple: validate_canonical_tuple(identities, declarations),
    list: validate_canonical_list(identities, declarations),
    void_declaration,
    structural_derive: validate_structural_derive_abi(
      identities, declarations, void_declaration,
    ),
  }
}

///|
pub fn CanonicalBasicAbi::validate_provider(
  self : CanonicalBasicAbi,
  provider : @abi.BasicTypeProvider,
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  match provider {
    Tuple => self.tuple
    List => self.list
    Void => self.void_type_symbol()
    Deriver => self.structural_derive.map(fn(abi) { abi.deriver })
    Product => self.structural_derive.map(fn(abi) { abi.product })
    Sum => self.structural_derive.map(fn(abi) { abi.sum })
    Iso => self.structural_derive.map(fn(abi) { abi.iso })
    TypeInfo => self.structural_derive.map(fn(abi) { abi.type_info })
    FieldInfo => self.structural_derive.map(fn(abi) { abi.field_info })
    VariantInfo => self.structural_derive.map(fn(abi) { abi.variant_info })
  }
}

///|
pub fn CanonicalBasicAbi::void_type_symbol(
  self : CanonicalBasicAbi,
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  match self.void_declaration {
    Ok(declaration) => Ok(declaration.symbol)
    Err(error) => Err(error)
  }
}

///|
pub fn CanonicalBasicAbi::derive_abi(
  self : CanonicalBasicAbi,
) -> Result[@checked.CheckedDeriveAbi, CanonicalBasicAbiError] {
  self.structural_derive
}

///|
pub fn CanonicalBasicAbi::checked_contract(
  self : CanonicalBasicAbi,
) -> @checked.CheckedCanonicalBasicAbi {
  let types = []
  for provider in basic_type_providers() {
    if self.validate_provider(provider) is Ok(symbol) {
      types.push(@checked.CheckedCanonicalBasicType::{ provider, symbol })
    }
  }
  { types, }
}

///|
fn checked_struct(
  declarations : Array[@module_interface.ModuleInterfaceType],
  symbol : @symbol.TypeSymbolId,
) -> @module_interface.ModuleInterfaceStruct? {
  for declaration in declarations {
    if declaration is Struct(declaration) && declaration.symbol == symbol {
      return Some(declaration)
    }
  }
  None
}

///|
fn checked_enum(
  declarations : Array[@module_interface.ModuleInterfaceType],
  symbol : @symbol.TypeSymbolId,
) -> @module_interface.ModuleInterfaceEnum? {
  for declaration in declarations {
    if declaration is Enum(declaration) && declaration.symbol == symbol {
      return Some(declaration)
    }
  }
  None
}

///|
fn canonical_basic_struct(
  identities : CanonicalBasicAbiIdentityCatalog,
  declarations : Array[@module_interface.ModuleInterfaceType],
  provider : @abi.BasicTypeProvider,
) -> Result[@module_interface.ModuleInterfaceStruct, CanonicalBasicAbiError] {
  guard identities.type_symbol(provider) is Some(symbol) else {
    return Err(
      InvalidProvider(provider~, reason="the required public struct is missing"),
    )
  }
  guard checked_struct(declarations, symbol) is Some(declaration) else {
    return Err(
      InvalidProvider(
        provider~,
        reason="the declaration must be a public struct",
      ),
    )
  }
  Ok(declaration)
}

///|
fn canonical_basic_enum(
  identities : CanonicalBasicAbiIdentityCatalog,
  declarations : Array[@module_interface.ModuleInterfaceType],
  provider : @abi.BasicTypeProvider,
) -> Result[@module_interface.ModuleInterfaceEnum, CanonicalBasicAbiError] {
  guard identities.type_symbol(provider) is Some(symbol) else {
    return Err(
      InvalidProvider(provider~, reason="the required public enum is missing"),
    )
  }
  guard checked_enum(declarations, symbol) is Some(declaration) else {
    return Err(
      InvalidProvider(provider~, reason="the declaration must be a public enum"),
    )
  }
  Ok(declaration)
}

///|
fn validate_canonical_tuple(
  identities : CanonicalBasicAbiIdentityCatalog,
  declarations : Array[@module_interface.ModuleInterfaceType],
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  let provider = @abi.BasicTypeProvider::Tuple
  let declaration = match
    canonical_basic_enum(identities, declarations, provider) {
    Ok(declaration) => declaration
    Err(error) => return Err(error)
  }
  guard declaration.type_parameters is [left, right] &&
    left.kind == Type &&
    right.kind == Type &&
    declaration.variants is [tuple] &&
    identities.variant_symbol(TupleValue) == Some(tuple.symbol) &&
    tuple.name == "tuple" &&
    tuple.type_parameters.is_empty() &&
    tuple.payload == [Parameter(left.id), Parameter(right.id)] else {
    return Err(
      InvalidProvider(
        provider~,
        reason="the declaration must be `enum Tuple[A, B] { tuple(A, B) }`",
      ),
    )
  }
  Ok(declaration.symbol)
}

///|
fn validate_canonical_list(
  identities : CanonicalBasicAbiIdentityCatalog,
  declarations : Array[@module_interface.ModuleInterfaceType],
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  let provider = @abi.BasicTypeProvider::List
  let declaration = match
    canonical_basic_enum(identities, declarations, provider) {
    Ok(declaration) => declaration
    Err(error) => return Err(error)
  }
  guard declaration.type_parameters is [element] &&
    element.kind == Type &&
    declaration.variants is [empty, cons] &&
    identities.variant_symbol(ListEmpty) == Some(empty.symbol) &&
    identities.variant_symbol(ListCons) == Some(cons.symbol) &&
    empty.name == "empty" &&
    empty.type_parameters.is_empty() &&
    empty.payload.is_empty() &&
    cons.name == "cons" &&
    cons.type_parameters.is_empty() &&
    cons.payload ==
    [
      Parameter(element.id),
      Apply(Constructor(declaration.symbol), [
        TypeArgument(Parameter(element.id)),
      ]),
    ] else {
    return Err(
      InvalidProvider(
        provider~,
        reason="the declaration must be `enum List[T] { empty(); cons(T, List[T]) }`",
      ),
    )
  }
  Ok(declaration.symbol)
}

///|
fn validate_canonical_void(
  identities : CanonicalBasicAbiIdentityCatalog,
  declarations : Array[@module_interface.ModuleInterfaceType],
) -> Result[@module_interface.ModuleInterfaceEnum, CanonicalBasicAbiError] {
  let provider = @abi.BasicTypeProvider::Void
  let declaration = match
    canonical_basic_enum(identities, declarations, provider) {
    Ok(declaration) => declaration
    Err(_) =>
      return Err(
        InvalidProvider(
          provider~,
          reason="the required public empty enum is missing",
        ),
      )
  }
  guard declaration.type_parameters.is_empty() &&
    declaration.variants.is_empty() else {
    return Err(
      InvalidProvider(
        provider~,
        reason="the declaration must be a public enum with no type parameters or variants",
      ),
    )
  }
  Ok(declaration)
}
