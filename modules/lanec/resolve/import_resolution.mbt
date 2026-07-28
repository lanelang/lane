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
  imported_environment : @module_interface.ImportedEnvironment,
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
      Open(module_path~, loc~) =>
        match
          imported_environment.find(
            @module_interface.module_path_text(module_path),
          ) {
          Some(imported) => {
            let module_path_text = @module_interface.module_path_text(
              module_path,
            )
            let open_origin = self.define_import_exposure(
              module_path_text,
              OpenBinding,
              loc,
            )
            ignore(
              self.register_imported_module(
                imported,
                provider_origin=Some(open_origin),
              ),
            )
            self.publish_imported_public_types(imported, Some(open_origin))
            self.publish_imported_public_effects(imported, Some(open_origin))
            self.publish_imported_public_values(
              imported,
              loc,
              Some(open_origin),
            )
          }
          None => ()
        }
      Selective(module_path~, items~, loc~) =>
        match
          imported_environment.find(
            @module_interface.module_path_text(module_path),
          ) {
          Some(imported) => {
            ignore(
              self.register_imported_module(imported, provider_origin=None),
            )
            let item_origins = self.define_selective_import_origins(
              imported, items,
            )
            self.publish_imported_selected_types(imported, item_origins)
            self.publish_imported_selected_effects(imported, item_origins)
            self.publish_imported_selected_values(imported, item_origins)
          }
          None => ignore(loc)
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
  self.import_exposures.push({ id, module_path_text, kind, loc })
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
      self.import_uses.push({ exposure_id, loc })
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
      self.module_binding_references.push({ exposure_id, loc })
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
      self.import_symbols.push({ exposure_id, symbol })
    }
  }
}

///|
fn Resolver::define_selective_import_origins(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  items : Array[@syntax.ImportItem],
) -> Array[SelectiveImportOrigin] {
  items.map(fn(item) {
    {
      name: item.name,
      origin: self.define_import_exposure(
        interface.module_path,
        SelectiveBinding(name=item.name),
        item.loc,
      ),
      loc: item.loc,
    }
  })
}

