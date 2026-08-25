///|
fn qualified_import_binding(
  module_path : @syntax.ModulePath,
  module_alias : @syntax.ModuleAlias?,
) -> (String, SourceSpan) {
  match module_alias {
    Some(module_alias) => (module_alias.name, module_alias.name_loc)
    None => (@module_interface.module_path_text(module_path), module_path.loc)
  }
}

///|
fn Resolver::publish_imported_bindings(
  self : Resolver,
  source : @syntax.SourceFile,
  imported_environment : @module_interface.ModuleInterfaceCatalog,
) -> Unit {
  let conflicting_qualified_imports = self.validate_qualified_imports(source)
  for import_ in source.imports {
    match import_ {
      Qualified(module_path~, module_alias~, loc~) => {
        let (binding_name, binding_loc) = qualified_import_binding(
          module_path, module_alias,
        )
        if binding_name != self.local_module.path_text &&
          !conflicting_qualified_imports.contains(binding_name) {
          self.publish_qualified_import(
            binding_name, binding_loc, module_path, loc, imported_environment,
          )
        }
      }
      Open(module_path~, loc~) => {
        let module_path_text = @module_interface.module_path_text(module_path)
        let bindings = imported_environment.public_exports(module_path_text)
        if imported_environment.find(module_path_text) is Some(_) {
          let open_origin = self.define_import_exposure(
            module_path_text,
            OpenBinding,
            loc,
          )
          ignore(
            self.register_imported_module(
              module_path_text,
              bindings,
              provider_origin=Some(open_origin),
            ),
          )
          self.publish_imported_public_bindings(
            bindings,
            loc,
            Some(open_origin),
          )
        }
      }
      Selective(module_path~, items~, is_public~, loc~) => {
        let module_path_text = @module_interface.module_path_text(module_path)
        if imported_environment.find(module_path_text) is Some(_) {
          let bindings = imported_environment.public_exports(module_path_text)
          ignore(
            self.register_imported_module(
              module_path_text,
              bindings,
              provider_origin=None,
            ),
          )
          self.publish_selective_import(
            module_path_text, bindings, items, is_public,
          )
        } else {
          ignore(loc)
        }
      }
    }
  }
}

///|
fn Resolver::validate_qualified_imports(
  self : Resolver,
  source : @syntax.SourceFile,
) -> @hashset.HashSet[String] {
  let conflicting_bindings : @hashset.HashSet[String] = HashSet([])
  let first_binding_locs : Map[String, SourceSpan] = Map([])
  for import_ in source.imports {
    if import_ is Qualified(module_path~, module_alias~, ..) {
      let (binding_name, binding_loc) = qualified_import_binding(
        module_path, module_alias,
      )
      if binding_name == self.local_module.path_text {
        self.report(
          AmbiguousModuleBinding(
            name=binding_name,
            existing_loc=self.local_module.name_loc,
          ),
          binding_loc,
        )
      } else {
        match first_binding_locs.get(binding_name) {
          Some(existing_loc) => {
            conflicting_bindings.add(binding_name)
            self.report(
              AmbiguousModuleBinding(name=binding_name, existing_loc~),
              binding_loc,
            )
          }
          None => first_binding_locs[binding_name] = binding_loc
        }
      }
    }
  }
  conflicting_bindings
}

///|
fn Resolver::define_import_exposure(
  self : Resolver,
  module_path_text : String,
  kind : ResolvedImportExposureKind,
  loc : SourceSpan,
) -> Int {
  let id = self.import_exposures.length()
  self.import_exposures.push({ id, module_path_text, kind, loc, })
  id
}

///|
fn Resolver::record_import_use(
  self : Resolver,
  origin : Int?,
  loc : SourceSpan,
) -> Unit {
  if origin is Some(exposure_id) {
    if !self.import_uses.any(fn(use_) {
        use_.exposure_id == exposure_id && use_.loc == loc
      }) {
      self.import_uses.push({ exposure_id, loc, })
    }
  }
}

///|
fn Resolver::record_import_uses(
  self : Resolver,
  origins : Array[Int],
  loc : SourceSpan,
) -> Unit {
  for origin in origins {
    self.record_import_use(Some(origin), loc)
  }
}

///|
fn Resolver::record_module_binding_reference(
  self : Resolver,
  exposure_id : Int?,
  loc : SourceSpan,
) -> Unit {
  if exposure_id is Some(exposure_id) {
    self.record_import_use(Some(exposure_id), loc)
    if !self.module_binding_references.any(fn(reference) {
        reference.exposure_id == exposure_id && reference.loc == loc
      }) {
      self.module_binding_references.push({ exposure_id, loc, })
    }
  }
}

