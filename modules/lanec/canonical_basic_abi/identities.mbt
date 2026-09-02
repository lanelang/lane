///|
pub struct CanonicalBasicAbiIdentityCatalog {
  types : Map[@abi.BasicTypeProvider, @symbol.TypeSymbolId]
  variants : Map[@abi.BasicVariantProvider, @symbol.VariantSymbolId]
  values : Map[@abi.BasicValueProvider, @symbol.ValueSymbolId]
} derive(Debug, Eq)

///|
pub struct CanonicalBasicAbiIdentityCatalogBuilder {
  types : Map[@abi.BasicTypeProvider, @symbol.TypeSymbolId]
  variants : Map[@abi.BasicVariantProvider, @symbol.VariantSymbolId]
  values : Map[@abi.BasicValueProvider, @symbol.ValueSymbolId]
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::from_interfaces(
  interfaces : @module_interface.ModuleInterfaceCatalog,
) -> CanonicalBasicAbiIdentityCatalogBuilder {
  let builder = CanonicalBasicAbiIdentityCatalogBuilder::{
    types: Map([]),
    variants: Map([]),
    values: Map([]),
  }
  for provider in @abi.BasicTypeProvider::all() {
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
  for provider in @abi.BasicValueProvider::all() {
    guard interfaces.find(provider.module_path()) is Some(interface) else {
      continue
    }
    for value in interface.values {
      if value.name == provider.value_name() {
        builder.register_value(provider, value.symbol)
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
  guard @abi.BasicTypeProvider::find(module_path, name) is Some(provider) else {
    return
  }
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
  guard @abi.BasicTypeProvider::find(module_path, owner_name) is Some(provider) else {
    return
  }
  guard self.type_symbol(provider) is Some(_) else { return }
  self.register_variant(provider, variant_name, symbol)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::register_local_value(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  module_path : String,
  name : String,
  symbol : @symbol.ValueSymbolId,
  is_public : Bool,
) -> Unit {
  guard is_public else { return }
  guard @abi.BasicValueProvider::find(module_path, name) is Some(provider) else {
    return
  }
  self.register_value(provider, symbol)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::type_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicTypeProvider,
) -> @symbol.TypeSymbolId? {
  self.types.get(provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::require_type_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicTypeProvider,
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  require_type_symbol(self.type_symbol(provider), provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::variant_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicVariantProvider,
) -> @symbol.VariantSymbolId? {
  self.variants.get(provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::value_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicValueProvider,
) -> @symbol.ValueSymbolId? {
  self.values.get(provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::require_value_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicValueProvider,
) -> Result[@symbol.ValueSymbolId, CanonicalBasicAbiError] {
  require_value_symbol(self.value_symbol(provider), provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::require_variant_symbol(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicVariantProvider,
) -> Result[@symbol.VariantSymbolId, CanonicalBasicAbiError] {
  require_variant_symbol(self.variant_symbol(provider), provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalogBuilder::build(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
) -> CanonicalBasicAbiIdentityCatalog {
  {
    types: self.types.copy(),
    variants: self.variants.copy(),
    values: self.values.copy(),
  }
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::type_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicTypeProvider,
) -> @symbol.TypeSymbolId? {
  self.types.get(provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::require_type_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicTypeProvider,
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  require_type_symbol(self.type_symbol(provider), provider)
}

///|
fn require_type_symbol(
  symbol : @symbol.TypeSymbolId?,
  provider : @abi.BasicTypeProvider,
) -> Result[@symbol.TypeSymbolId, CanonicalBasicAbiError] {
  match symbol {
    Some(symbol) => Ok(symbol)
    None =>
      Err(
        InvalidProvider(
          provider~,
          reason="the required public declaration is missing",
        ),
      )
  }
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::variant_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicVariantProvider,
) -> @symbol.VariantSymbolId? {
  self.variants.get(provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::value_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicValueProvider,
) -> @symbol.ValueSymbolId? {
  self.values.get(provider)
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::require_value_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicValueProvider,
) -> Result[@symbol.ValueSymbolId, CanonicalBasicAbiError] {
  require_value_symbol(self.value_symbol(provider), provider)
}

///|
fn require_value_symbol(
  symbol : @symbol.ValueSymbolId?,
  provider : @abi.BasicValueProvider,
) -> Result[@symbol.ValueSymbolId, CanonicalBasicAbiError] {
  match symbol {
    Some(symbol) => Ok(symbol)
    None =>
      Err(
        InvalidValueProvider(
          provider~,
          reason="the required public declaration is missing",
        ),
      )
  }
}

///|
pub fn CanonicalBasicAbiIdentityCatalog::require_variant_symbol(
  self : CanonicalBasicAbiIdentityCatalog,
  provider : @abi.BasicVariantProvider,
) -> Result[@symbol.VariantSymbolId, CanonicalBasicAbiError] {
  require_variant_symbol(self.variant_symbol(provider), provider)
}

///|
fn require_variant_symbol(
  symbol : @symbol.VariantSymbolId?,
  provider : @abi.BasicVariantProvider,
) -> Result[@symbol.VariantSymbolId, CanonicalBasicAbiError] {
  match symbol {
    Some(symbol) => Ok(symbol)
    None =>
      Err(
        InvalidProvider(
          provider=provider.owner(),
          reason="the required public declaration is missing",
        ),
      )
  }
}

///|
fn CanonicalBasicAbiIdentityCatalogBuilder::register_type(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicTypeProvider,
  symbol : @symbol.TypeSymbolId,
) -> Unit {
  if self.types.get(provider) is None {
    self.types[provider] = symbol
  }
}

///|
fn CanonicalBasicAbiIdentityCatalogBuilder::register_variant(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  owner : @abi.BasicTypeProvider,
  name : String,
  symbol : @symbol.VariantSymbolId,
) -> Unit {
  guard @abi.BasicVariantProvider::find(owner, name) is Some(provider) else {
    return
  }
  if self.variants.get(provider) is None {
    self.variants[provider] = symbol
  }
}

///|
fn CanonicalBasicAbiIdentityCatalogBuilder::register_value(
  self : CanonicalBasicAbiIdentityCatalogBuilder,
  provider : @abi.BasicValueProvider,
  symbol : @symbol.ValueSymbolId,
) -> Unit {
  if self.values.get(provider) is None {
    self.values[provider] = symbol
  }
}
