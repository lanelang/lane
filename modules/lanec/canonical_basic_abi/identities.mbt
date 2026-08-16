///|
pub struct CanonicalBasicAbiIdentityCatalog {
  types : Array[@symbol.TypeSymbolId?]
  variants : Array[@symbol.VariantSymbolId?]
} derive(Debug, Eq)

///|
pub struct CanonicalBasicAbiIdentityCatalogBuilder {
  types : Array[@symbol.TypeSymbolId?]
  variants : Array[@symbol.VariantSymbolId?]
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::from_interfaces(
  interfaces : @module_interface.ModuleInterfaceCatalog,
) -> CanonicalBasicAbiIdentityCatalogBuilder {
  let builder = CanonicalBasicAbiIdentityCatalogBuilder::{
    types: Array::make(basic_type_providers().length(), None),
    variants: Array::make(basic_variant_providers().length(), None),
  }
  for provider in basic_type_providers() {
    guard interfaces.find(provider.module_path()) is Some(interface) else {
      continue
    }
    for type_ in interface.types {
      match type_ {
        Struct(declaration) =>
          if declaration.name == provider.type_name() {
            builder.register_type(provider, declaration.symbol)
          }
        External(declaration) =>
          if declaration.name == provider.type_name() {
            builder.register_type(provider, declaration.symbol)
          }
        Enum(declaration) =>
          if declaration.name == provider.type_name() {
            builder.register_type(provider, declaration.symbol)
            for variant in declaration.variants {
              builder.register_variant(provider, variant.name, variant.symbol)
            }
          }
      }
    }
  }
  builder
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::register_local_type(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  module_path : String,
  name : String,
  symbol : @symbol.TypeSymbolId,
  is_public : Bool,
) -> Unit {
  guard is_public else { return }
  guard basic_type_provider(module_path, name) is Some(provider) else { return }
  self.register_type(provider, symbol)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::register_local_variant(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  module_path : String,
  owner_name : String,
  variant_name : String,
  symbol : @symbol.VariantSymbolId,
) -> Unit {
  guard basic_type_provider(module_path, owner_name) is Some(provider) else {
    return
  }
  guard self.type_symbol(provider) is Some(_) else { return }
  self.register_variant(provider, variant_name, symbol)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::type_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicTypeProvider,
) -> @symbol.TypeSymbolId? {
  self.types[provider.index()]
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::variant_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicVariantProvider,
) -> @symbol.VariantSymbolId? {
  self.variants[provider.index()]
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::build(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
) -> CanonicalBasicAbiIdentityCatalog {
  { types: self.types.copy(), variants: self.variants.copy() }
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::type_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicTypeProvider,
) -> @symbol.TypeSymbolId? {
  self.types[provider.index()]
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::variant_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicVariantProvider,
) -> @symbol.VariantSymbolId? {
  self.variants[provider.index()]
}

///|
fn CanonicalBasicAbiIdentityCatalogBuilder::register_type(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicTypeProvider,
  symbol : @symbol.TypeSymbolId,
) -> Unit {
  let index = provider.index()
  if self.types[index] is None {
    self.types[index] = Some(symbol)
  }
}

///|
fn CanonicalBasicAbiIdentityCatalogBuilder::register_variant(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  owner : @abi.BasicTypeProvider,
  name : String,
  symbol : @symbol.VariantSymbolId,
) -> Unit {
  guard basic_variant_provider(owner, name) is Some(provider) else { return }
  let index = provider.index()
  if self.variants[index] is None {
    self.variants[index] = Some(symbol)
  }
}

///|
fn basic_type_provider(
  module_path : String,
  name : String,
) -> @abi.BasicTypeProvider? {
  for provider in basic_type_providers() {
    if provider.module_path() == module_path && provider.type_name() == name {
      return Some(provider)
    }
  }
  None
}

///|
fn basic_type_providers() -> Array[@abi.BasicTypeProvider] {
  [
    Tuple,
    List,
    Void,
    Deriver,
    Product,
    Sum,
    Iso,
    TypeInfo,
    FieldInfo,
    VariantInfo,
  ]
}

///|
fn @abi.BasicTypeProvider::index(self : @abi.BasicTypeProvider) -> Int {
  for index, provider in basic_type_providers() {
    if provider == self {
      return index
    }
  }
  abort("unregistered canonical Basic type provider")
}

///|
fn @abi.BasicVariantProvider::index(self : @abi.BasicVariantProvider) -> Int {
  for index, provider in basic_variant_providers() {
    if provider == self {
      return index
    }
  }
  abort("unregistered canonical Basic variant provider")
}

///|
fn basic_variant_provider(
  owner : @abi.BasicTypeProvider,
  name : String,
) -> @abi.BasicVariantProvider? {
  for provider in basic_variant_providers() {
    if provider.owner() == owner && provider.variant_name() == name {
      return Some(provider)
    }
  }
  None
}

///|
fn basic_variant_providers() -> Array[@abi.BasicVariantProvider] {
  [TupleValue, ListEmpty, ListCons]
}