///|
fn optional_import_origin(origin : Int?) -> Array[Int] {
  match origin {
    Some(origin) => [origin]
    None => []
  }
}

///|
fn Resolver::record_import_symbol(
  self : Resolver,
  origin : Int?,
  symbol : ResolvedImportSymbol,
) -> Unit {
  if origin is Some(exposure_id) {
    if !self.import_symbols.any(fn(item) {
        item.exposure_id == exposure_id && item.symbol == symbol
      }) {
      self.import_symbols.push({ exposure_id, symbol, })
    }
  }
}

///|
fn selective_import_bindings(
  bindings : Array[@module_interface.ResolvedModuleInterfaceExport],
  name : String,
) -> Array[@module_interface.ResolvedModuleInterfaceExport] {
  bindings.filter(fn(binding) { binding.export_.exposed_name == name })
}

///|
fn Resolver::publish_selective_import(
  self : Resolver,
  module_path_text : String,
  public_bindings : Array[@module_interface.ResolvedModuleInterfaceExport],
  items : Array[@syntax.ImportItem],
  is_public : Bool,
) -> Unit {
  for item in items {
    let bindings = selective_import_bindings(public_bindings, item.name)
    if bindings.is_empty() {
      self.report(
        UnresolvedImportItem(module_path=module_path_text, name=item.name),
        item.loc,
      )
      continue
    }
    let origin = self.define_import_exposure(
      module_path_text,
      SelectiveBinding(name=item.name, is_public~),
      item.loc,
    )
    for binding in bindings {
      self.publish_selective_import_binding(binding, Some(origin), item.loc)
      if is_public {
        self.publish_public_export(binding, item.loc)
        self.record_import_use(Some(origin), item.loc)
      }
    }
  }
}

///|
fn Resolver::publish_public_export(
  self : Resolver,
  binding : @module_interface.ResolvedModuleInterfaceExport,
  loc : SourceSpan,
) -> Unit {
  let export_ = binding.export_
  for existing in self.public_exports {
    if existing.export_.export_namespace == export_.export_namespace &&
      existing.export_.exposed_name == export_.exposed_name {
      self.report(
        ConflictingPublicExport(
          name=export_.exposed_name,
          export_namespace=export_.export_namespace,
          existing_loc=existing.loc,
        ),
        loc,
      )
      return
    }
  }
  self.public_exports.push({ export_, declaration: binding.declaration, loc, })
}

///|
fn Resolver::publish_qualified_import(
  self : Resolver,
  binding_name : String,
  binding_loc : SourceSpan,
  module_path : @syntax.ModulePath,
  import_loc : SourceSpan,
  imported_environment : @module_interface.ModuleInterfaceCatalog,
) -> Unit {
  let path_text = @module_interface.module_path_text(module_path)
  guard imported_environment.find(path_text) is Some(_) else { return }
  let bindings = imported_environment.public_exports(path_text)
  let import_origin = self.define_import_exposure(
    path_text,
    QualifiedModuleBinding(name=binding_name, name_loc=binding_loc),
    import_loc,
  )
  let imported = self.register_imported_module(
    path_text,
    bindings,
    provider_origin=Some(import_origin),
  )
  self.module_bindings.push({
    name_text: binding_name,
    imported,
    import_origin: Some(import_origin),
  })
}

///|
fn Resolver::register_imported_module(
  self : Resolver,
  module_path_text : String,
  bindings : Array[@module_interface.ResolvedModuleInterfaceExport],
  provider_origin~ : Int?,
) -> ImportedModule {
  let imported = match self.imported_module(module_path_text) {
    Some(imported) => imported
    None => {
      let imported = ImportedModule::{
        path_text: module_path_text,
        bindings,
        provider_origins: [],
      }
      self.imported_modules.push(imported)
      imported
    }
  }
  if provider_origin is Some(origin) &&
    !imported.provider_origins.contains(origin) {
    imported.provider_origins.push(origin)
  }
  imported
}

///|
fn Resolver::publish_imported_public_bindings(
  self : Resolver,
  bindings : Array[@module_interface.ResolvedModuleInterfaceExport],
  loc : SourceSpan,
  import_origin : Int?,
) -> Unit {
  for binding in bindings {
    self.publish_selective_import_binding(binding, import_origin, loc)
  }
}

