///|
pub(all) enum ModuleInterfaceDeclaration {
  NominalType(ModuleInterfaceType)
  TypeAlias(ModuleInterfaceTypeAlias)
  Effect(ModuleInterfaceEffect)
  Value(ModuleInterfaceValue)
} derive(Debug, Eq)

///|
pub(all) struct ResolvedModuleInterfaceExport {
  export_ : ModuleInterfaceExport
  declaration : ModuleInterfaceDeclaration
  provider_source_id : String?
} derive(Debug, Eq)

///|
fn ModuleInterfaceDeclaration::export_namespace(
  self : ModuleInterfaceDeclaration,
) -> ModuleInterfaceExportNamespace {
  match self {
    NominalType(_) => TypeNamespace
    TypeAlias(alias_) =>
      match alias_.body {
        TypeBody(_) => TypeNamespace
        EffectBody(_) => EffectNamespace
      }
    Effect(_) => EffectNamespace
    Value(_) => ValueNamespace
  }
}

///|
fn ModuleInterfaceDeclaration::name(
  self : ModuleInterfaceDeclaration,
) -> String {
  match self {
    NominalType(Struct(declaration)) => declaration.name
    NominalType(Enum(declaration)) => declaration.name
    NominalType(External(declaration)) => declaration.name
    TypeAlias(declaration) => declaration.name
    Effect(declaration) => declaration.name
    Value(declaration) => declaration.name
  }
}

///|
pub fn ModuleInterface::declaration(
  self : ModuleInterface,
  reference : ModuleInterfaceDeclarationRef,
) -> ModuleInterfaceDeclaration? {
  if reference.provider_module != self.module_path {
    return None
  }
  match reference.export_namespace {
    TypeNamespace => {
      for type_ in self.types {
        let name = match type_ {
          Struct(declaration) => declaration.name
          Enum(declaration) => declaration.name
          External(declaration) => declaration.name
        }
        if name == reference.declaration_name {
          return Some(NominalType(type_))
        }
      }
      for alias_ in self.type_aliases {
        if alias_.name == reference.declaration_name &&
          alias_.body is TypeBody(_) {
          return Some(TypeAlias(alias_))
        }
      }
      None
    }
    EffectNamespace => {
      for effect in self.effects {
        if effect.name == reference.declaration_name {
          return Some(Effect(effect))
        }
      }
      for alias_ in self.type_aliases {
        if alias_.name == reference.declaration_name &&
          alias_.body is EffectBody(_) {
          return Some(TypeAlias(alias_))
        }
      }
      None
    }
    ValueNamespace => {
      for value in self.values {
        if value.name == reference.declaration_name {
          return Some(Value(value))
        }
      }
      None
    }
  }
}

///|
fn ModuleInterfaceCatalog::resolve_export(
  self : ModuleInterfaceCatalog,
  export_ : ModuleInterfaceExport,
) -> ResolvedModuleInterfaceExport? {
  guard self.find(export_.target.provider_module) is Some(provider) else {
    return None
  }
  guard provider.declaration(export_.target) is Some(declaration) else {
    return None
  }
  guard provider.declaration_fingerprint(declaration) is Ok(fingerprint) &&
    fingerprint == export_.expected_target_fingerprint else {
    return None
  }
  Some({ export_, declaration, provider_source_id: provider.source_id })
}

///|
pub fn ModuleInterfaceCatalog::public_exports(
  self : ModuleInterfaceCatalog,
  module_path : String,
) -> Array[ResolvedModuleInterfaceExport] {
  guard self.find(module_path) is Some(interface) else { return [] }
  interface.exports.map(fn(export_) {
    match self.resolve_export(export_) {
      Some(resolved) => resolved
      None =>
        abort(
          "invalid public export `\{module_path}.\{export_.exposed_name}` in a validated interface catalog",
        )
    }
  })
}

///|
pub fn ModuleInterface::owned_exports(
  self : ModuleInterface,
) -> Array[ModuleInterfaceExport] {
  let exports = []
  for declaration in self.owned_declarations() {
    let export_namespace = declaration.export_namespace()
    let name = declaration.name()
    let fingerprint = match self.declaration_fingerprint(declaration) {
      Ok(fingerprint) => fingerprint
      Err(message) =>
        abort(
          "invalid provider declaration `\{self.module_path}.\{name}`: \{message}",
        )
    }
    exports.push({
      export_namespace,
      exposed_name: name,
      target: {
        provider_module: self.module_path,
        export_namespace,
        declaration_name: name,
      },
      expected_target_fingerprint: fingerprint,
    })
  }
  exports
}

///|
fn ModuleInterface::owned_declarations(
  self : ModuleInterface,
) -> Array[ModuleInterfaceDeclaration] {
  let declarations = []
  for type_ in self.types {
    declarations.push(NominalType(type_))
  }
  for effect in self.effects {
    declarations.push(Effect(effect))
  }
  for alias_ in self.type_aliases {
    declarations.push(TypeAlias(alias_))
  }
  for value in self.values {
    declarations.push(Value(value))
  }
  declarations
}
