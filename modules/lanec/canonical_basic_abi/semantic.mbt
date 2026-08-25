///|
pub(all) enum CanonicalBasicAbiError {
  InvalidProvider(provider~ : @abi.BasicTypeProvider, reason~ : String)
  InvalidStructuralDerivation(reason~ : String)
} derive(Debug, Eq)

///|
pub struct CanonicalBasicAbi {
  providers : Map[
    @abi.BasicTypeProvider,
    Result[@symbol.TypeSymbolId, CanonicalBasicAbiError],
  ]
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
  let tuple = validate_canonical_tuple(identities, declarations)
  let list = validate_canonical_list(identities, declarations)
  let structural_derive = validate_structural_derive_abi(
    identities, declarations, void_declaration,
  )
  let providers : Map[
    @abi.BasicTypeProvider,
    Result[@symbol.TypeSymbolId, CanonicalBasicAbiError],
  ] = Map([])
  for provider in @abi.BasicTypeProvider::all() {
    providers[provider] = certified_provider_type(
      provider, tuple, list, void_declaration, structural_derive,
    )
  }
  { providers, void_declaration, structural_derive, }
}

///|
fn certified_provider_type(
  provider : @abi.BasicTypeProvider,
  tuple : Result[@symbol.TypeSymbolId, CanonicalBasicAbiError],
  list : Result[@symbol.TypeSymbolId, CanonicalBasicAbiError],
  void_declaration : Result[
    @module_interface.ModuleInterfaceEnum,
    CanonicalBasicAbiError,
  ],
  structural_derive : Result[@checked.CheckedDeriveAbi, CanonicalBasicAbiError],
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  match provider {
    Tuple => tuple
    List => list
    Void => void_declaration.map(declaration => declaration.symbol)
    Deriver => structural_derive.map(abi => abi.deriver)
    Product => structural_derive.map(abi => abi.product)
    Sum => structural_derive.map(abi => abi.sum)
    Iso => structural_derive.map(abi => abi.iso)
    TypeInfo => structural_derive.map(abi => abi.type_info)
    FieldInfo => structural_derive.map(abi => abi.field_info)
    VariantInfo => structural_derive.map(abi => abi.variant_info)
  }
}

///|
pub fn CanonicalBasicAbi::validate_provider(
  self : CanonicalBasicAbi,
  provider : @abi.BasicTypeProvider,
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  match self.providers.get(provider) {
    Some(result) => result
    None =>
      Err(
        InvalidProvider(
          provider~,
          reason="the provider is absent from the canonical Basic ABI contract",
        ),
      )
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
  for provider in @abi.BasicTypeProvider::all() {
    if self.validate_provider(provider) is Ok(symbol) {
      types.push(@checked.CheckedCanonicalBasicType::{ provider, symbol, })
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
