///|
priv struct Resolver {
  registry : SymbolRegistry
  declaration_symbols : @symbol.DeclarationSymbolScope
  modules : Array[ModuleBinding]
  types : Array[TypeBinding]
  effects : Array[EffectBinding]
  type_aliases : Array[TypeAliasBinding]
  top_values : Array[ValueBinding]
  ordered_top_values : Array[ValueBinding]
  conflicting_top_value_names : Array[String]
  import_exposures : Array[ResolvedImportExposure]
  import_uses : Array[ResolvedImportUse]
  import_symbols : Array[ResolvedImportExposureSymbol]
  diagnostics : Array[ResolveDiagnostic]
}

///|
priv struct ModuleBinding {
  path_text : String
  interface : @module_interface.ModuleInterface
  import_origin : Int?
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
  name : String
  owner_module_path : String?
  is_effect : Bool
  parameter_kinds : Array[@types.Kind]
  import_origin : Int?
}

///|
priv struct SelectiveImportOrigin {
  name : String
  origin : Int
  loc : SourceSpan
}

///|
priv struct QualifiedNameText {
  module_path : String
  name : String
}

///|
/// Resolves a syntax source file and returns diagnostics with the result.
///
/// Example: resolving `fn f(x : Missing) -> Int { x }` records an unresolved
/// type diagnostic while still returning a resolved tree for later phases.
pub fn resolve_source_file_result(source : @syntax.SourceFile) -> ResolveResult {
  let resolver = Resolver::Resolver(
    SymbolRegistry(),
    @module_interface.module_path_text(source.module_path),
  )
  resolver.resolve_source_file_result(source)
}

