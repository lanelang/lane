///|
priv struct Resolver {
  registry : SymbolRegistry
  declaration_symbols : @symbol.DeclarationSymbolScope
  canonical_basic_abi : @canonical_basic_abi.CanonicalBasicAbiIdentityCatalogBuilder
  canonical_basic_abi_demands : Array[
    @canonical_basic_abi.CanonicalBasicAbiDemand,
  ]
  local_module : LocalModuleNamespace
  imported_modules : Array[ImportedModule]
  module_bindings : Array[ModuleBinding]
  types : Array[TypeBinding]
  effects : Array[EffectBinding]
  type_aliases : Array[TypeAliasBinding]
  top_values : Array[ValueBinding]
  ordered_top_values : Array[ValueBinding]
  conflicting_top_value_names : Array[String]
  import_exposures : Array[ResolvedImportExposure]
  import_uses : Array[ResolvedImportUse]
  import_symbols : Array[ResolvedImportExposureSymbol]
  public_exports : Array[ResolvedPublicExport]
  module_binding_references : Array[ResolvedModuleBindingReference]
  diagnostics : Array[ResolveDiagnostic]
}

///|
priv struct ImportedModule {
  path_text : String
  bindings : Array[@module_interface.ResolvedModuleInterfaceExport]
  provider_origins : Array[Int]
}

///|
priv struct ModuleBinding {
  name_text : String
  imported : ImportedModule
  import_origin : Int?
}

///|
priv struct LocalModuleNamespace {
  path_text : String
  name_loc : SourceSpan
  types : Array[TypeBinding]
  effects : Array[EffectBinding]
  type_aliases : Array[TypeAliasBinding]
}

///|
priv enum ModuleNamespaceSource {
  LocalModule(LocalModuleNamespace)
  ImportedModule(
    imported~ : ImportedModule,
    import_origins~ : Array[Int],
    authored_binding_origin~ : Int?
  )
}

///|
priv enum ModuleTypeBindingKind {
  NominalType(symbol~ : TypeSymbolId, variants~ : Array[VariantBinding])
  EffectType(EffectSymbolId)
  TypeAlias(symbol~ : TypeAliasSymbolId, is_effect~ : Bool)
}

///|
priv struct ModuleTypeBinding {
  owner_module_path : String
  parameter_kinds : Array[@types.Kind]
  kind : ModuleTypeBindingKind
  import_origins : Array[Int]
}

///|
priv struct VariantBinding {
  name : String
  symbol : VariantSymbolId
}

///|
priv struct FieldBinding {
  name : String
  symbol : FieldSymbolId
}

///|
priv struct OperationBinding {
  name : String
  symbol : OperationSymbolId
}

///|
priv struct TypeBinding {
  name : String
  symbol : TypeSymbolId
  parameter_kinds : Array[@types.Kind]
  type_members : Array[String]
  fields : Array[FieldBinding]
  variants : Array[VariantBinding]
  import_origin : Int?
}

///|
priv struct EffectBinding {
  name : String
  symbol : EffectSymbolId
  parameter_kinds : Array[@types.Kind]
  operations : Array[OperationBinding]
  import_origin : Int?
}

///|
priv struct TypeAliasBinding {
  symbol : TypeAliasSymbolId
  name : String
  owner_module_path : String?
  is_effect : Bool
  parameter_kinds : Array[@types.Kind]
  import_origin : Int?
}

///|

///|
/// Resolves a syntax source file and returns diagnostics with the result.
///
/// Example: resolving `fn f(x : Missing) -> Int { x }` records an unresolved
/// type diagnostic while still returning a resolved tree for later phases.
pub fn resolve_source_file_result(source : @syntax.SourceFile) -> ResolveResult {
  let registry = SymbolRegistry()
  let resolver = Resolver::Resolver(
    registry,
    None,
    source.module_path,
    ModuleInterfaceCatalog(),
  )
  resolver.resolve_source_file_result(source)
}

///|
/// Resolves a source file inside one compiler invocation registry and with
/// imported module interfaces and their reachable declaration providers
/// available. Only modules named by the source are published; the wider
/// catalog exists so flattened public exports can resolve their providers.
pub fn resolve_source_file_with_imports_result(
  source : @syntax.SourceFile,
  registry : SymbolRegistry,
  imported_environment : @module_interface.ModuleInterfaceCatalog,
  previous_declarations? : @symbol.DeclarationIdentities? = None,
) -> ResolveResult {
  let resolver = Resolver::Resolver(
    registry,
    previous_declarations,
    source.module_path,
    imported_environment,
  )
  resolver.publish_imported_bindings(source, imported_environment)
  resolver.resolve_source_file_result(source)
}