///|
fn Resolver::publish_imported_type(
  self : Resolver,
  type_ : @module_interface.ModuleInterfaceType,
  import_origin : Int?,
) -> Unit {
  match type_ {
    Struct(declaration) =>
      self.publish_type_binding(
        declaration.name,
        declaration.symbol,
        interface_type_parameter_kinds(declaration.type_parameters),
        type_members=declaration.type_members.map(fn(item) { item.name }),
        fields=declaration.fields.map(fn(field) {
          { name: field.name, symbol: field.symbol, }
        }),
        import_origin,
      )
    Enum(declaration) =>
      self.publish_type_binding(
        declaration.name,
        declaration.symbol,
        interface_type_parameter_kinds(declaration.type_parameters),
        variants=declaration.variants.map(fn(variant) {
          { name: variant.name, symbol: variant.symbol, }
        }),
        import_origin,
      )
    External(declaration) =>
      self.publish_type_binding(
        declaration.name,
        declaration.symbol,
        [],
        import_origin,
      )
  }
}

///|
fn Resolver::publish_imported_type_alias(
  self : Resolver,
  module_path : String,
  type_alias : @module_interface.ModuleInterfaceTypeAlias,
  import_origin : Int?,
) -> Unit {
  self.type_aliases.push({
    symbol: type_alias.symbol,
    name: type_alias.name,
    owner_module_path: Some(module_path),
    is_effect: type_alias.kind == Effect,
    parameter_kinds: interface_type_parameter_kinds(type_alias.type_parameters),
    import_origin,
  })
}

///|
fn interface_type_parameter_kinds(
  parameters : Array[@types.TypeParameter],
) -> Array[@types.Kind] {
  parameters.map(fn(parameter) { parameter.kind })
}

///|
fn syntax_type_parameter_kinds(
  parameters : Array[@syntax.TypeParameter],
) -> Array[@types.Kind] {
  parameters.map(fn(parameter) {
    match parameter.kind {
      Some(kind) => kind.to_binding_kind()
      None => Type
    }
  })
}

///|
fn @syntax.Kind::to_binding_kind(self : @syntax.Kind) -> @types.Kind {
  match self {
    Type(..) => Type
    Effect(..) => Effect
    Function(parameters~, result~, ..) =>
      Function(
        parameters.map(@syntax.Kind::to_binding_kind),
        result.to_binding_kind(),
      )
    Grouped(kind~, ..) => kind.to_binding_kind()
  }
}

///|
fn Resolver::publish_imported_effect(
  self : Resolver,
  effect : @module_interface.ModuleInterfaceEffect,
  import_origin : Int?,
) -> Unit {
  self.publish_effect_binding(
    effect.name,
    effect.symbol,
    interface_type_parameter_kinds(effect.type_parameters),
    operations=effect.operations.map(fn(operation) {
      { name: operation.name, symbol: operation.symbol, }
    }),
    import_origin,
  )
}

///|
fn Resolver::publish_imported_value(
  self : Resolver,
  provider_module : String,
  provider_source_id : String?,
  value : @module_interface.ModuleInterfaceValue,
  loc : SourceSpan,
  import_origin : Int?,
) -> Unit {
  let binding = imported_interface_value_binding(
    provider_module, provider_source_id, value, import_origin,
  )
  self.publish_complete_top_level_binding(binding, loc)
  self.publish_ordered_top_level_binding(binding, loc)
  self.record_import_symbol(import_origin, ValueSymbol(value.symbol))
}

///|
fn Resolver::publish_selective_import_binding(
  self : Resolver,
  binding : @module_interface.ResolvedModuleInterfaceExport,
  origin : Int?,
  loc : SourceSpan,
) -> Unit {
  match binding.declaration {
    NominalType(type_) => self.publish_imported_type(type_, origin)
    TypeAlias(type_alias) =>
      self.publish_imported_type_alias(
        binding.export_.target.provider_module,
        type_alias,
        origin,
      )
    Effect(effect) => self.publish_imported_effect(effect, origin)
    Value(value) =>
      self.publish_imported_value(
        binding.export_.target.provider_module,
        binding.provider_source_id,
        value,
        loc,
        origin,
      )
  }
}

///|
fn imported_interface_value_binding(
  provider_module : String,
  provider_source_id : String?,
  value : @module_interface.ModuleInterfaceValue,
  import_origin : Int?,
) -> ValueBinding {
  let source = match provider_source_id {
    Some(source_id) => ExternalSource(source_id~)
    None => NoSource(origin="module `\{provider_module}`")
  }
  {
    name: value.name,
    reference: Symbol(value.symbol),
    type_: None,
    kind: Plain,
    source,
    import_origin,
  }
}