///|
/// Resolves a source file inside one compiler invocation registry and with
/// directly imported module interfaces already available.
pub fn resolve_source_file_with_imports_result(
  source : @syntax.SourceFile,
  registry : SymbolRegistry,
  imported_environment : @module_interface.ImportedEnvironment,
) -> ResolveResult {
  let resolver = Resolver::Resolver(
    registry,
    @module_interface.module_path_text(source.module_path),
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
  self.collect_nominal_members(source)
  let declarations = source.declarations.map(fn(declaration) {
    declaration.resolve_top_level(self)
  })
  let resolved = {
    module_path: source.module_path,
    symbols: self.registry,
    import_exposures: self.import_exposures,
    import_uses: self.import_uses,
    import_symbols: self.import_symbols,
    declarations,
    loc: source.loc,
  }
  { source: resolved, diagnostics: self.diagnostics }
}

///|
fn Resolver::Resolver(
  registry : SymbolRegistry,
  scope_key : String,
) -> Resolver {
  {
    registry,
    declaration_symbols: registry.declaration_scope(scope_key),
    modules: [],
    types: [],
    effects: [],
    type_aliases: [],
    top_values: [],
    ordered_top_values: [],
    conflicting_top_value_names: [],
    import_exposures: [],
    import_uses: [],
    import_symbols: [],
    diagnostics: [],
  }
}

///|
fn Resolver::publish_imported_bindings(
  self : Resolver,
  source : @syntax.SourceFile,
  imported_environment : @module_interface.ImportedEnvironment,
) -> Unit {
  for import_ in source.imports {
    match import_ {
      Qualified(module_path~, loc~) => {
        let module_path_text = @module_interface.module_path_text(module_path)
        let module_origin = self.define_import_exposure(
          module_path_text,
          QualifiedModuleBinding,
          loc,
        )
        self.publish_imported_module_binding(
          module_path,
          imported_environment,
          Some(module_origin),
        )
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
            let module_origin = self.define_import_exposure(
              module_path_text,
              ImportedModuleBinding,
              loc,
            )
            let open_origin = self.define_import_exposure(
              module_path_text,
              OpenBinding,
              loc,
            )
            self.publish_imported_module_binding(
              module_path,
              imported_environment,
              Some(module_origin),
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
            let module_path_text = @module_interface.module_path_text(
              module_path,
            )
            let module_origin = self.define_import_exposure(
              module_path_text,
              ImportedModuleBinding,
              loc,
            )
            self.publish_imported_module_binding(
              module_path,
              imported_environment,
              Some(module_origin),
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
fn Resolver::publish_imported_module_binding(
  self : Resolver,
  module_path : @syntax.ModulePath,
  imported_environment : @module_interface.ImportedEnvironment,
  import_origin : Int?,
) -> Unit {
  let path_text = @module_interface.module_path_text(module_path)
  guard imported_environment.find(path_text) is Some(interface) else { return }
  if self.modules.any(fn(binding) { binding.path_text == path_text }) {
    return
  }
  self.modules.push({ path_text, interface, import_origin })
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

///|
fn Resolver::collect_top_level_headers(
  self : Resolver,
  source : @syntax.SourceFile,
) -> Unit {
  let symbols = self.declaration_symbols
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => {
        self.report_type_effect_conflict_if_effect_exists(
          declaration.name,
          "type",
          declaration.loc,
        )
        self.publish_type_binding(
          declaration.name,
          symbols.define_type(
            declaration.name,
            Struct,
            declaration.type_parameters.length(),
            declaration.name_loc,
          ),
          syntax_type_parameter_kinds(declaration.type_parameters),
          None,
        )
      }
      Enum(declaration) => {
        self.report_type_effect_conflict_if_effect_exists(
          declaration.name,
          "type",
          declaration.loc,
        )
        self.publish_type_binding(
          declaration.name,
          symbols.define_type(
            declaration.name,
            Enum,
            declaration.type_parameters.length(),
            declaration.name_loc,
          ),
          syntax_type_parameter_kinds(declaration.type_parameters),
          None,
        )
      }
      Effect(declaration) => {
        self.report_effect_type_conflict_if_type_exists(
          declaration.name,
          declaration.loc,
        )
        self.publish_effect_binding(
          declaration.name,
          symbols.define_effect(
            declaration.name,
            declaration.type_parameters.length(),
            declaration.name_loc,
          ),
          syntax_type_parameter_kinds(declaration.type_parameters),
          None,
        )
      }
      ExternalType(declaration) =>
        match declaration.result_kind {
          Type(_) => {
            self.report_type_effect_conflict_if_effect_exists(
              declaration.name,
              "external type",
              declaration.loc,
            )
            self.publish_type_binding(
              declaration.name,
              symbols.define_type(
                declaration.name,
                External,
                declaration.type_parameters.length(),
                declaration.name_loc,
              ),
              syntax_type_parameter_kinds(declaration.type_parameters),
              None,
            )
          }
          Effect(_) => {
            self.report_effect_type_conflict_if_type_exists(
              declaration.name,
              declaration.loc,
            )
            self.publish_effect_binding(
              declaration.name,
              symbols.define_effect(
                declaration.name,
                declaration.type_parameters.length(),
                declaration.name_loc,
                flavor=External,
              ),
              syntax_type_parameter_kinds(declaration.type_parameters),
              None,
            )
          }
        }
      TypeAlias(declaration) => {
        self.report_type_effect_conflict_if_effect_exists(
          declaration.name,
          "type alias",
          declaration.loc,
        )
        self.type_aliases.push({
          name: declaration.name,
          owner_module_path: None,
          is_effect: declaration.body is EffectBody(_),
          parameter_kinds: syntax_type_parameter_kinds(
            declaration.type_parameters,
          ),
          import_origin: None,
        })
      }
      Function(declaration) => {
        let symbol = symbols.define_value(
          declaration.name,
          TopLevelFunction,
          declaration.name_loc,
        )
        let binding = {
          name: declaration.name,
          reference: Symbol(symbol),
          type_: None,
          kind: Plain,
          source: CurrentSource,
          import_origin: None,
        }
        self.publish_complete_top_level_binding(binding, declaration.name_loc)
        self.publish_ordered_top_level_binding(binding, declaration.name_loc)
      }
      Let(declaration) =>
        if declaration.name is Some(name) {
          let symbol = symbols.define_value(
            name,
            TopLevelValue,
            declaration.name_loc.unwrap_or(declaration.loc),
          )
          let type_annotation = declaration.type_annotation.map(fn(type_) {
            type_.resolve_type(self, self.scope([]))
          })
          self.publish_complete_top_level_binding(
            {
              name,
              reference: Symbol(symbol),
              type_: type_annotation,
              kind: Plain,
              source: CurrentSource,
              import_origin: None,
            },
            declaration.name_loc.unwrap_or(declaration.loc),
          )
        }
      Offer(declaration) => {
        let symbol = symbols.define_value(
          declaration.name,
          TopLevelValue,
          declaration.name_loc,
        )
        let type_annotation = declaration.type_annotation.resolve_type(
          self,
          self.scope([]),
        )
        self.publish_complete_top_level_binding(
          {
            name: declaration.name,
            reference: Symbol(symbol),
            type_: Some(type_annotation),
            kind: Plain,
            source: CurrentSource,
            import_origin: None,
          },
          declaration.name_loc,
        )
      }
    }
  }
}

///|
fn Resolver::collect_nominal_members(
  self : Resolver,
  source : @syntax.SourceFile,
) -> Unit {
  let symbols = self.declaration_symbols
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => {
        let owner = self.type_symbol(declaration.name)
        let mut index = 0
        for item in declaration.members {
          match item {
            TypeMember(type_member) =>
              self.type_binding_for_symbol(owner).unwrap().type_members.push(
                type_member.name,
              )
            Field(field) => {
              let symbol = symbols.define_field(
                owner,
                field.name,
                index,
                field.name_loc,
              )
              self.type_binding_for_symbol(owner).unwrap().fields.push({
                name: field.name,
                symbol,
              })
              index += 1
            }
          }
        }
      }
      Enum(declaration) => {
        let owner = self.type_symbol(declaration.name)
        for index = 0; index < declaration.variants.length(); index = index + 1 {
          let variant = declaration.variants[index]
          let symbol = symbols.define_variant(
            owner,
            variant.name,
            index,
            variant.payload.length(),
            variant.name_loc,
          )
          self.type_binding_for_symbol(owner).unwrap().variants.push({
            name: variant.name,
            symbol,
          })
        }
      }
      Effect(declaration) => {
        let owner = self.effect_symbol(declaration.name)
        for index in 0..<declaration.operations.length() {
          let operation = declaration.operations[index]
          let symbol = symbols.define_operation(
            owner,
            operation.name,
            index,
            operation.payload.length(),
            operation.name_loc,
          )
          self.effect_binding_for_symbol(owner).unwrap().operations.push({
            name: operation.name,
            symbol,
          })
        }
      }
      ExternalType(_) | TypeAlias(_) | Function(_) | Let(_) | Offer(_) => ()
    }
  }
}

///|
/// Resolves one top-level declaration after the global headers are known.
///
/// Example: `fn f() -> Int { 1 }` resolves through the function path, while
/// `offer int_ops : Add[Int] = value` resolves through the top-level offered
/// value path.
fn @syntax.TopLevelDeclaration::resolve_top_level(
  self : @syntax.TopLevelDeclaration,
  resolver : Resolver,
) -> ResolvedTopLevelDeclaration {
  match self {
    Struct(declaration) => Struct(declaration.resolve_struct(resolver))
    Enum(declaration) => Enum(declaration.resolve_enum(resolver))
    Effect(declaration) => Effect(declaration.resolve_effect(resolver))
    ExternalType(declaration) => declaration.resolve_external_type(resolver)
    TypeAlias(declaration) =>
      TypeAlias(declaration.resolve_type_alias(resolver))
    Function(declaration) =>
      Function(declaration.resolve_top_level_function(resolver))
    Let(declaration) => Let(declaration.resolve_top_level_let(resolver))
    Offer(declaration) => Offer(declaration.resolve_top_level_offer(resolver))
  }
}

///|
fn @syntax.ExternalTypeDeclaration::resolve_external_type(
  self : @syntax.ExternalTypeDeclaration,
  resolver : Resolver,
) -> ResolvedTopLevelDeclaration {
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  match self.result_kind {
    Type(_) =>
      ExternalType({
        is_public: self.is_public,
        symbol: resolver.type_symbol(self.name),
        name: self.name,
        name_loc: self.name_loc,
        type_parameters,
        loc: self.loc,
      })
    Effect(_) =>
      Effect({
        is_public: self.is_public,
        symbol: resolver.effect_symbol(self.name),
        name: self.name,
        name_loc: self.name_loc,
        flavor: External,
        type_parameters,
        operations: [],
        loc: self.loc,
      })
  }
}

///|
/// Resolves a struct declaration and its fields.
///
/// Example: `struct Point { x : Int }` resolves `Point` to a type symbol and
/// `x` to a field symbol whose declared type is also resolved.
fn @syntax.StructDeclaration::resolve_struct(
  self : @syntax.StructDeclaration,
  resolver : Resolver,
) -> ResolvedStructDeclaration {
  let symbol = resolver.type_symbol(self.name)
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let scope = resolver.scope(type_parameters)
  let mut field_index = 0
  let mut type_member_index = 0
  let members = []
  for item in self.members {
    match item {
      TypeMember(type_member) => {
        let resolved = type_member.resolve_type_member(
          resolver, scope, symbol, type_member_index,
        )
        type_member_index += 1
        members.push(ResolvedStructMember::TypeMember(resolved))
      }
      Field(field) => {
        let resolved = field.resolve_field(resolver, scope, symbol, field_index)
        field_index += 1
        members.push(Field(resolved))
      }
    }
  }
  {
    is_public: self.is_public,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_parameters,
    members,
    loc: self.loc,
  }
}

///|
/// Resolves one struct type-member declaration and exposes it to later fields.
///
/// Example: in `struct Hide { type T : Type; val : T }`, resolving `T`
/// creates both a member identity owned by `Hide` and an abstract type
/// parameter used by the following field annotation.
fn @syntax.TypeMemberDeclaration::resolve_type_member(
  self : @syntax.TypeMemberDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId,
  index : Int,
) -> ResolvedTypeMemberDeclaration {
  let kind : ResolvedKind = match self.kind {
    Some(kind) => kind.resolve_kind()
    None => Type(loc=self.loc)
  }
  let type_parameter_symbol = resolver.registry.define_type_parameter(
    self.name,
    self.name_loc,
  )
  let type_parameter : ResolvedTypeParameter = {
    symbol: type_parameter_symbol,
    name: self.name,
    name_loc: self.name_loc,
    kind: Some(kind),
    loc: self.loc,
  }
  let symbol = resolver.declaration_symbols.define_type_member(
    owner,
    self.name,
    index,
    type_parameter_symbol,
    self.name_loc,
  )
  scope.type_parameters.push(type_parameter)
  {
    symbol,
    type_parameter,
    name: self.name,
    name_loc: self.name_loc,
    kind,
    index,
    loc: self.loc,
  }
}

///|
/// Resolves kind syntax without interpreting higher-kind support yet.
///
/// Example: `Type -> Type` remains an arrow kind in resolved IR so the later
/// kind checker can decide whether that form is accepted in the current phase.
fn @syntax.Kind::resolve_kind(self : @syntax.Kind) -> ResolvedKind {
  match self {
    Type(loc~) => Type(loc~)
    Effect(loc~) => Effect(loc~)
    Function(parameters~, result~, loc~) =>
      Function(
        parameters=parameters.map(fn(parameter) { parameter.resolve_kind() }),
        result=result.resolve_kind(),
        loc~,
      )
    Grouped(kind~, ..) => kind.resolve_kind()
  }
}

///|
fn @syntax.TypeAliasDeclaration::resolve_type_alias(
  self : @syntax.TypeAliasDeclaration,
  resolver : Resolver,
) -> ResolvedTypeAliasDeclaration {
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let scope = resolver.scope(type_parameters)
  let body = self.body.resolve_type_alias_body(resolver, scope)
  {
    is_public: self.is_public,
    name: self.name,
    name_loc: self.name_loc,
    type_parameters,
    result_kind: self.result_kind.map(fn(kind) { kind.resolve_kind() }),
    body: if type_parameters.is_empty() {
      body
    } else {
      body.wrap_type_lambda(type_parameters, self.loc)
    },
    loc: self.loc,
  }
}

///|
fn @syntax.TypeAliasBody::resolve_type_alias_body(
  self : @syntax.TypeAliasBody,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedTypeAliasBody {
  match self {
    TypeBody(type_) => TypeBody(type_.resolve_type(resolver, scope))
    EffectBody(effect) =>
      EffectBody(effect.resolve_effect_term(resolver, scope))
  }
}

///|
fn ResolvedTypeAliasBody::wrap_type_lambda(
  self : ResolvedTypeAliasBody,
  parameters : Array[ResolvedTypeParameter],
  loc : SourceSpan,
) -> ResolvedTypeAliasBody {
  match self {
    TypeBody(body) => TypeBody(TypeLambda(parameters~, body~, loc~))
    EffectBody(_) => self
  }
}

///|
/// Resolves an enum declaration and every declared variant payload type.
///
/// Example: `enum Option[A] { some(A) }` resolves `Option`, `A`, and `some`
/// into distinct type-parameter and variant symbols.
fn @syntax.EnumDeclaration::resolve_enum(
  self : @syntax.EnumDeclaration,
  resolver : Resolver,
) -> ResolvedEnumDeclaration {
  let symbol = resolver.type_symbol(self.name)
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let scope = resolver.scope(type_parameters)
  let variants = self.variants.mapi(fn(index, variant) {
    variant.resolve_variant(resolver, scope, symbol, index)
  })
  {
    is_public: self.is_public,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_parameters,
    variants,
    loc: self.loc,
  }
}

///|
/// Resolves a list of type parameter names into fresh type-parameter symbols.
///
/// Example: the `[A, B]` in `fn[A, B] pair(...)` creates two symbols that can be
/// referenced by parameter, return, and body type annotations.
fn Resolver::resolve_type_parameters(
  self : Resolver,
  parameters : Array[@syntax.TypeParameter],
  _loc : SourceSpan,
) -> Array[ResolvedTypeParameter] {
  parameters.map(fn(parameter) {
    let symbol = self.registry.define_type_parameter(
      parameter.name,
      parameter.name_loc,
    )
    {
      symbol,
      name: parameter.name,
      name_loc: parameter.name_loc,
      kind: parameter.kind.map(@syntax.Kind::resolve_kind),
      loc: parameter.loc,
    }
  })
}

///|
fn Resolver::resolve_type_parameter_names(
  self : Resolver,
  names : Array[String],
  loc : SourceSpan,
) -> Array[ResolvedTypeParameter] {
  names.map(fn(name) {
    let symbol = self.registry.define_type_parameter(name, loc)
    { symbol, name, name_loc: loc, kind: None, loc }
  })
}

///|
/// Resolves one struct field declaration under the struct's type-parameter scope.
///
/// Example: in `struct Box[A] { value : A }`, the field type `A` resolves to
/// the struct type parameter, not a nominal type named `A`.
fn @syntax.FieldDeclaration::resolve_field(
  self : @syntax.FieldDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId,
  index : Int,
) -> ResolvedFieldDeclaration {
  let symbol = resolver.field_symbol(owner, self.name)
  let type_ = self.type_.resolve_type(resolver, scope)
  {
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_,
    index,
    loc: self.loc,
  }
}

///|
/// Resolves one enum variant declaration and its payload type list.
///
/// Example: `some(A)` inside `enum Option[A]` resolves to the `some` variant
/// symbol and a payload whose type is the enum type parameter `A`.
fn @syntax.EnumVariant::resolve_variant(
  self : @syntax.EnumVariant,
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId,
  index : Int,
) -> ResolvedEnumVariant {
  let symbol = resolver.variant_symbol(owner, self.name)
  let variant_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let variant_scope = {
    values: scope.values.copy(),
    type_parameters: scope.type_parameters + variant_parameters,
  }
  {
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    index,
    type_parameters: variant_parameters,
    payload: self.payload.map(fn(type_) {
      type_.resolve_type(resolver, variant_scope)
    }),
    loc: self.loc,
  }
}

///|
fn @syntax.EffectDeclaration::resolve_effect(
  self : @syntax.EffectDeclaration,
  resolver : Resolver,
) -> ResolvedEffectDeclaration {
  let symbol = resolver.effect_symbol(self.name)
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let scope = resolver.scope(type_parameters)
  let operations = self.operations.mapi(fn(index, operation) {
    operation.resolve_operation(resolver, scope, symbol, index)
  })
  {
    is_public: self.is_public,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    flavor: Algebraic,
    type_parameters,
    operations,
    loc: self.loc,
  }
}

///|
fn @syntax.EffectOperationDeclaration::resolve_operation(
  self : @syntax.EffectOperationDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  owner : EffectSymbolId,
  index : Int,
) -> ResolvedEffectOperationDeclaration {
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let operation_scope = scope.enter_scope()
  operation_scope.type_parameters.append(type_parameters)
  {
    symbol: resolver.operation_symbol(owner, self.name),
    name: self.name,
    name_loc: self.name_loc,
    index,
    type_parameters,
    payload: self.payload.map(fn(type_) {
      type_.resolve_type(resolver, operation_scope)
    }),
    result: self.result.resolve_type(resolver, operation_scope),
    loc: self.loc,
  }
}

///|
/// Resolves a top-level function using its pre-collected value symbol.
///
/// Example: `fn even(...)` can refer to `odd(...)` because both top-level
/// function symbols are collected before this function body is resolved.
fn @syntax.FunctionDeclaration::resolve_top_level_function(
  self : @syntax.FunctionDeclaration,
  resolver : Resolver,
) -> ResolvedFunctionDeclaration {
  self.resolve_function_with_symbol(
    resolver,
    resolver.value_symbol(self.name),
    resolver.scope([]),
  )
}

///|
/// Resolves a function declaration once the function's value symbol is known.
///
/// Example: both top-level `fn f(...)` and local `fn f(...)` use this path after
/// their caller decides which value symbol should represent `f`.
fn @syntax.FunctionDeclaration::resolve_function_with_symbol(
  self : @syntax.FunctionDeclaration,
  resolver : Resolver,
  symbol : ValueSymbolId,
  scope : ResolveScope,
) -> ResolvedFunctionDeclaration {
  let type_parameters = resolver.resolve_type_parameters(
    self.type_parameters,
    self.loc,
  )
  let parameter_scope = scope.enter_scope()
  parameter_scope.type_parameters.append(type_parameters)
  let parameters = self.parameters.map(fn(parameter) {
    parameter.resolve_parameter(resolver, parameter_scope)
  })
  let return_type = self.return_type.resolve_type(resolver, parameter_scope)
  let effect = self.effect.resolve_effect_term(resolver, parameter_scope)
  // Parameters are inserted into `parameter_scope` while they are resolved. The
  // return type can use type parameters, and the body can use both type and
  // value parameters.
  {
    is_public: self.is_public,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_parameters,
    parameters,
    return_type,
    effect,
    body: self.body.resolve_expr(resolver, parameter_scope),
    loc: self.loc,
  }
}

///|
/// Resolves a named function parameter and binds it in the function scope.
///
/// Example: `x : Int` in `fn f(x : Int) -> Int { x }` creates a parameter
/// value symbol that the body reference `x` resolves to.
fn @syntax.Parameter::resolve_parameter(
  self : @syntax.Parameter,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedValueParameter {
  let type_ = self.type_.resolve_type(resolver, scope)
  let symbol = resolver.registry.define_value(
    self.name,
    Parameter,
    self.name_loc,
  )
  scope.define_value(self.name, symbol, Some(type_))
  {
    symbol,
    is_auto: self.is_auto,
    is_offered: self.is_offered,
    name: self.name,
    name_loc: self.name_loc,
    type_,
    loc: self.loc,
  }
}

///|
/// Resolves a top-level let declaration and publishes it for later declarations.
///
/// Example: after `let answer : Int = 42`, following top-level declarations can
/// resolve `answer`, but earlier declarations cannot.
fn @syntax.LetDeclaration::resolve_top_level_let(
  self : @syntax.LetDeclaration,
  resolver : Resolver,
) -> ResolvedLetDeclaration {
  let scope = resolver.ordered_scope([])
  let symbol = match self.name {
    Some(name) => resolver.value_symbol(name)
    None =>
      resolver.registry.define_value("<anonymous>", TopLevelValue, self.loc)
  }
  let type_annotation = match self.name {
    Some(name) =>
      match resolver.top_value_binding(name) {
        Some(binding) => binding.type_
        None =>
          self.type_annotation.map(fn(type_) {
            type_.resolve_type(resolver, scope)
          })
      }
    None =>
      self.type_annotation.map(fn(type_) { type_.resolve_type(resolver, scope) })
  }
  let declaration = self.resolve_let_with_resolved_type(
    resolver, scope, symbol, type_annotation,
  )
  resolver.publish_top_level_let(declaration, self.name_loc.unwrap_or(self.loc))
  declaration
}

///|
fn Resolver::publish_top_level_let(
  self : Resolver,
  declaration : ResolvedLetDeclaration,
  loc : SourceSpan,
) -> Unit {
  let binding = {
    name: declaration.name.unwrap_or("<anonymous>"),
    reference: Symbol(declaration.symbol),
    type_: declaration.type_annotation,
    kind: Plain,
    source: CurrentSource,
    import_origin: None,
  }
  match declaration.name {
    Some(_) => self.publish_ordered_top_level_binding(binding, loc)
    None => ()
  }
}

///|
/// Resolves a let declaration in the supplied scope.
///
/// Example: `let y = x` resolves the initializer against the current scope,
/// then binds `y` for declarations and expressions that follow.
fn @syntax.LetDeclaration::resolve_let(
  self : @syntax.LetDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  kind : @symbol.ValueSymbolKind,
) -> ResolvedLetDeclaration {
  let display_name = self.name.unwrap_or("<anonymous>")
  let symbol = resolver.registry.define_value(
    display_name,
    kind,
    self.name_loc.unwrap_or(self.loc),
  )
  self.resolve_let_with_symbol(resolver, scope, symbol)
}

///|
fn @syntax.LetDeclaration::resolve_let_with_symbol(
  self : @syntax.LetDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  symbol : ValueSymbolId,
) -> ResolvedLetDeclaration {
  let type_annotation = self.type_annotation.map(fn(type_) {
    type_.resolve_type(resolver, scope)
  })
  self.resolve_let_with_resolved_type(resolver, scope, symbol, type_annotation)
}

///|
fn @syntax.LetDeclaration::resolve_let_with_resolved_type(
  self : @syntax.LetDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  symbol : ValueSymbolId,
  type_annotation : ResolvedType?,
) -> ResolvedLetDeclaration {
  // The initializer is resolved before the binding is inserted. This keeps
  // local let bindings sequential and non-recursive.
  let initializer = self.initializer.resolve_expr(resolver, scope)
  if self.name is Some(name) {
    scope.define_value(name, symbol, type_annotation)
  }
  {
    is_public: self.is_public,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_annotation,
    initializer,
    loc: self.loc,
  }
}

///|
/// Resolves a top-level offered value declaration.
///
/// Example: `offer int_add_ops : Add[Int] = value` defines `int_add_ops` for
/// later top-level declarations and marks it for Contextual Resolution.
fn @syntax.OfferDeclaration::resolve_top_level_offer(
  self : @syntax.OfferDeclaration,
  resolver : Resolver,
) -> ResolvedOfferDeclaration {
  let scope = resolver.ordered_scope([])
  let symbol = resolver.value_symbol(self.name)
  let type_annotation = match resolver.top_value_binding(self.name) {
    Some({ type_: Some(type_annotation), .. }) => type_annotation
    _ => self.type_annotation.resolve_type(resolver, scope)
  }
  let declaration = self.resolve_offer_value_with_resolved_type(
    resolver, scope, symbol, type_annotation,
  )
  resolver.publish_top_level_offer(declaration, self.name_loc)
  declaration
}

///|
fn Resolver::publish_top_level_offer(
  self : Resolver,
  declaration : ResolvedOfferDeclaration,
  loc : SourceSpan,
) -> Unit {
  self.publish_ordered_top_level_binding(
    {
      name: declaration.name,
      reference: Symbol(declaration.symbol),
      type_: Some(declaration.type_annotation),
      kind: Plain,
      source: CurrentSource,
      import_origin: None,
    },
    loc,
  )
}

///|
fn @syntax.OfferDeclaration::resolve_offer_value(
  self : @syntax.OfferDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  kind : @symbol.ValueSymbolKind,
) -> ResolvedOfferDeclaration {
  let symbol = resolver.registry.define_value(self.name, kind, self.name_loc)
  self.resolve_offer_value_with_symbol(resolver, scope, symbol)
}

///|
fn @syntax.OfferDeclaration::resolve_offer_value_with_symbol(
  self : @syntax.OfferDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  symbol : ValueSymbolId,
) -> ResolvedOfferDeclaration {
  let type_annotation = self.type_annotation.resolve_type(resolver, scope)
  self.resolve_offer_value_with_resolved_type(
    resolver, scope, symbol, type_annotation,
  )
}

///|
fn @syntax.OfferDeclaration::resolve_offer_value_with_resolved_type(
  self : @syntax.OfferDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
  symbol : ValueSymbolId,
  type_annotation : ResolvedType,
) -> ResolvedOfferDeclaration {
  let initializer = self.initializer.resolve_expr(resolver, scope)
  scope.define_value(self.name, symbol, Some(type_annotation))
  {
    is_public: self.is_public,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_annotation,
    initializer,
    loc: self.loc,
  }
}

///|
/// Resolves a source type expression into primitive, parameter, nominal, or
/// unresolved resolved-type nodes.
///
/// Example: `A` in a generic scope resolves to a type parameter, while
/// `Option[Int]` resolves to a nominal type application.
fn @syntax.Type::resolve_type(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedType {
  match self {
    Name(name~, loc~) =>
      // Type names are resolved in the language order: primitives first, then
      // in-scope type parameters, then nominal type constructors, then aliases.
      match primitive_type(name) {
        Some(primitive) => Primitive(primitive, loc~)
        None =>
          match scope.type_parameter(name) {
            Some(symbol) => Parameter(symbol~, name~, loc~)
            None =>
              match resolver.type_binding(name) {
                Some(binding) => {
                  resolver.record_import_use(binding.import_origin, loc)
                  Constructor(symbol=binding.symbol, name~, loc~)
                }
                None =>
                  match resolver.type_alias_binding(name) {
                    Some(binding) => {
                      resolver.record_import_use(binding.import_origin, loc)
                      Alias(
                        owner_module_path=binding.owner_module_path,
                        name~,
                        loc~,
                      )
                    }
                    None =>
                      match resolver.qualified_type_symbol_opt(name) {
                        Some(symbol) => Constructor(symbol~, name~, loc~)
                        None => {
                          resolver.report(UnresolvedType(name), loc)
                          Unresolved(name~, arguments=[], loc~)
                        }
                      }
                  }
              }
          }
      }
    QualifiedName(module_path~, name~, loc~) =>
      resolver.resolve_module_qualified_type(module_path, name, loc)
    Apply(callee~, arguments~, loc~) => {
      let resolved_callee = callee.resolve_type(resolver, scope)
      Apply(
        callee=resolved_callee,
        arguments=callee.resolve_type_application_arguments(
          resolved_callee, arguments, resolver, scope,
        ),
        loc~,
      )
    }
    TypeLambda(parameters~, body~, loc~) => {
      let resolved_type_parameters = resolver.resolve_type_parameters(
        parameters, loc,
      )
      let next_scope = scope.enter_scope()
      next_scope.type_parameters.append(resolved_type_parameters)
      TypeLambda(
        parameters=resolved_type_parameters,
        body=body.resolve_type(resolver, next_scope),
        loc~,
      )
    }
    Function(type_parameters~, parameters~, result~, effect~, loc~) => {
      let resolved_type_parameters = resolver.resolve_type_parameters(
        type_parameters, loc,
      )
      let next_scope = scope.enter_scope()
      next_scope.type_parameters.append(resolved_type_parameters)
      Function(
        type_parameters=resolved_type_parameters,
        parameters=parameters.map(fn(type_) {
          type_.resolve_type(resolver, next_scope)
        }),
        result=result.resolve_type(resolver, next_scope),
        effect=effect.resolve_effect_term(resolver, next_scope),
        loc~,
      )
    }
    Grouped(type_~, ..) => type_.resolve_type(resolver, scope)
  }
}

///|
fn @syntax.Type::resolve_type_application_arguments(
  self : @syntax.Type,
  _resolved_callee : ResolvedType,
  arguments : Array[@syntax.GenericArgument],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  match self {
    Name(name~, ..) =>
      match resolver.type_binding(name) {
        Some(binding) =>
          resolve_generic_arguments(
            arguments,
            binding.parameter_kinds,
            resolver,
            scope,
          )
        None =>
          match resolver.type_alias_binding(name) {
            Some(binding) =>
              resolve_generic_arguments(
                arguments,
                binding.parameter_kinds,
                resolver,
                scope,
              )
            None =>
              resolve_default_generic_arguments(arguments, resolver, scope)
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      match
        resolver.module_binding(@module_interface.module_path_text(module_path)) {
        Some(module_) =>
          match interface_type_application_parameters(module_.interface, name) {
            Some(parameters) =>
              resolve_generic_arguments(arguments, parameters, resolver, scope)
            None =>
              resolve_default_generic_arguments(arguments, resolver, scope)
          }
        None => resolve_default_generic_arguments(arguments, resolver, scope)
      }
    _ => resolve_default_generic_arguments(arguments, resolver, scope)
  }
}

///|
fn resolve_default_generic_arguments(
  arguments : Array[@syntax.GenericArgument],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  arguments.map(fn(argument) {
    argument.resolve_default_generic_argument(resolver, scope)
  })
}

///|
fn resolve_generic_arguments(
  arguments : Array[@syntax.GenericArgument],
  parameter_kinds : Array[@types.Kind],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  arguments.mapi(fn(index, argument) {
    if index < parameter_kinds.length() {
      argument.resolve_generic_argument_with_kind(
        parameter_kinds[index],
        resolver,
        scope,
      )
    } else {
      argument.resolve_default_generic_argument(resolver, scope)
    }
  })
}

///|
fn resolve_type_name_arguments(
  type_name : String,
  arguments : Array[@syntax.GenericArgument],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  match resolver.type_binding(type_name) {
    Some(binding) => {
      resolver.record_import_use(
        binding.import_origin,
        @basic.SourceSpan::dummy(),
      )
      resolve_generic_arguments(
        arguments,
        binding.parameter_kinds,
        resolver,
        scope,
      )
    }
    None =>
      match resolver.type_alias_binding(type_name) {
        Some(binding) => {
          resolver.record_import_use(
            binding.import_origin,
            @basic.SourceSpan::dummy(),
          )
          resolve_generic_arguments(
            arguments,
            binding.parameter_kinds,
            resolver,
            scope,
          )
        }
        None =>
          match qualified_type_name_parameters(resolver, type_name) {
            Some(parameters) =>
              resolve_generic_arguments(arguments, parameters, resolver, scope)
            None =>
              resolve_default_generic_arguments(arguments, resolver, scope)
          }
      }
  }
}

///|
priv struct ResolvedOwnerArguments {
  type_name : String
  arguments : Array[ResolvedGenericArgument]
}

///|
fn owner_type_name(owner : @syntax.Type) -> String {
  match owner {
    Name(name~, ..) => name
    QualifiedName(module_path~, name~, ..) =>
      module_path.components.join(".") + "." + name
    _ => abort("expected nominal owner type")
  }
}

///|
fn resolve_owner_generic_arguments(
  owner : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedOwnerArguments {
  match owner {
    Apply(callee~, arguments~, ..) => {
      let type_name = owner_type_name(callee)
      {
        type_name,
        arguments: resolve_type_name_arguments(
          type_name, arguments, resolver, scope,
        ),
      }
    }
    _ => {
      let type_name = owner_type_name(owner)
      { type_name, arguments: [] }
    }
  }
}

///|
fn qualified_type_name_parameters(
  resolver : Resolver,
  type_name : String,
) -> Array[@types.Kind]? {
  guard split_qualified_name(type_name) is Some(qualified) else { return None }
  match resolver.module_binding(qualified.module_path) {
    Some(module_) =>
      interface_type_application_parameters(module_.interface, qualified.name)
    None => None
  }
}

///|
fn split_qualified_name(type_name : String) -> QualifiedNameText? {
  let parts = type_name.split(".").map(StringView::to_owned).collect()
  if parts.length() < 2 {
    return None
  }
  let module_parts = []
  for index in 0..<(parts.length() - 1) {
    module_parts.push(parts[index])
  }
  Some({ module_path: module_parts.join("."), name: parts[parts.length() - 1] })
}

///|
fn interface_type_application_parameters(
  interface : @module_interface.ModuleInterface,
  name : String,
) -> Array[@types.Kind]? {
  for type_ in interface.types {
    match type_ {
      Struct(declaration) if declaration.name == name =>
        return Some(interface_type_parameter_kinds(declaration.type_parameters))
      Enum(declaration) if declaration.name == name =>
        return Some(interface_type_parameter_kinds(declaration.type_parameters))
      _ => ()
    }
  }
  for type_alias in interface.type_aliases {
    if type_alias.name == name {
      return Some(interface_type_parameter_kinds(type_alias.type_parameters))
    }
  }
  None
}

///|
fn @syntax.EffectTerm::resolve_effect_term(
  self : @syntax.EffectTerm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedEffectTerm {
  match self {
    Empty(loc~) => Empty(loc~)
    Term(type_~, ..) => type_.resolve_effect_type(resolver, scope, type_.loc())
    Union(items~, loc~) =>
      Union(
        items=items.map(fn(item) {
          item.resolve_effect_type(resolver, scope, item.loc())
        }),
        loc~,
      )
  }
}

///|
fn @syntax.Type::resolve_effect_type(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
  loc : SourceSpan,
) -> ResolvedEffectTerm {
  let (base, arguments) = self.effect_type_parts()
  match base {
    Name(name="Io", ..) =>
      Io(
        arguments=resolve_default_generic_arguments(arguments, resolver, scope),
        loc~,
      )
    Name(name~, ..) =>
      match scope.type_parameter_info(name) {
        Some(parameter) =>
          Parameter(symbol=parameter.symbol, name=parameter.name, loc~)
        None =>
          match resolver.effect_binding(name) {
            Some(binding) => {
              resolver.record_import_use(binding.import_origin, loc)
              let resolved_arguments = resolve_generic_arguments(
                arguments,
                binding.parameter_kinds,
                resolver,
                scope,
              )
              Singleton(
                symbol=binding.symbol,
                name~,
                arguments=resolved_arguments,
                loc~,
              )
            }
            None =>
              match resolver.type_alias_binding(name) {
                Some(binding) => {
                  resolver.record_import_use(binding.import_origin, loc)
                  let resolved_arguments = resolve_effect_alias_arguments(
                    arguments,
                    binding.parameter_kinds,
                    resolver,
                    scope,
                  )
                  Alias(
                    owner_module_path=binding.owner_module_path,
                    name~,
                    arguments=resolved_arguments,
                    loc~,
                  )
                }
                None => {
                  let resolved_arguments = arguments.map(fn(argument) {
                    argument.resolve_default_generic_argument(resolver, scope)
                  })
                  resolver.report(UnresolvedType(name), loc)
                  Unresolved(name~, arguments=resolved_arguments, loc~)
                }
              }
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      resolver.resolve_module_qualified_effect_type(
        module_path, name, arguments, scope, loc,
      )
    _ => {
      let resolved = self.resolve_type(resolver, scope)
      Unresolved(
        name=@prettyprinter.render(resolved.pretty(), width=100),
        arguments=[],
        loc~,
      )
    }
  }
}

///|
fn @syntax.Type::effect_type_parts(
  self : @syntax.Type,
) -> (@syntax.Type, Array[@syntax.GenericArgument]) {
  match self {
    Apply(callee~, arguments~, ..) => (callee, arguments)
    Grouped(type_~, ..) => type_.effect_type_parts()
    _ => (self, [])
  }
}

///|
fn Resolver::resolve_module_qualified_type(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
  loc : SourceSpan,
) -> ResolvedType {
  let full_name = module_qualified_name(module_path, name)
  match self.module_binding(@module_interface.module_path_text(module_path)) {
    Some(module_) => {
      self.record_import_use(module_.import_origin, loc)
      for type_ in module_.interface.types {
        if interface_type_name(type_) == name {
          return Constructor(
            symbol=interface_type_symbol(type_),
            name=full_name,
            loc~,
          )
        }
      }
      for type_alias in module_.interface.type_aliases {
        if type_alias.name == name {
          return Alias(
            owner_module_path=Some(module_.interface.module_path),
            name=full_name,
            loc~,
          )
        }
      }
      self.report(UnresolvedType(full_name), loc)
      Unresolved(name=full_name, arguments=[], loc~)
    }
    None => {
      self.report(UnresolvedType(full_name), loc)
      Unresolved(name=full_name, arguments=[], loc~)
    }
  }
}

///|
fn Resolver::resolve_module_qualified_effect_type(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
  arguments : Array[@syntax.GenericArgument],
  scope : ResolveScope,
  loc : SourceSpan,
) -> ResolvedEffectTerm {
  let full_name = module_qualified_name(module_path, name)
  match self.module_binding(@module_interface.module_path_text(module_path)) {
    Some(module_) => {
      self.record_import_use(module_.import_origin, loc)
      for effect in module_.interface.effects {
        if effect.name == name {
          let arguments = resolve_generic_arguments(
            arguments,
            interface_type_parameter_kinds(effect.type_parameters),
            self,
            scope,
          )
          return Singleton(
            symbol=effect.symbol,
            name=full_name,
            arguments~,
            loc~,
          )
        }
      }
      for type_alias in module_.interface.type_aliases {
        if type_alias.name == name {
          let arguments = resolve_effect_alias_arguments(
            arguments,
            interface_type_parameter_kinds(type_alias.type_parameters),
            self,
            scope,
          )
          return Alias(
            owner_module_path=Some(module_.interface.module_path),
            name=full_name,
            arguments~,
            loc~,
          )
        }
      }
      let arguments = resolve_default_generic_arguments(arguments, self, scope)
      self.report(UnresolvedType(full_name), loc)
      Unresolved(name=full_name, arguments~, loc~)
    }
    None => {
      let arguments = resolve_default_generic_arguments(arguments, self, scope)
      self.report(UnresolvedType(full_name), loc)
      Unresolved(name=full_name, arguments~, loc~)
    }
  }
}

///|
fn @syntax.GenericArgument::resolve_generic_argument(
  self : @syntax.GenericArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedGenericArgument {
  match self {
    TypeTerm(type_) =>
      if type_.should_resolve_as_effect_alias_argument(resolver, scope) {
        EffectArgument(type_.resolve_effect_type(resolver, scope, type_.loc()))
      } else {
        TypeArgument(type_.resolve_type(resolver, scope))
      }
    EffectTerm(effect) =>
      EffectArgument(effect.resolve_effect_term(resolver, scope))
  }
}

///|
fn @syntax.GenericArgument::resolve_default_generic_argument(
  self : @syntax.GenericArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedGenericArgument {
  match self {
    TypeTerm(type_) => TypeArgument(type_.resolve_type(resolver, scope))
    EffectTerm(effect) =>
      EffectArgument(effect.resolve_effect_term(resolver, scope))
  }
}

///|
fn @syntax.GenericArgument::resolve_generic_argument_with_kind(
  self : @syntax.GenericArgument,
  kind : @types.Kind,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedGenericArgument {
  match (self, kind) {
    (EffectTerm(effect), _) =>
      EffectArgument(effect.resolve_effect_term(resolver, scope))
    (TypeTerm(type_), Effect) =>
      EffectArgument(type_.resolve_effect_type(resolver, scope, type_.loc()))
    (TypeTerm(type_), _) => TypeArgument(type_.resolve_type(resolver, scope))
  }
}

///|
fn resolve_effect_alias_arguments(
  arguments : Array[@syntax.GenericArgument],
  parameter_kinds : Array[@types.Kind],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedEffectAliasArgument] {
  arguments.mapi(fn(index, argument) {
    match argument {
      EffectTerm(effect) =>
        EffectArgument(effect.resolve_effect_term(resolver, scope))
      TypeTerm(type_) =>
        if index < parameter_kinds.length() &&
          parameter_kinds[index] == Effect &&
          type_.should_resolve_as_effect_alias_argument(resolver, scope) {
          EffectArgument(
            type_.resolve_effect_type(resolver, scope, type_.loc()),
          )
        } else {
          TypeArgument(type_.resolve_type(resolver, scope))
        }
    }
  })
}

///|
fn @syntax.Type::should_resolve_as_effect_alias_argument(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> Bool {
  let (base, _) = self.effect_type_parts()
  match base {
    Name(name~, ..) =>
      match scope.type_parameter_info(name) {
        Some(parameter) =>
          match parameter.kind {
            Some(Effect(_)) => true
            _ => false
          }
        None =>
          if resolver.effect_symbol_opt(name) is Some(_) {
            true
          } else {
            match resolver.type_alias_binding(name) {
              Some(binding) => binding.is_effect
              None => false
            }
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      resolver.module_qualified_name_can_be_effect_alias_argument(
        module_path, name,
      )
    _ => false
  }
}

///|
fn Resolver::module_qualified_name_can_be_effect_alias_argument(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
) -> Bool {
  match self.module_binding(@module_interface.module_path_text(module_path)) {
    Some(module_) => {
      for effect in module_.interface.effects {
        if effect.name == name {
          return true
        }
      }
      for type_alias in module_.interface.type_aliases {
        if type_alias.name == name {
          return type_alias.kind == Effect
        }
      }
      false
    }
    None => false
  }
}

///|
fn module_qualified_name(
  module_path : @syntax.ModulePath,
  name : String,
) -> String {
  @module_interface.module_path_text(module_path) + "." + name
}

///|
fn interface_type_name(type_ : @module_interface.ModuleInterfaceType) -> String {
  match type_ {
    Struct(declaration) => declaration.name
    Enum(declaration) => declaration.name
    External(declaration) => declaration.name
  }
}

///|
fn interface_type_symbol(
  type_ : @module_interface.ModuleInterfaceType,
) -> TypeSymbolId {
  match type_ {
    Struct(declaration) => declaration.symbol
    Enum(declaration) => declaration.symbol
    External(declaration) => declaration.symbol
  }
}

///|
fn Resolver::type_alias_binding(
  self : Resolver,
  name : String,
) -> TypeAliasBinding? {
  for index = self.type_aliases.length(); index > 0; index = index - 1 {
    let binding = self.type_aliases[index - 1]
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::report_type_effect_conflict_if_effect_exists(
  self : Resolver,
  name : String,
  type_kind : String,
  loc : SourceSpan,
) -> Unit {
  if self.effect_binding(name) is Some(_) {
    self.report(
      ConflictingTopLevelTypeAndEffectName(
        name~,
        type_kind~,
        effect_kind="effect",
      ),
      loc,
    )
  }
}

///|
fn Resolver::report_effect_type_conflict_if_type_exists(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> Unit {
  if self.type_binding(name) is Some(_) {
    self.report(
      ConflictingTopLevelTypeAndEffectName(
        name~,
        type_kind="type",
        effect_kind="effect",
      ),
      loc,
    )
  } else if self.type_alias_binding(name) is Some(_) {
    self.report(
      ConflictingTopLevelTypeAndEffectName(
        name~,
        type_kind="type alias",
        effect_kind="effect",
      ),
      loc,
    )
  }
}

///|
/// Resolves a source expression under the current value and type scopes.
///
/// Example: `Point::{ x: a }` resolves field initializer `a` as an expression,
/// while `point.x` defers or records the field symbol depending on base type.
fn @syntax.Expr::resolve_expr(
  self : @syntax.Expr,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedExpr {
  match self {
    IntLiteral(value, loc~) => IntLiteral(value, loc~)
    DoubleLiteral(value, loc~) => DoubleLiteral(value, loc~)
    StringLiteral(value, loc~) => StringLiteral(value, loc~)
    BoolLiteral(value, loc~) => BoolLiteral(value, loc~)
    UnitLiteral(loc~) => UnitLiteral(loc~)
    Var(name, loc~) =>
      resolver.resolve_unqualified_name_use(scope, name, loc, BareUse(loc))
    QualifiedVariant(
      owner~,
      variant~,
      variant_loc~,
      variant_type_arguments~,
      arguments~,
      loc~
    ) => {
      let resolved_owner = resolve_owner_generic_arguments(
        owner, resolver, scope,
      )
      QualifiedVariant(
        type_name=resolved_owner.type_name,
        type_name_loc=owner.loc(),
        generic_arguments=resolved_owner.arguments,
        variant~,
        variant_loc~,
        variant_generic_arguments=variant_type_arguments.map(fn(type_) {
          type_.resolve_generic_argument(resolver, scope)
        }),
        reference=resolver.variant_reference(
          resolved_owner.type_name,
          variant,
          variant_loc,
        ),
        arguments=arguments.map(fn(argument) {
          argument.resolve_expr(resolver, scope)
        }),
        loc~,
      )
    }
    StructLiteral(owner~, fields~, loc~) => {
      let resolved_owner = resolve_owner_generic_arguments(
        owner, resolver, scope,
      )
      StructLiteral(
        type_name=resolved_owner.type_name,
        type_name_loc=owner.loc(),
        reference=resolver.type_reference(resolved_owner.type_name, owner.loc()),
        generic_arguments=resolved_owner.arguments,
        fields=resolve_struct_literal_fields(fields, resolver, scope),
        loc~,
      )
    }
    ListLiteral(items~, loc~) =>
      ListLiteral(
        items=items.map(fn(item) { item.resolve_expr(resolver, scope) }),
        empty_reference=resolver.unqualified_variant_reference("empty", loc),
        cons_reference=if items.is_empty() {
          None
        } else {
          Some(resolver.unqualified_variant_reference("cons", loc))
        },
        loc~,
      )
    Builtin(name, loc~) => Builtin(name, loc~)
    Extern(name, loc~) => Extern(name, loc~)
    EffectOperationCall(name~, type_witnesses~, arguments~, loc~) =>
      EffectOperationCall(
        name=name.resolve_effect_operation_name(resolver, scope),
        generic_witnesses=type_witnesses.map(fn(type_) {
          type_.resolve_generic_argument(resolver, scope)
        }),
        arguments=arguments.map(fn(argument) {
          argument.resolve_expr(resolver, scope)
        }),
        loc~,
      )
    TypeApplication(callee~, arguments~, loc~) =>
      GenericApplication(
        callee=callee.resolve_expr(resolver, scope),
        arguments=arguments.map(fn(argument) {
          argument.resolve_generic_argument(resolver, scope)
        }),
        loc~,
      )
    Handler(body~, handlers~, final_branch~, loc~) =>
      Handler(
        body=body.resolve_expr(resolver, scope),
        handlers=handlers.map(fn(handler) {
          handler.resolve_handler_with_block(resolver, scope)
        }),
        final_branch=final_branch.resolve_handler_final_branch(resolver, scope),
        loc~,
      )
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) => {
      let resolved_type_parameters = resolver.resolve_type_parameters(
        type_parameters, loc,
      )
      let next_scope = scope.enter_scope()
      next_scope.type_parameters.append(resolved_type_parameters)
      let resolved_parameters = parameters.map(fn(parameter) {
        parameter.resolve_function_literal_parameter(resolver, next_scope)
      })
      // Function literal parameters are inserted before the body is resolved;
      // omitted parameter types stay unresolved until semantic checking.
      FunctionLiteral(
        type_parameters=resolved_type_parameters,
        parameters=resolved_parameters,
        return_type=return_type.map(fn(type_) {
          type_.resolve_type(resolver, next_scope)
        }),
        effect=effect.map(fn(effect) {
          effect.resolve_effect_term(resolver, next_scope)
        }),
        body=body.resolve_expr(resolver, next_scope),
        loc~,
      )
    }
    Block(items~, result~, loc~) => {
      let next_scope = scope.enter_scope()
      // Local items are resolved in source order against one mutable scope copy.
      // This preserves sequential local bindings while still letting later items
      // see earlier `let`, `fn`, and `offer` declarations.
      Block(
        items=items.map(fn(item) {
          item.resolve_local_item(resolver, next_scope)
        }),
        result=result.resolve_expr(resolver, next_scope),
        loc~,
      )
    }
    If(condition~, then_branch~, else_branch~, loc~) =>
      If(
        condition=condition.resolve_expr(resolver, scope),
        then_branch=then_branch.resolve_expr(resolver, scope),
        else_branch=else_branch.resolve_expr(resolver, scope),
        loc~,
      )
    Match(scrutinee~, arms~, loc~) =>
      Match(
        scrutinee=scrutinee.resolve_expr(resolver, scope),
        arms=arms.map(fn(arm) { arm.resolve_match_arm(resolver, scope) }),
        loc~,
      )
    Call(callee~, arguments~, loc~) =>
      callee.resolve_call(resolver, scope, arguments, loc)
    Field(loc~, ..) as field =>
      match resolver.resolve_module_value_field_chain(scope, field, loc) {
        Some(expr) => expr
        None => {
          guard field is Field(base~, name~, name_loc~, ..) else {
            abort("expected field")
          }
          let base = base.resolve_expr(resolver, scope)
          Field(
            base~,
            name~,
            name_loc~,
            reference=resolver.field_reference(scope, base, name, loc),
            loc~,
          )
        }
      }
    Unary(operator~, operand~, loc~) => {
      let reference = resolver.operator_reference(
        scope,
        operator.operation_name(),
        loc,
      )
      Unary(
        operator~,
        reference~,
        operand=operand.resolve_expr(resolver, scope),
        loc~,
      )
    }
    Binary(operator~, left~, right~, loc~) => {
      let reference = resolver.operator_reference(
        scope,
        operator.operation_name(),
        loc,
      )
      Binary(
        operator~,
        reference~,
        left=left.resolve_expr(resolver, scope),
        right=right.resolve_expr(resolver, scope),
        loc~,
      )
    }
    Pipeline(left~, right~, loc~) =>
      Pipeline(
        left=left.resolve_expr(resolver, scope),
        right=right.resolve_expr(resolver, scope),
        loc~,
      )
    Grouped(expression~, ..) => expression.resolve_expr(resolver, scope)
  }
}

///|
fn @syntax.EffectOperationName::resolve_effect_operation_name(
  self : @syntax.EffectOperationName,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedEffectOperationName {
  match self {
    Qualified(owner~, operation~, operation_loc~) => {
      let owner = owner.resolve_effect_type(resolver, scope, owner.loc())
      let reference = match owner {
        Singleton(symbol~, ..) => {
          resolver.record_import_use(
            resolver.effect_import_origin(symbol),
            operation_loc,
          )
          resolver.operation_reference(symbol, operation)
        }
        _ => Unresolved(operation)
      }
      Qualified(owner~, operation~, reference~, operation_loc~)
    }
    Unqualified(operation~, operation_loc~) =>
      Unqualified(
        operation~,
        reference=resolver.unqualified_operation_reference(
          operation, operation_loc,
        ),
        operation_loc~,
      )
  }
}

///|
priv enum UnqualifiedNameUse {
  BareUse(SourceSpan)
  CallUse(arguments~ : Array[@syntax.CallArgument], loc~ : SourceSpan)
}

///|
fn Resolver::operator_reference(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  loc : SourceSpan,
) -> ResolvedValueReference {
  let reference = scope.value_reference(name)
  self.record_import_use(scope.value_import_origin(reference), loc)
  self.report_unresolved_value(reference, loc)
  reference
}

///|
fn @syntax.UnaryOperator::operation_name(
  self : @syntax.UnaryOperator,
) -> String {
  match self {
    Neg => "op_neg"
    Not => "op_not"
  }
}

///|
fn @syntax.BinaryOperator::operation_name(
  self : @syntax.BinaryOperator,
) -> String {
  match self {
    Add => "op_add"
    Sub => "op_sub"
    Mul => "op_mul"
    Div => "op_div"
    Rem => "op_rem"
    Equal => "op_equal"
    NotEqual => "op_not_equal"
    Less => "op_less"
    LessEqual => "op_less_eq"
    Greater => "op_greater"
    GreaterEqual => "op_greater_eq"
    And => "op_and"
    Or => "op_or"
  }
}

///|
fn Resolver::field_reference(
  self : Resolver,
  scope : ResolveScope,
  base : ResolvedExpr,
  name : String,
  loc : SourceSpan,
) -> ResolvedFieldReference {
  match nominal_type_of_expr(scope, base) {
    Some(symbol) =>
      match self.field_symbol_opt(symbol, name) {
        Some(field) => Symbol(field)
        None => {
          self.report_unresolved_field(symbol, name, loc)
          let type_name = match self.registry.type_metadata(symbol) {
            Some(metadata) => metadata.name
            None => "<unknown>"
          }
          Unresolved(type_name~, field=name)
        }
      }
    None => Deferred(name)
  }
}

///|
fn nominal_type_of_expr(
  scope : ResolveScope,
  expr : ResolvedExpr,
) -> TypeSymbolId? {
  match expr {
    Var(reference~, ..) =>
      match scope.value_type(reference) {
        Some(type_) =>
          match nominal_type_of_resolved_type(type_) {
            Some(symbol) => Some(symbol)
            None => None
          }
        _ => None
      }
    StructLiteral(reference=Symbol(symbol), ..) => Some(symbol)
    _ => None
  }
}

///|
fn nominal_type_of_resolved_type(type_ : ResolvedType) -> TypeSymbolId? {
  match type_ {
    Constructor(symbol~, ..) => Some(symbol)
    Apply(callee=Constructor(symbol~, ..), ..) => Some(symbol)
    _ => None
  }
}

///|
/// Resolves an unqualified source name in value position.
///
/// Example: `none` and `none()` both start from the same visible name. A visible
/// value named `none` wins first; otherwise the name may fall back to an
/// unqualified enum variant. Payloadless variants are still constructors, so
/// `none()` is the valid form and bare `none` is diagnosed here.
fn Resolver::resolve_unqualified_name_use(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
) -> ResolvedExpr {
  self.resolve_unqualified_name_use_with_variant_arguments(
    scope,
    name,
    name_loc,
    name_use,
    [],
  )
}

///|
fn Resolver::resolve_unqualified_name_use_with_variant_arguments(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
  variant_generic_arguments : Array[@syntax.GenericArgument],
) -> ResolvedExpr {
  match scope.value_reference(name) {
    Symbol(_) as reference => {
      self.record_import_use(scope.value_import_origin(reference), name_loc)
      name_use.resolve_as_value(self, scope, name, name_loc, reference)
    }
    Unresolved(_) =>
      self.resolve_unqualified_variant_use(
        scope, name, name_loc, name_use, variant_generic_arguments,
      )
  }
}

///|
fn Resolver::resolve_unqualified_variant_use(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
  variant_generic_arguments : Array[@syntax.GenericArgument],
) -> ResolvedExpr {
  match self.unqualified_variant_reference(name, name_loc) {
    Symbol(symbol) as reference => {
      name_use.report_payloadless_variant_without_parens(self, symbol, name)
      name_use.resolve_as_variant(
        self, scope, name, name_loc, variant_generic_arguments, reference,
      )
    }
    Ambiguous(_) as reference =>
      name_use.resolve_as_variant(
        self, scope, name, name_loc, variant_generic_arguments, reference,
      )
    Unresolved(..) | UnresolvedUnqualified(_) =>
      name_use.resolve_as_unresolved_value(self, scope, name, name_loc)
  }
}

///|
fn Resolver::resolve_module_value_field_chain(
  self : Resolver,
  scope : ResolveScope,
  expr : @syntax.Expr,
  loc : SourceSpan,
) -> ResolvedExpr? {
  guard dotted_segments(expr) is Some(segments) else { return None }
  if segments.length() < 2 {
    return None
  }
  let full_name = segments.join(".")
  let module_path_text = dotted_prefix_text(segments, segments.length() - 1)
  let value_name = segments[segments.length() - 1]
  match self.module_binding(module_path_text) {
    Some(module_) => {
      self.record_import_use(module_.import_origin, loc)
      if scope.value_reference(segments[0]) is Symbol(_) {
        self.report(AmbiguousModuleValue(full_name), loc)
        return Some(Var(name=full_name, reference=Unresolved(full_name), loc~))
      }
      for value in module_.interface.values {
        if value.name == value_name {
          return Some(Var(name=full_name, reference=Symbol(value.symbol), loc~))
        }
      }
      self.report(UnresolvedValue(full_name), loc)
      Some(Var(name=full_name, reference=Unresolved(full_name), loc~))
    }
    None =>
      if self.has_imported_module_prefix(segments) {
        self.report(UnresolvedValue(full_name), loc)
        Some(Var(name=full_name, reference=Unresolved(full_name), loc~))
      } else {
        None
      }
  }
}

///|
fn dotted_segments(expr : @syntax.Expr) -> Array[String]? {
  match expr {
    Var(name, ..) => Some([name])
    Field(base~, name~, ..) =>
      match dotted_segments(base) {
        Some(segments) => {
          segments.push(name)
          Some(segments)
        }
        None => None
      }
    _ => None
  }
}

///|
fn dotted_prefix_text(segments : Array[String], end : Int) -> String {
  let prefix = []
  for index in 0..<end {
    prefix.push(segments[index])
  }
  prefix.join(".")
}

///|
fn Resolver::module_binding(
  self : Resolver,
  path_text : String,
) -> ModuleBinding? {
  for binding in self.modules {
    if binding.path_text == path_text {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::has_imported_module_prefix(
  self : Resolver,
  segments : Array[String],
) -> Bool {
  for end in 1..<(segments.length() - 1) {
    if self.module_binding(dotted_prefix_text(segments, end)) is Some(_) {
      return true
    }
  }
  false
}

///|
fn UnqualifiedNameUse::resolve_as_value(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  reference : ResolvedValueReference,
) -> ResolvedExpr {
  match self {
    BareUse(loc) => Var(name~, reference~, loc~)
    CallUse(arguments~, loc~) =>
      Call(
        callee=Var(name~, reference~, loc=name_loc),
        arguments=arguments.map(fn(argument) {
          argument.resolve_call_argument(resolver, scope)
        }),
        loc~,
      )
  }
}

///|
fn UnqualifiedNameUse::resolve_as_variant(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  variant_generic_arguments : Array[@syntax.GenericArgument],
  reference : ResolvedVariantReference,
) -> ResolvedExpr {
  let resolved_variant_generic_arguments = variant_generic_arguments.map(fn(
    argument,
  ) {
    argument.resolve_generic_argument(resolver, scope)
  })
  match self {
    BareUse(loc) =>
      UnqualifiedVariant(
        variant=name,
        variant_loc=name_loc,
        variant_generic_arguments=resolved_variant_generic_arguments,
        reference~,
        arguments=[],
        loc~,
      )
    CallUse(arguments~, loc~) =>
      UnqualifiedVariant(
        variant=name,
        variant_loc=name_loc,
        variant_generic_arguments=resolved_variant_generic_arguments,
        reference~,
        arguments=arguments.map(fn(argument) {
          argument.resolve_positional_call_argument(resolver, scope)
        }),
        loc~,
      )
  }
}

///|
fn UnqualifiedNameUse::resolve_as_unresolved_value(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
) -> ResolvedExpr {
  resolver.report(UnresolvedValue(name), self.loc())
  self.resolve_as_value(resolver, scope, name, name_loc, Unresolved(name))
}

///|
fn UnqualifiedNameUse::report_payloadless_variant_without_parens(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  symbol : VariantSymbolId,
  name : String,
) -> Unit {
  guard self is BareUse(_) else { return }
  guard resolver.registry.variant_metadata(symbol) is Some(metadata) else {
    return
  }
  if metadata.payload_count == 0 {
    resolver.report(PayloadlessVariantWithoutParens(name), self.loc())
  }
}

///|
fn UnqualifiedNameUse::loc(self : UnqualifiedNameUse) -> SourceSpan {
  match self {
    BareUse(loc) | CallUse(loc~, ..) => loc
  }
}

///|
/// Resolves call syntax whose callee was parsed as an expression.
///
/// Example: `f(x)` resolves to a value call when `f` is visible as a value,
/// while `some(x)` resolves to an unqualified enum variant call when no value
/// named `some` is visible and enum variants named `some` are available.
fn @syntax.Expr::resolve_call(
  self : @syntax.Expr,
  resolver : Resolver,
  scope : ResolveScope,
  arguments : Array[@syntax.CallArgument],
  loc : SourceSpan,
) -> ResolvedExpr {
  match self {
    TypeApplication(
      callee=Var(name, loc=name_loc),
      arguments=type_arguments,
      ..
    ) =>
      match scope.value_reference(name) {
        Symbol(_) =>
          Call(
            callee=self.resolve_expr(resolver, scope),
            arguments=arguments.map(fn(argument) {
              argument.resolve_call_argument(resolver, scope)
            }),
            loc~,
          )
        Unresolved(_) =>
          resolver.resolve_unqualified_name_use_with_variant_arguments(
            scope,
            name,
            name_loc,
            CallUse(arguments~, loc~),
            type_arguments,
          )
      }
    Var(name, loc=name_loc) =>
      resolver.resolve_unqualified_name_use(
        scope,
        name,
        name_loc,
        CallUse(arguments~, loc~),
      )
    Field(..) =>
      match resolver.resolve_module_value_field_chain(scope, self, self.loc()) {
        Some(callee) =>
          Call(
            callee~,
            arguments=arguments.map(fn(argument) {
              argument.resolve_call_argument(resolver, scope)
            }),
            loc~,
          )
        None =>
          Call(
            callee=self.resolve_expr(resolver, scope),
            arguments=arguments.map(fn(argument) {
              argument.resolve_call_argument(resolver, scope)
            }),
            loc~,
          )
      }
    _ =>
      Call(
        callee=self.resolve_expr(resolver, scope),
        arguments=arguments.map(fn(argument) {
          argument.resolve_call_argument(resolver, scope)
        }),
        loc~,
      )
  }
}

///|
/// Resolves the expression carried by a call argument.
///
/// Example: `op_add(1, 2, op=custom)` preserves the `custom` expression for
/// later contextual-argument checking. Full named argument validation belongs
/// to the type checker because it needs callee metadata.
fn @syntax.CallArgument::resolve_call_argument(
  self : @syntax.CallArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedCallArgument {
  match self {
    Positional(value~, loc~) =>
      Positional(value=value.resolve_expr(resolver, scope), loc~)
    Named(name~, value~, loc~) =>
      Named(name~, value=value.resolve_expr(resolver, scope), loc~)
  }
}

///|
/// Resolves a call argument in a syntactic position that only accepts
/// positional values.
///
/// Example: variant construction accepts `some(x)`, while named contextual
/// arguments are reserved for direct function calls and are therefore reduced
/// to their value expression here.
fn @syntax.CallArgument::resolve_positional_call_argument(
  self : @syntax.CallArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedExpr {
  match self {
    Positional(value~, ..) => value.resolve_expr(resolver, scope)
    Named(value~, ..) => value.resolve_expr(resolver, scope)
  }
}

///|
/// Resolves one struct literal field value or field pun.
///
/// Example: `Point::{ x }` records the visible value reference for `x`, while
/// `Point::{ x: value }` resolves `value` now.
fn @syntax.StructLiteralField::resolve_struct_literal_field(
  self : @syntax.StructLiteralField,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedStructLiteralField {
  match self {
    Value(name~, value~, loc~) => {
      let punned_reference = match value {
        Some(_) => None
        None => {
          let reference = scope.value_reference(name)
          resolver.record_import_use(scope.value_import_origin(reference), loc)
          resolver.report_unresolved_value(reference, loc)
          Some(reference)
        }
      }
      Value(
        name~,
        value=value.map(fn(value) { value.resolve_expr(resolver, scope) }),
        punned_reference~,
        loc~,
      )
    }
    TypeWitness(name~, witness~, loc~) =>
      TypeWitness(name~, witness=witness.resolve_type(resolver, scope), loc~)
  }
}

///|
fn resolve_struct_literal_fields(
  fields : Array[@syntax.StructLiteralField],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedStructLiteralField] {
  fields.map(fn(field) { field.resolve_struct_literal_field(resolver, scope) })
}

///|
/// Resolves a function literal parameter and binds it in the literal body scope.
///
/// Example: in `fn(x) { x }`, `x` gets a value symbol even when its type
/// annotation is absent and must be inferred later from context.
fn @syntax.FunctionLiteralParameter::resolve_function_literal_parameter(
  self : @syntax.FunctionLiteralParameter,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedFunctionLiteralParameter {
  let type_annotation = self.type_annotation.map(fn(type_) {
    type_.resolve_type(resolver, scope)
  })
  let symbol = resolver.registry.define_value(
    self.name,
    Parameter,
    self.name_loc,
  )
  scope.define_value(self.name, symbol, type_annotation)
  {
    symbol,
    is_offered: self.is_offered,
    name: self.name,
    name_loc: self.name_loc,
    type_annotation,
    loc: self.loc,
  }
}

///|
/// Resolves a local block item in source order.
///
/// Example: a local `let` extends the following scope, and a local `fn` binds
/// its name before resolving its body.
fn @syntax.LocalItem::resolve_local_item(
  self : @syntax.LocalItem,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedLocalItem {
  match self {
    Let(declaration) =>
      Let(declaration.resolve_let(resolver, scope, LocalBinding))
    PatternLet(declaration) =>
      PatternLet(declaration.resolve_pattern_let(resolver, scope))
    Function(declaration) => {
      let symbol = resolver.registry.define_value(
        declaration.name,
        LocalFunction,
        declaration.loc,
      )
      scope.define_value(declaration.name, symbol, None)
      // The local function name is inserted before its body is resolved, so the
      // function can call itself after the declaration has been reached.
      Function(
        declaration.resolve_function_with_symbol(resolver, symbol, scope),
      )
    }
    Offer(declaration) =>
      Offer(declaration.resolve_local_offer(resolver, scope))
    Expression(expression~) =>
      Expression(expression.resolve_expr(resolver, scope))
  }
}

///|
fn @syntax.PatternLetDeclaration::resolve_pattern_let(
  self : @syntax.PatternLetDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedPatternLetDeclaration {
  let initializer = self.initializer.resolve_expr(resolver, scope)
  let type_annotation = self.type_annotation.map(fn(type_) {
    type_.resolve_type(resolver, scope)
  })
  let pattern = self.pattern.resolve_pattern(resolver, scope)
  { pattern, type_annotation, initializer, loc: self.loc }
}

///|
/// Resolves a local offered value declaration.
///
/// Example: `{ offer ops : Add[Int] = value; body }` defines `ops` for later
/// local items and marks it for Contextual Resolution.
fn @syntax.OfferDeclaration::resolve_local_offer(
  self : @syntax.OfferDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedOfferDeclaration {
  self.resolve_offer_value(resolver, scope, LocalBinding)
}

///|
/// Resolves a match arm with pattern binders visible only in the arm body.
///
/// Example: in `Option::some(x) => x`, the pattern binder `x` is added to a
/// copied arm scope before resolving the body expression.
fn @syntax.MatchArm::resolve_match_arm(
  self : @syntax.MatchArm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedMatchArm {
  let arm_scope = scope.copy()
  {
    pattern: self.pattern.resolve_pattern(resolver, arm_scope),
    body: self.body.resolve_expr(resolver, arm_scope),
    loc: self.loc,
  }
}

///|
fn @syntax.HandlerWithBlock::resolve_handler_with_block(
  self : @syntax.HandlerWithBlock,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedHandlerWithBlock {
  {
    arms: self.arms.map(fn(arm) {
      arm.resolve_handler_operation_arm(resolver, scope)
    }),
    loc: self.loc,
  }
}

///|
fn @syntax.HandlerOperationArm::resolve_handler_operation_arm(
  self : @syntax.HandlerOperationArm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedHandlerOperationArm {
  let arm_scope = scope.copy()
  let type_binders = resolver.resolve_type_parameter_names(
    self.type_binders.map(fn(binder) { binder.name }),
    self.loc,
  )
  arm_scope.type_parameters.append(type_binders)
  let payload_patterns = self.payload_patterns.map(fn(pattern) {
    pattern.resolve_pattern(resolver, arm_scope)
  })
  let resume_symbol = resolver.registry.define_value(
    self.resume_binder,
    PatternBinder,
    self.resume_loc,
  )
  arm_scope.define_value(self.resume_binder, resume_symbol, None)
  {
    name: self.name.resolve_effect_operation_name(resolver, scope),
    type_binders,
    payload_patterns,
    resume_symbol,
    resume_binder: self.resume_binder,
    resume_loc: self.resume_loc,
    body: self.body.resolve_expr(resolver, arm_scope),
    loc: self.loc,
  }
}

///|
fn @syntax.HandlerFinalBranch::resolve_handler_final_branch(
  self : @syntax.HandlerFinalBranch,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedHandlerFinalBranch {
  let branch_scope = scope.copy()
  let binder_symbol = resolver.registry.define_value(
    self.binder,
    PatternBinder,
    self.binder_loc,
  )
  branch_scope.define_value(self.binder, binder_symbol, None)
  {
    binder_symbol,
    binder: self.binder,
    binder_loc: self.binder_loc,
    body: self.body.resolve_expr(resolver, branch_scope),
    loc: self.loc,
  }
}

///|
/// Resolves a pattern and binds any pattern variables into the current arm scope.
///
/// Example: `Point::{ x }` resolves a struct pattern field, while `x` alone
/// creates a pattern binder rather than resolving a value reference.
fn @syntax.Pattern::resolve_pattern(
  self : @syntax.Pattern,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedPattern {
  match self {
    Wildcard(loc) => Wildcard(loc)
    Binding(name, loc~) => {
      let symbol = resolver.registry.define_value(name, PatternBinder, loc)
      scope.define_value(name, symbol, None)
      Binding(name~, symbol~, loc~)
    }
    IntLiteral(value, loc~) => IntLiteral(value, loc~)
    DoubleLiteral(value, loc~) => DoubleLiteral(value, loc~)
    StringLiteral(value, loc~) => StringLiteral(value, loc~)
    BoolLiteral(value, loc~) => BoolLiteral(value, loc~)
    QualifiedVariant(
      type_name~,
      type_name_loc~,
      variant~,
      variant_loc~,
      type_binders~,
      arguments~,
      loc~
    ) => {
      let type_binders = resolver.resolve_type_parameter_names(
        type_binders.map(fn(binder) { binder.name }),
        loc,
      )
      scope.type_parameters.append(type_binders)
      QualifiedVariant(
        type_name~,
        type_name_loc~,
        variant~,
        variant_loc~,
        type_binders~,
        reference=resolver.variant_reference(type_name, variant, variant_loc),
        arguments=arguments.map(fn(argument) {
          argument.resolve_pattern(resolver, scope)
        }),
        loc~,
      )
    }
    UnqualifiedVariant(variant~, variant_loc~, type_binders~, arguments~, loc~) => {
      let type_binders = resolver.resolve_type_parameter_names(
        type_binders.map(fn(binder) { binder.name }),
        loc,
      )
      scope.type_parameters.append(type_binders)
      UnqualifiedVariant(
        variant~,
        variant_loc~,
        type_binders~,
        arguments=arguments.map(fn(argument) {
          argument.resolve_pattern(resolver, scope)
        }),
        loc~,
      )
    }
    Struct(type_name~, type_name_loc~, fields~, loc~) => {
      let reference = resolver.type_reference(type_name, type_name_loc)
      let owner = match reference {
        Symbol(symbol) => Some(symbol)
        Unresolved(_) => None
      }
      Struct(
        type_name~,
        type_name_loc~,
        reference~,
        fields=resolve_struct_pattern_fields(fields, resolver, scope, owner),
        loc~,
      )
    }
  }
}

///|
/// Resolves one struct pattern field and its nested pattern.
///
/// Example: in `Point::{ x: Option::some(y) }`, the field name is kept and the
/// nested variant pattern is recursively resolved.
fn @syntax.StructPatternField::resolve_struct_pattern_field(
  self : @syntax.StructPatternField,
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId?,
) -> ResolvedStructPatternField {
  match self {
    Value(name~, pattern~, loc~) => {
      if pattern is None && owner_has_type_member(resolver, owner, name) {
        return resolver.resolve_pattern_type_binder(scope, name, loc)
      }
      let pattern = match pattern {
        Some(pattern) => pattern.resolve_pattern(resolver, scope)
        None => {
          let symbol = resolver.registry.define_value(name, PatternBinder, loc)
          scope.define_value(name, symbol, None)
          Binding(name~, symbol~, loc~)
        }
      }
      Value(name~, pattern~, loc~)
    }
    TypeBinder(name~, loc~) =>
      resolver.resolve_pattern_type_binder(scope, name, loc)
    TypeWildcard(loc~) => resolver.resolve_pattern_type_wildcard(scope, loc)
  }
}

///|
fn Resolver::resolve_pattern_type_binder(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  loc : SourceSpan,
) -> ResolvedStructPatternField {
  let symbol = self.registry.define_type_parameter(name, loc)
  let type_parameter = { symbol, name, name_loc: loc, kind: None, loc }
  scope.type_parameters.push(type_parameter)
  TypeBinder(name~, type_parameter~, loc~)
}

///|
fn Resolver::resolve_pattern_type_wildcard(
  self : Resolver,
  scope : ResolveScope,
  loc : SourceSpan,
) -> ResolvedStructPatternField {
  let symbol = self.registry.define_type_parameter("_", loc)
  let type_parameter : ResolvedTypeParameter = {
    symbol,
    name: "_",
    name_loc: loc,
    kind: None,
    loc,
  }
  scope.type_parameters.push(type_parameter)
  TypeWildcard(type_parameter~, loc~)
}

///|
fn owner_has_type_member(
  resolver : Resolver,
  owner : TypeSymbolId?,
  name : String,
) -> Bool {
  if owner is Some(owner) {
    resolver.type_has_member(owner, name)
  } else {
    false
  }
}

///|
fn resolve_struct_pattern_fields(
  fields : Array[@syntax.StructPatternField],
  resolver : Resolver,
  scope : ResolveScope,
  owner : TypeSymbolId?,
) -> Array[ResolvedStructPatternField] {
  fields.map(fn(field) {
    field.resolve_struct_pattern_field(resolver, scope, owner)
  })
}

///|
fn Resolver::scope(
  self : Resolver,
  type_parameters : Array[ResolvedTypeParameter],
) -> ResolveScope {
  { values: self.top_values.copy(), type_parameters: type_parameters.copy() }
}

///|
fn Resolver::ordered_scope(
  self : Resolver,
  type_parameters : Array[ResolvedTypeParameter],
) -> ResolveScope {
  {
    values: self.ordered_top_values.copy(),
    type_parameters: type_parameters.copy(),
  }
}

///|
fn Resolver::type_symbol(self : Resolver, name : String) -> TypeSymbolId {
  self.type_binding(name).unwrap().symbol
}

///|
fn Resolver::type_reference(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> ResolvedTypeReference {
  match self.type_binding(name) {
    Some(binding) => {
      self.record_import_use(binding.import_origin, loc)
      Symbol(binding.symbol)
    }
    None =>
      match qualified_name_text(name) {
        Some(qualified) =>
          match self.module_binding(qualified.module_path) {
            Some(module_) => {
              self.record_import_use(module_.import_origin, loc)
              match module_.interface.type_symbol_named(qualified.name) {
                Some(symbol) => Symbol(symbol)
                None => Unresolved(name)
              }
            }
            None => Unresolved(name)
          }
        None => Unresolved(name)
      }
  }
}

///|
fn Resolver::qualified_type_symbol_opt(
  self : Resolver,
  name : String,
) -> TypeSymbolId? {
  match qualified_name_text(name) {
    Some(qualified) =>
      match self.module_binding(qualified.module_path) {
        Some(module_) => module_.interface.type_symbol_named(qualified.name)
        None => None
      }
    None => None
  }
}

///|
fn @module_interface.ModuleInterface::type_symbol_named(
  self : @module_interface.ModuleInterface,
  name : String,
) -> TypeSymbolId? {
  for type_ in self.types {
    match type_ {
      Struct(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      Enum(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      _ => ()
    }
  }
  None
}

///|
fn qualified_name_text(name : String) -> QualifiedNameText? {
  let parts = name.split(".").map(StringView::to_owned).collect()
  if parts.length() < 2 {
    return None
  }
  let module_segments = []
  for index in 0..<(parts.length() - 1) {
    module_segments.push(parts[index])
  }
  Some({
    module_path: module_segments.join("."),
    name: parts[parts.length() - 1],
  })
}

///|
fn Resolver::type_binding(self : Resolver, name : String) -> TypeBinding? {
  for index = self.types.length(); index > 0; index = index - 1 {
    let binding = self.types[index - 1]
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::type_binding_for_symbol(
  self : Resolver,
  symbol : TypeSymbolId,
) -> TypeBinding? {
  for binding in self.types {
    if binding.symbol == symbol {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::field_symbol_opt(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> FieldSymbolId? {
  if self.type_binding_for_symbol(owner) is Some(binding) {
    for field in binding.fields {
      if field.name == name {
        return Some(field.symbol)
      }
    }
  }
  for module_ in self.modules {
    for type_ in module_.interface.types {
      if type_ is Struct(declaration) && declaration.symbol == owner {
        for field in declaration.fields {
          if field.name == name {
            return Some(field.symbol)
          }
        }
      }
    }
  }
  None
}

///|
fn Resolver::field_symbol(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> FieldSymbolId {
  self.field_symbol_opt(owner, name).unwrap()
}

///|
fn Resolver::type_has_member(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> Bool {
  if self.type_binding_for_symbol(owner) is Some(binding) {
    return binding.type_members.contains(name)
  }
  for module_ in self.modules {
    for type_ in module_.interface.types {
      if type_ is Struct(declaration) && declaration.symbol == owner {
        return declaration.type_members.any(fn(item) { item.name == name })
      }
    }
  }
  false
}

///|
fn Resolver::type_import_origin(self : Resolver, symbol : TypeSymbolId) -> Int? {
  for binding in self.types {
    if binding.symbol == symbol {
      return binding.import_origin
    }
  }
  None
}

///|
fn Resolver::publish_type_binding(
  self : Resolver,
  name : String,
  symbol : TypeSymbolId,
  parameter_kinds : Array[@types.Kind],
  type_members? : Array[String] = [],
  fields? : Array[FieldBinding] = [],
  variants? : Array[VariantBinding] = [],
  import_origin : Int?,
) -> Unit {
  self.types.push({
    name,
    symbol,
    parameter_kinds,
    type_members,
    fields,
    variants,
    import_origin,
  })
  self.record_import_symbol(import_origin, TypeSymbol(symbol))
}

///|
fn Resolver::effect_symbol(self : Resolver, name : String) -> EffectSymbolId {
  self.effect_binding(name).unwrap().symbol
}

///|
fn Resolver::effect_symbol_opt(
  self : Resolver,
  name : String,
) -> EffectSymbolId? {
  self.effect_binding(name).map(fn(binding) { binding.symbol })
}

///|
fn Resolver::effect_binding(self : Resolver, name : String) -> EffectBinding? {
  for index = self.effects.length(); index > 0; index = index - 1 {
    let binding = self.effects[index - 1]
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::effect_binding_for_symbol(
  self : Resolver,
  symbol : EffectSymbolId,
) -> EffectBinding? {
  for binding in self.effects {
    if binding.symbol == symbol {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::effect_import_origin(
  self : Resolver,
  symbol : EffectSymbolId,
) -> Int? {
  for binding in self.effects {
    if binding.symbol == symbol {
      return binding.import_origin
    }
  }
  None
}

///|
fn Resolver::publish_effect_binding(
  self : Resolver,
  name : String,
  symbol : EffectSymbolId,
  parameter_kinds : Array[@types.Kind],
  operations? : Array[OperationBinding] = [],
  import_origin : Int?,
) -> Unit {
  self.effects.push({ name, symbol, parameter_kinds, operations, import_origin })
  self.record_import_symbol(import_origin, EffectSymbol(symbol))
}

///|
fn Resolver::operation_reference(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> ResolvedOperationReference {
  match self.operation_binding(owner, name) {
    Some(symbol) => Symbol(symbol)
    None => Unresolved(name)
  }
}

///|
fn Resolver::unqualified_operation_reference(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> ResolvedOperationReference {
  let candidates = []
  for binding in self.effects {
    for operation in binding.operations {
      if operation.name == name && !candidates.contains(operation.symbol) {
        candidates.push(operation.symbol)
      }
    }
  }
  match candidates.length() {
    0 => Unresolved(name)
    1 => {
      if self.registry.operation_metadata(candidates[0]) is Some(metadata) {
        self.record_import_use(self.effect_import_origin(metadata.owner), loc)
      }
      Symbol(candidates[0])
    }
    _ => Ambiguous(name~, candidates~)
  }
}

///|
fn Resolver::operation_symbol(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> OperationSymbolId {
  self.operation_binding(owner, name).unwrap()
}

///|
fn Resolver::operation_binding(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> OperationSymbolId? {
  if self.effect_binding_for_symbol(owner) is Some(binding) {
    for operation in binding.operations {
      if operation.name == name {
        return Some(operation.symbol)
      }
    }
  }
  for module_ in self.modules {
    for effect in module_.interface.effects {
      if effect.symbol == owner {
        for operation in effect.operations {
          if operation.name == name {
            return Some(operation.symbol)
          }
        }
      }
    }
  }
  None
}

///|
fn Resolver::value_symbol(self : Resolver, name : String) -> ValueSymbolId {
  for binding in self.top_values {
    if binding.name == name {
      if binding.reference is Symbol(symbol) {
        return symbol
      }
    }
  }
  abort("missing predeclared value symbol")
}

///|
fn Resolver::top_value_binding(self : Resolver, name : String) -> ValueBinding? {
  for index = self.top_values.length(); index > 0; index = index - 1 {
    let binding = self.top_values[index - 1]
    if binding.name == name && binding.kind == Plain {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::ordered_top_value_binding(
  self : Resolver,
  name : String,
) -> ValueBinding? {
  for index = self.ordered_top_values.length(); index > 0; index = index - 1 {
    let binding = self.ordered_top_values[index - 1]
    if binding.name == name && binding.kind == Plain {
      return Some(binding)
    }
  }
  None
}

///|
fn Resolver::publish_complete_top_level_binding(
  self : Resolver,
  binding : ValueBinding,
  loc : SourceSpan,
) -> Unit {
  match binding.kind {
    Plain =>
      match self.top_value_binding(binding.name) {
        Some(existing) =>
          if !self.has_conflicting_top_value_name(binding.name) {
            self.report_conflicting_top_level_value(binding, existing, loc)
          }
        None => self.top_values.push(binding)
      }
  }
}

///|
fn Resolver::publish_ordered_top_level_binding(
  self : Resolver,
  binding : ValueBinding,
  loc : SourceSpan,
) -> Unit {
  match binding.kind {
    Plain =>
      match self.ordered_top_value_binding(binding.name) {
        Some(existing) =>
          if !self.has_conflicting_top_value_name(binding.name) {
            self.report_conflicting_top_level_value(binding, existing, loc)
          }
        None => self.ordered_top_values.push(binding)
      }
  }
}

///|
fn Resolver::has_conflicting_top_value_name(
  self : Resolver,
  name : String,
) -> Bool {
  self.conflicting_top_value_names.any(fn(conflicting) { conflicting == name })
}

///|
fn Resolver::report_conflicting_top_level_value(
  self : Resolver,
  incoming : ValueBinding,
  existing : ValueBinding,
  loc : SourceSpan,
) -> Unit {
  self.conflicting_top_value_names.push(incoming.name)
  self.report(
    ConflictingTopLevelValue(
      name=incoming.name,
      existing=self.binding_display(existing),
      incoming=self.binding_display(incoming),
      existing_source_id=binding_source_id(existing),
      existing_loc=self.binding_loc(existing),
      existing_origin=binding_origin(existing),
    ),
    loc,
  )
}

///|
fn Resolver::binding_display(self : Resolver, binding : ValueBinding) -> String {
  match binding.reference {
    Symbol(symbol) =>
      match self.registry.value_metadata(symbol) {
        Some(metadata) => metadata.name
        None => binding.name
      }
    Unresolved(name) => name
  }
}

///|
fn binding_source_id(binding : ValueBinding) -> String? {
  match binding.source {
    ExternalSource(source_id~) => Some(source_id)
    _ => None
  }
}

///|
fn Resolver::binding_loc(
  self : Resolver,
  binding : ValueBinding,
) -> SourceSpan? {
  match binding.source {
    NoSource(_) => None
    _ =>
      match binding.reference {
        Symbol(symbol) =>
          match self.registry.value_metadata(symbol) {
            Some(metadata) => Some(metadata.loc)
            None => None
          }
        Unresolved(_) => None
      }
  }
}

///|
fn binding_origin(binding : ValueBinding) -> String? {
  match binding.source {
    NoSource(origin~) => Some(origin)
    _ => None
  }
}

///|
fn Resolver::variant_reference(
  self : Resolver,
  type_name : String,
  variant : String,
  loc : SourceSpan,
) -> ResolvedVariantReference {
  if self.qualified_variant_symbol(type_name, variant, loc) is Some(symbol) {
    return Symbol(symbol)
  }
  if self.type_binding(type_name) is Some(binding) {
    self.record_import_use(binding.import_origin, loc)
    for item in binding.variants {
      if item.name == variant {
        return Symbol(item.symbol)
      }
    }
    resolver_report_qualified_variant(self, type_name, variant, loc)
    Unresolved(type_name~, variant~)
  } else {
    resolver_report_qualified_variant(self, type_name, variant, loc)
    Unresolved(type_name~, variant~)
  }
}

///|
fn Resolver::variant_symbol(
  self : Resolver,
  owner : TypeSymbolId,
  name : String,
) -> VariantSymbolId {
  if self.type_binding_for_symbol(owner) is Some(binding) {
    for variant in binding.variants {
      if variant.name == name {
        return variant.symbol
      }
    }
  }
  abort("missing predeclared variant symbol")
}

///|
fn Resolver::qualified_variant_symbol(
  self : Resolver,
  type_name : String,
  variant : String,
  loc : SourceSpan,
) -> VariantSymbolId? {
  match qualified_name_text(type_name) {
    Some(qualified) =>
      match self.module_binding(qualified.module_path) {
        Some(module_) => {
          self.record_import_use(module_.import_origin, loc)
          module_.interface.variant_symbol_named(qualified.name, variant)
        }
        None => None
      }
    None => None
  }
}

///|
fn @module_interface.ModuleInterface::variant_symbol_named(
  self : @module_interface.ModuleInterface,
  type_name : String,
  variant : String,
) -> VariantSymbolId? {
  for type_ in self.types {
    match type_ {
      Enum(declaration) if declaration.name == type_name =>
        for item in declaration.variants {
          if item.name == variant {
            return Some(item.symbol)
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn Resolver::unqualified_variant_reference(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> ResolvedVariantReference {
  let candidates = []
  for binding in self.types {
    for variant in binding.variants {
      if variant.name == name && !candidates.contains(variant.symbol) {
        candidates.push(variant.symbol)
      }
    }
  }
  match candidates.length() {
    0 => UnresolvedUnqualified(name)
    1 => {
      if self.registry.variant_metadata(candidates[0]) is Some(metadata) {
        self.record_import_use(self.type_import_origin(metadata.owner), loc)
      }
      Symbol(candidates[0])
    }
    _ => {
      self.report(
        AmbiguousUnqualifiedVariant(
          name~,
          candidates=candidates.map(fn(candidate) {
            self.variant_candidate(candidate)
          }),
        ),
        loc,
      )
      Ambiguous(name~, candidates~)
    }
  }
}

///|
fn Resolver::variant_candidate(
  self : Resolver,
  symbol : VariantSymbolId,
) -> ResolveVariantCandidate {
  match self.registry.variant_metadata(symbol) {
    Some(variant) =>
      match self.registry.type_metadata(variant.owner) {
        Some(owner) => { owner: owner.name, variant: variant.name }
        None => { owner: "<unknown>", variant: variant.name }
      }
    None => { owner: "<unknown>", variant: "<unknown>" }
  }
}

///|
fn Resolver::report(
  self : Resolver,
  kind : ResolveDiagnosticKind,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({ kind, loc })
}

///|
fn Resolver::report_unresolved_value(
  self : Resolver,
  reference : ResolvedValueReference,
  loc : SourceSpan,
) -> Unit {
  match reference {
    Symbol(_) => ()
    Unresolved(name) => self.report(UnresolvedValue(name), loc)
  }
}

///|
fn Resolver::report_unresolved_field(
  self : Resolver,
  owner : TypeSymbolId,
  field : String,
  loc : SourceSpan,
) -> Unit {
  let type_name = match self.registry.type_metadata(owner) {
    Some(metadata) => metadata.name
    None => "<unknown>"
  }
  self.report(UnresolvedField(type_name~, field~), loc)
}

///|
fn resolver_report_qualified_variant(
  resolver : Resolver,
  type_name : String,
  variant : String,
  loc : SourceSpan,
) -> Unit {
  resolver.report(UnresolvedQualifiedVariant(type_name~, variant~), loc)
}

///|
fn primitive_type(name : String) -> @types.PrimitiveType? {
  match name {
    "Int" => Some(Int)
    "Double" => Some(Double)
    "Bool" => Some(Bool)
    "String" => Some(String)
    "Unit" => Some(Unit)
    _ => None
  }
}