///|
fn Resolver::resolve_source_file_result(
  self : Resolver,
  source : @syntax.SourceFile,
) -> ResolveResult {
  // Headers and nominal members are collected before declaration bodies so
  // top-level functions, structs, enums, fields, and variants can be recursive.
  self.collect_top_level_headers(source)
  self.validate_local_public_export_collisions(source)
  self.collect_nominal_members(source)
  let declarations = source.declarations.map(fn(declaration) {
    declaration.resolve_top_level(self)
  })
  let resolved = {
    module_path: source.module_path,
    symbols: self.registry,
    canonical_basic_abi: self.canonical_basic_abi.build(),
    canonical_basic_abi_demands: self.canonical_basic_abi_demands.copy(),
    import_exposures: self.import_exposures,
    import_uses: self.import_uses,
    import_symbols: self.import_symbols,
    public_exports: self.public_exports,
    module_binding_references: self.module_binding_references,
    declarations,
    loc: source.loc,
  }
  { source: resolved, diagnostics: self.diagnostics, }
}

///|
fn Resolver::validate_local_public_export_collisions(
  self : Resolver,
  source : @syntax.SourceFile,
) -> Unit {
  for declaration in source.declarations {
    guard syntax_public_export_key(declaration)
      is Some((export_namespace, name, loc)) else {
      continue
    }
    for existing in self.public_exports {
      if existing.export_.export_namespace == export_namespace &&
        existing.export_.exposed_name == name {
        self.report(
          ConflictingPublicExport(
            name~,
            export_namespace~,
            existing_loc=existing.loc,
          ),
          loc,
        )
      }
    }
  }
}

///|
fn syntax_public_export_key(
  declaration : @syntax.TopLevelDeclaration,
) -> (@module_interface.ModuleInterfaceExportNamespace, String, SourceSpan)? {
  match declaration {
    Struct(declaration) if declaration.is_public =>
      Some((TypeNamespace, declaration.name, declaration.name_loc))
    Enum(declaration) if declaration.is_public =>
      Some((TypeNamespace, declaration.name, declaration.name_loc))
    Effect(declaration) if declaration.is_public =>
      Some((EffectNamespace, declaration.name, declaration.name_loc))
    ExternalType(declaration) if declaration.is_public =>
      Some(
        (
          if declaration.result_kind is Type(_) {
            TypeNamespace
          } else {
            EffectNamespace
          },
          declaration.name,
          declaration.name_loc,
        ),
      )
    TypeAlias(declaration) if declaration.is_public =>
      Some(
        (
          if declaration.body is EffectBody(_) {
            EffectNamespace
          } else {
            TypeNamespace
          },
          declaration.name,
          declaration.name_loc,
        ),
      )
    Function(declaration) if declaration.is_public =>
      Some((ValueNamespace, declaration.name, declaration.name_loc))
    Let(declaration) if declaration.is_public =>
      Some((ValueNamespace, declaration.name, declaration.name_loc))
    _ => None
  }
}

///|
fn Resolver::Resolver(
  registry : SymbolRegistry,
  previous_declarations : @symbol.DeclarationIdentities?,
  current_module : @syntax.ModulePath,
  imported_environment : @module_interface.ModuleInterfaceCatalog,
) -> Resolver {
  {
    registry,
    declaration_symbols: registry.declaration_scope(
      previous=previous_declarations,
    ),
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbiIdentityCatalogBuilder::from_interfaces(
      imported_environment,
    ),
    canonical_basic_abi_demands: [],
    local_module: {
      path_text: @module_interface.module_path_text(current_module),
      name_loc: current_module.loc,
      types: [],
      effects: [],
      type_aliases: [],
    },
    imported_modules: [],
    module_bindings: [],
    types: [],
    effects: [],
    type_aliases: [],
    top_values: [],
    ordered_top_values: [],
    conflicting_top_value_names: [],
    import_exposures: [],
    import_uses: [],
    import_symbols: [],
    public_exports: [],
    module_binding_references: [],
    diagnostics: [],
  }
}