///|
fn Resolver::publish_qualified_import(
  self : Resolver,
  binding_name : String,
  binding_loc : SourceSpan,
  module_path : @syntax.ModulePath,
  import_loc : SourceSpan,
  imported_environment : @module_interface.ImportedEnvironment,
) -> Unit {
  let path_text = @module_interface.module_path_text(module_path)
  guard imported_environment.find(path_text) is Some(interface) else { return }
  let import_origin = self.define_import_exposure(
    path_text,
    QualifiedModuleBinding(name=binding_name, name_loc=binding_loc),
    import_loc,
  )
  let imported = self.register_imported_module(
    interface,
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
  interface : @module_interface.ModuleInterface,
  provider_origin~ : Int?,
) -> ImportedModule {
  let imported = match self.imported_module(interface.module_path) {
    Some(imported) => imported
    None => {
      let imported = ImportedModule::{
        path_text: interface.module_path,
        interface,
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
fn Resolver::publish_imported_public_types(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  import_origin : Int?,
) -> Unit {
  for type_ in interface.types {
    match type_ {
      Struct(declaration) =>
        self.publish_type_binding(
          declaration.name,
          declaration.symbol,
          interface_type_parameter_kinds(declaration.type_parameters),
          type_members=declaration.type_members.map(fn(item) { item.name }),
          fields=declaration.fields.map(fn(field) {
            { name: field.name, symbol: field.symbol }
          }),
          import_origin,
        )
      Enum(declaration) =>
        self.publish_type_binding(
          declaration.name,
          declaration.symbol,
          interface_type_parameter_kinds(declaration.type_parameters),
          variants=declaration.variants.map(fn(variant) {
            { name: variant.name, symbol: variant.symbol }
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
  for type_alias in interface.type_aliases {
    self.type_aliases.push({
      symbol: type_alias.symbol,
      name: type_alias.name,
      owner_module_path: Some(interface.module_path),
      is_effect: type_alias.kind == Effect,
      parameter_kinds: interface_type_parameter_kinds(
        type_alias.type_parameters,
      ),
      import_origin,
    })
  }
}

///|
fn Resolver::publish_imported_public_effects(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  import_origin : Int?,
) -> Unit {
  for effect in interface.effects {
    self.publish_effect_binding(
      effect.name,
      effect.symbol,
      interface_type_parameter_kinds(effect.type_parameters),
      operations=effect.operations.map(fn(operation) {
        { name: operation.name, symbol: operation.symbol }
      }),
      import_origin,
    )
  }
}

///|
fn Resolver::publish_imported_selected_types(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  item_origins : Array[SelectiveImportOrigin],
) -> Unit {
  for item in item_origins {
    for type_ in interface.types {
      match type_ {
        Struct(declaration) if declaration.name == item.name =>
          self.publish_type_binding(
            declaration.name,
            declaration.symbol,
            interface_type_parameter_kinds(declaration.type_parameters),
            type_members=declaration.type_members.map(fn(item) { item.name }),
            fields=declaration.fields.map(fn(field) {
              { name: field.name, symbol: field.symbol }
            }),
            Some(item.origin),
          )
        Enum(declaration) if declaration.name == item.name =>
          self.publish_type_binding(
            declaration.name,
            declaration.symbol,
            interface_type_parameter_kinds(declaration.type_parameters),
            variants=declaration.variants.map(fn(variant) {
              { name: variant.name, symbol: variant.symbol }
            }),
            Some(item.origin),
          )
        _ => ()
      }
    }
    for type_alias in interface.type_aliases {
      if type_alias.name == item.name {
        self.type_aliases.push({
          symbol: type_alias.symbol,
          name: type_alias.name,
          owner_module_path: Some(interface.module_path),
          is_effect: type_alias.kind == Effect,
          parameter_kinds: interface_type_parameter_kinds(
            type_alias.type_parameters,
          ),
          import_origin: Some(item.origin),
        })
      }
    }
  }
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
fn Resolver::publish_imported_selected_effects(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  item_origins : Array[SelectiveImportOrigin],
) -> Unit {
  for item in item_origins {
    for effect in interface.effects {
      if effect.name == item.name {
        self.publish_effect_binding(
          effect.name,
          effect.symbol,
          interface_type_parameter_kinds(effect.type_parameters),
          operations=effect.operations.map(fn(operation) {
            { name: operation.name, symbol: operation.symbol }
          }),
          Some(item.origin),
        )
      }
    }
  }
}

///|
fn Resolver::publish_imported_public_values(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  loc : SourceSpan,
  import_origin : Int?,
) -> Unit {
  for value in interface.values {
    let binding = imported_interface_value_binding(
      interface, value, import_origin,
    )
    self.publish_complete_top_level_binding(binding, loc)
    self.publish_ordered_top_level_binding(binding, loc)
    self.record_import_symbol(import_origin, ValueSymbol(value.symbol))
  }
}

///|
fn Resolver::publish_imported_selected_values(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  item_origins : Array[SelectiveImportOrigin],
) -> Unit {
  for item in item_origins {
    for value in interface.values {
      if value.name == item.name {
        let binding = imported_interface_value_binding(
          interface,
          value,
          Some(item.origin),
        )
        self.publish_complete_top_level_binding(binding, item.loc)
        self.publish_ordered_top_level_binding(binding, item.loc)
        self.record_import_symbol(Some(item.origin), ValueSymbol(value.symbol))
      }
    }
  }
}

///|
fn imported_interface_value_binding(
  interface : @module_interface.ModuleInterface,
  value : @module_interface.ModuleInterfaceValue,
  import_origin : Int?,
) -> ValueBinding {
  let source = match interface.source_id {
    Some(source_id) => ExternalSource(source_id~)
    None => NoSource(origin="module `\{interface.module_path}`")
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
