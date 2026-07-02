///|
priv struct Resolver {
  registry : SymbolRegistry
  modules : Array[ModuleBinding]
  types : Array[TypeBinding]
  effects : Array[EffectBinding]
  type_aliases : Array[TypeAliasBinding]
  top_values : Array[ValueBinding]
  ordered_top_values : Array[ValueBinding]
  diagnostics : Array[ResolveDiagnostic]
}

///|
priv struct ModuleBinding {
  path_text : String
  interface : @module_interface.ModuleInterface
}

///|
priv struct TypeBinding {
  name : String
  symbol : TypeSymbolId
}

///|
priv struct EffectBinding {
  name : String
  symbol : EffectSymbolId
}

///|
priv struct TypeAliasBinding {
  name : String
}

///|
priv struct QualifiedNameText {
  module_path : String
  name : String
}

///|
/// Resolves a syntax source file and returns only the resolved source.
///
/// Example: a parsed file containing `struct Point { x : Int }` becomes a
/// resolved file whose `Point` type and `x` field have stable compiler symbols.
pub fn resolve_source_file(source : @syntax.SourceFile) -> ResolvedSourceFile {
  resolve_source_file_result(source).source
}

///|
/// Resolves a syntax source file and returns diagnostics with the result.
///
/// Example: resolving `fn f(x : Missing) -> Int { x }` records an unresolved
/// type diagnostic while still returning a resolved tree for later phases.
pub fn resolve_source_file_result(source : @syntax.SourceFile) -> ResolveResult {
  let resolver = Resolver::Resolver(SymbolRegistry())
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
  let resolver = Resolver::Resolver(registry)
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
    declarations,
    loc: source.loc,
  }
  { source: resolved, diagnostics: self.diagnostics }
}

///|
fn Resolver::Resolver(registry : SymbolRegistry) -> Resolver {
  {
    registry,
    modules: [],
    types: [],
    effects: [],
    type_aliases: [],
    top_values: [],
    ordered_top_values: [],
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
      Qualified(module_path~, ..) =>
        self.publish_imported_module_binding(module_path, imported_environment)
      Open(module_path~, loc~) =>
        match
          imported_environment.find(
            @module_interface.module_path_text(module_path),
          ) {
          Some(imported) => {
            self.publish_imported_module_binding(
              module_path, imported_environment,
            )
            self.publish_imported_public_types(imported)
            self.publish_imported_public_effects(imported)
            self.publish_imported_public_values(imported, loc)
          }
          None => ()
        }
      Selective(module_path~, items~, loc~) =>
        match
          imported_environment.find(
            @module_interface.module_path_text(module_path),
          ) {
          Some(imported) => {
            self.publish_imported_module_binding(
              module_path, imported_environment,
            )
            self.publish_imported_selected_types(imported, items)
            self.publish_imported_selected_effects(imported, items)
            self.publish_imported_selected_values(imported, items)
          }
          None => ignore(loc)
        }
    }
  }
}

///|
fn Resolver::publish_imported_module_binding(
  self : Resolver,
  module_path : @syntax.ModulePath,
  imported_environment : @module_interface.ImportedEnvironment,
) -> Unit {
  let path_text = @module_interface.module_path_text(module_path)
  guard imported_environment.find(path_text) is Some(interface) else { return }
  if self.modules.any(fn(binding) { binding.path_text == path_text }) {
    return
  }
  self.modules.push({ path_text, interface })
}

///|
fn Resolver::publish_imported_public_types(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  for type_ in interface.types {
    match type_ {
      Struct(declaration) =>
        self.publish_type_binding(declaration.name, declaration.symbol)
      Enum(declaration) =>
        self.publish_type_binding(declaration.name, declaration.symbol)
    }
  }
  for type_alias in interface.type_aliases {
    self.type_aliases.push({ name: type_alias.name })
  }
}

///|
fn Resolver::publish_imported_public_effects(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  for effect in interface.effects {
    self.publish_effect_binding(effect.name, effect.symbol)
  }
}

///|
fn Resolver::publish_imported_selected_types(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  items : Array[@syntax.ImportItem],
) -> Unit {
  for item in items {
    for type_ in interface.types {
      match type_ {
        Struct(declaration) if declaration.name == item.name =>
          self.publish_type_binding(declaration.name, declaration.symbol)
        Enum(declaration) if declaration.name == item.name =>
          self.publish_type_binding(declaration.name, declaration.symbol)
        _ => ()
      }
    }
    for type_alias in interface.type_aliases {
      if type_alias.name == item.name {
        self.type_aliases.push({ name: type_alias.name })
      }
    }
  }
}

///|
fn Resolver::publish_imported_selected_effects(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  items : Array[@syntax.ImportItem],
) -> Unit {
  for item in items {
    for effect in interface.effects {
      if effect.name == item.name {
        self.publish_effect_binding(effect.name, effect.symbol)
      }
    }
  }
}

///|
fn Resolver::publish_imported_public_values(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  loc : SourceSpan,
) -> Unit {
  for value in interface.values {
    let binding = imported_interface_value_binding(value)
    self.publish_complete_top_level_binding(binding, loc)
    self.publish_ordered_top_level_binding(binding, loc)
  }
}

///|
fn Resolver::publish_imported_selected_values(
  self : Resolver,
  interface : @module_interface.ModuleInterface,
  items : Array[@syntax.ImportItem],
) -> Unit {
  for item in items {
    for value in interface.values {
      if value.name == item.name {
        let binding = imported_interface_value_binding(value)
        self.publish_complete_top_level_binding(binding, item.loc)
        self.publish_ordered_top_level_binding(binding, item.loc)
      }
    }
  }
}

///|
fn imported_interface_value_binding(
  value : @module_interface.ModuleInterfaceValue,
) -> ValueBinding {
  {
    name: value.name,
    reference: Symbol(value.symbol),
    type_: None,
    kind: Plain,
  }
}

///|
fn Resolver::collect_top_level_headers(
  self : Resolver,
  source : @syntax.SourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) =>
        self.publish_type_binding(
          declaration.name,
          self.registry.define_type(
            declaration.name,
            Struct,
            declaration.type_parameters.length(),
            declaration.loc,
          ),
        )
      Enum(declaration) =>
        self.publish_type_binding(
          declaration.name,
          self.registry.define_type(
            declaration.name,
            Enum,
            declaration.type_parameters.length(),
            declaration.loc,
          ),
        )
      Effect(declaration) =>
        self.publish_effect_binding(
          declaration.name,
          self.registry.define_effect(
            declaration.name,
            declaration.type_parameters.length(),
            declaration.loc,
          ),
        )
      TypeAlias(declaration) =>
        self.type_aliases.push({ name: declaration.name })
      Function(declaration) => {
        let symbol = self.registry.define_value(
          declaration.name,
          TopLevelFunction,
          declaration.loc,
        )
        let binding = {
          name: declaration.name,
          reference: Symbol(symbol),
          type_: None,
          kind: Plain,
        }
        self.publish_complete_top_level_binding(binding, declaration.loc)
        self.publish_ordered_top_level_binding(binding, declaration.loc)
      }
      Let(declaration) =>
        if declaration.name is Some(name) {
          let symbol = self.registry.define_value(
            name,
            TopLevelValue,
            declaration.loc,
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
            },
            declaration.loc,
          )
        }
      Offer(declaration) => {
        let symbol = self.registry.define_value(
          declaration.name,
          TopLevelValue,
          declaration.loc,
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
          },
          declaration.loc,
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
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => {
        let owner = self.type_symbol(declaration.name)
        let mut index = 0
        for item in declaration.members {
          if item is Field(field) {
            self.registry.define_field(owner, field.name, index, field.loc)
            |> ignore
            index += 1
          }
        }
      }
      Enum(declaration) => {
        let owner = self.type_symbol(declaration.name)
        for index = 0; index < declaration.variants.length(); index = index + 1 {
          let variant = declaration.variants[index]
          self.registry.define_variant(
            owner,
            variant.name,
            index,
            variant.payload.length(),
            variant.loc,
          )
          |> ignore
        }
      }
      Effect(declaration) => {
        let owner = self.effect_symbol(declaration.name)
        for index in 0..<declaration.operations.length() {
          let operation = declaration.operations[index]
          self.registry.define_operation(
            owner,
            operation.name,
            index,
            operation.payload.length(),
            operation.loc,
          )
          |> ignore
        }
      }
      TypeAlias(_) | Function(_) | Let(_) | Offer(_) => ()
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
    TypeAlias(declaration) =>
      TypeAlias(declaration.resolve_type_alias(resolver))
    Function(declaration) =>
      Function(declaration.resolve_top_level_function(resolver))
    Let(declaration) => Let(declaration.resolve_top_level_let(resolver))
    Offer(declaration) => Offer(declaration.resolve_top_level_offer(resolver))
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
  let type_parameter_symbol = resolver.registry.define_type_parameter(
    self.name,
    self.loc,
  )
  let type_parameter : ResolvedTypeParameter = {
    symbol: type_parameter_symbol,
    name: self.name,
    kind: Some(self.kind.resolve_kind()),
    loc: self.loc,
  }
  let symbol = resolver.registry.define_type_member(
    owner,
    self.name,
    index,
    type_parameter_symbol,
    self.loc,
  )
  scope.type_parameters.push(type_parameter)
  {
    symbol,
    type_parameter,
    name: self.name,
    kind: self.kind.resolve_kind(),
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
  let body = self.body.resolve_type(resolver, scope)
  {
    is_public: self.is_public,
    name: self.name,
    body: if type_parameters.is_empty() {
      body
    } else {
      TypeLambda(parameters=type_parameters, body~, loc=self.loc)
    },
    loc: self.loc,
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
      parameter.loc,
    )
    {
      symbol,
      name: parameter.name,
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
    { symbol, name, kind: None, loc }
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
  let symbol = resolver.registry.field_named(owner, self.name).unwrap()
  let type_ = self.type_.resolve_type(resolver, scope)
  {
    symbol,
    is_offered: self.is_offered,
    name: self.name,
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
  let symbol = resolver.registry.variant_named(owner, self.name).unwrap()
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
  let symbol = resolver.registry.define_value(self.name, Parameter, self.loc)
  scope.define_value(self.name, symbol, Some(type_))
  {
    symbol,
    is_auto: self.is_auto,
    is_offered: self.is_offered,
    name: self.name,
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
  resolver.publish_top_level_let(declaration, self.loc)
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
  let symbol = resolver.registry.define_value(display_name, kind, self.loc)
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
  resolver.publish_top_level_offer(declaration, self.loc)
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
  let symbol = resolver.registry.define_value(self.name, kind, self.loc)
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
              match resolver.type_symbol_opt(name) {
                Some(symbol) => Constructor(symbol~, name~, loc~)
                None =>
                  if resolver.has_type_alias(name) {
                    Alias(name~, loc~)
                  } else {
                    resolver.report(UnresolvedType(name), loc)
                    Unresolved(name~, arguments=[], loc~)
                  }
              }
          }
      }
    QualifiedName(module_path~, name~, loc~) =>
      resolver.resolve_module_qualified_type(module_path, name, loc)
    Apply(callee~, arguments~, loc~) =>
      Apply(
        callee=callee.resolve_type(resolver, scope),
        arguments=arguments.map(fn(argument) {
          argument.resolve_type(resolver, scope)
        }),
        loc~,
      )
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
  }
}

///|
fn @syntax.EffectTerm::resolve_effect_term(
  self : @syntax.EffectTerm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedEffectTerm {
  match self {
    Empty(loc~) => Empty(loc~)
    Term(type_~, loc~) => type_.resolve_effect_type(resolver, scope, loc)
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
  let resolved_arguments = arguments.map(fn(argument) {
    argument.resolve_type(resolver, scope)
  })
  match base {
    Name(name~, ..) =>
      match scope.type_parameter_info(name) {
        Some(parameter) =>
          Parameter(symbol=parameter.symbol, name=parameter.name, loc~)
        None =>
          match resolver.effect_symbol_opt(name) {
            Some(symbol) =>
              Singleton(symbol~, name~, arguments=resolved_arguments, loc~)
            None => {
              resolver.report(UnresolvedType(name), loc)
              Unresolved(name~, arguments=resolved_arguments, loc~)
            }
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      match resolver.qualified_effect_symbol_opt(module_path, name) {
        Some(symbol) =>
          Singleton(symbol~, name~, arguments=resolved_arguments, loc~)
        None => {
          resolver.report(UnresolvedType(name), loc)
          Unresolved(name~, arguments=resolved_arguments, loc~)
        }
      }
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
) -> (@syntax.Type, Array[@syntax.Type]) {
  match self {
    Apply(callee~, arguments~, ..) => (callee, arguments)
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
          return Alias(name=full_name, loc~)
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
  }
}

///|
fn interface_type_symbol(
  type_ : @module_interface.ModuleInterfaceType,
) -> TypeSymbolId {
  match type_ {
    Struct(declaration) => declaration.symbol
    Enum(declaration) => declaration.symbol
  }
}

///|
fn Resolver::has_type_alias(self : Resolver, name : String) -> Bool {
  self.type_aliases.any(fn(type_alias) { type_alias.name == name })
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
    StringLiteral(value, loc~) => StringLiteral(value, loc~)
    BoolLiteral(value, loc~) => BoolLiteral(value, loc~)
    UnitLiteral(loc~) => UnitLiteral(loc~)
    Var(name, loc~) =>
      resolver.resolve_unqualified_name_use(scope, name, loc, BareUse(loc))
    QualifiedVariant(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      arguments~,
      loc~
    ) =>
      QualifiedVariant(
        type_name~,
        type_arguments=type_arguments.map(fn(type_) {
          type_.resolve_type(resolver, scope)
        }),
        variant~,
        variant_type_arguments=variant_type_arguments.map(fn(type_) {
          type_.resolve_type(resolver, scope)
        }),
        reference=resolver.variant_reference(type_name, variant, loc),
        arguments=arguments.map(fn(argument) {
          argument.resolve_expr(resolver, scope)
        }),
        loc~,
      )
    StructLiteral(type_name~, type_arguments~, fields~, loc~) =>
      StructLiteral(
        type_name~,
        type_arguments=type_arguments.map(fn(type_) {
          type_.resolve_type(resolver, scope)
        }),
        fields=resolve_struct_literal_fields(fields, resolver, scope),
        loc~,
      )
    Builtin(name, loc~) => Builtin(name, loc~)
    EffectOperationCall(name~, type_witnesses~, arguments~, loc~) =>
      EffectOperationCall(
        name=name.resolve_effect_operation_name(resolver, scope),
        type_witnesses=type_witnesses.map(fn(type_) {
          type_.resolve_type(resolver, scope)
        }),
        arguments=arguments.map(fn(argument) {
          argument.resolve_expr(resolver, scope)
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
          guard field is Field(base~, name~, ..) else {
            abort("expected field")
          }
          let base = base.resolve_expr(resolver, scope)
          Field(
            base~,
            name~,
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
  }
}

///|
fn @syntax.EffectOperationName::resolve_effect_operation_name(
  self : @syntax.EffectOperationName,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedEffectOperationName {
  match self {
    Qualified(owner~, operation~, loc~) => {
      let owner = owner.resolve_effect_type(resolver, scope, owner.loc())
      let reference = match owner {
        Singleton(symbol~, ..) =>
          resolver.operation_reference(symbol, operation)
        _ => Unresolved(operation)
      }
      Qualified(owner~, operation~, reference~, loc~)
    }
    Shorthand(operation~, loc~) =>
      Shorthand(
        operation~,
        reference=resolver.unqualified_operation_reference(operation),
        loc~,
      )
    Unqualified(operation~, loc~) =>
      Unqualified(
        operation~,
        reference=resolver.unqualified_operation_reference(operation),
        loc~,
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
  match self.nominal_type_of_expr(scope, base) {
    Some(symbol) =>
      match self.registry.field_named(symbol, name) {
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
fn Resolver::nominal_type_of_expr(
  self : Resolver,
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
    StructLiteral(type_name~, ..) => self.type_symbol_opt(type_name)
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
/// unqualified enum variant. Payloadless variants are values, so `none` is the
/// valid form and `none()` is diagnosed here while the original call syntax is
/// still available.
fn Resolver::resolve_unqualified_name_use(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
) -> ResolvedExpr {
  match scope.value_reference(name) {
    Symbol(_) as reference =>
      name_use.resolve_as_value(self, scope, name, name_loc, reference)
    Unresolved(_) =>
      self.resolve_unqualified_variant_use(scope, name, name_loc, name_use)
  }
}

///|
fn Resolver::resolve_unqualified_variant_use(
  self : Resolver,
  scope : ResolveScope,
  name : String,
  name_loc : SourceSpan,
  name_use : UnqualifiedNameUse,
) -> ResolvedExpr {
  match self.unqualified_variant_reference(name, name_use.loc()) {
    Symbol(symbol) as reference => {
      name_use.report_payloadless_variant_call(self, symbol, name)
      name_use.resolve_as_variant(self, scope, name, reference)
    }
    Ambiguous(_) as reference =>
      name_use.resolve_as_variant(self, scope, name, reference)
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
  reference : ResolvedVariantReference,
) -> ResolvedExpr {
  match self {
    BareUse(loc) =>
      UnqualifiedVariant(variant=name, reference~, arguments=[], loc~)
    CallUse(arguments~, loc~) =>
      UnqualifiedVariant(
        variant=name,
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
fn UnqualifiedNameUse::report_payloadless_variant_call(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  symbol : VariantSymbolId,
  name : String,
) -> Unit {
  guard self is CallUse(arguments~, ..) else { return }
  guard arguments.is_empty() else { return }
  guard resolver.registry.variant_metadata(symbol) is Some(metadata) else {
    return
  }
  if metadata.payload_count == 0 {
    resolver.report(PayloadlessVariantCall(name), self.loc())
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
    Positional(expression) =>
      Positional(expression.resolve_expr(resolver, scope))
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
    Positional(expression) => expression.resolve_expr(resolver, scope)
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
  let symbol = resolver.registry.define_value(self.name, Parameter, self.loc)
  scope.define_value(self.name, symbol, type_annotation)
  {
    symbol,
    is_offered: self.is_offered,
    name: self.name,
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
  }
}

///|
fn @syntax.PatternLetDeclaration::resolve_pattern_let(
  self : @syntax.PatternLetDeclaration,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedPatternLetDeclaration {
  let initializer = self.initializer.resolve_expr(resolver, scope)
  let pattern = self.pattern.resolve_pattern(resolver, scope)
  { pattern, initializer, loc: self.loc }
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
    self.type_binders,
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
    StringLiteral(value, loc~) => StringLiteral(value, loc~)
    BoolLiteral(value, loc~) => BoolLiteral(value, loc~)
    QualifiedVariant(type_name~, variant~, type_binders~, arguments~, loc~) => {
      let type_binders = resolver.resolve_type_parameter_names(
        type_binders, loc,
      )
      scope.type_parameters.append(type_binders)
      QualifiedVariant(
        type_name~,
        variant~,
        type_binders~,
        reference=resolver.variant_reference(type_name, variant, loc),
        arguments=arguments.map(fn(argument) {
          argument.resolve_pattern(resolver, scope)
        }),
        loc~,
      )
    }
    ShorthandVariant(variant~, type_binders~, arguments~, loc~) => {
      let type_binders = resolver.resolve_type_parameter_names(
        type_binders, loc,
      )
      scope.type_parameters.append(type_binders)
      ShorthandVariant(
        variant~,
        type_binders~,
        arguments=arguments.map(fn(argument) {
          argument.resolve_pattern(resolver, scope)
        }),
        loc~,
      )
    }
    Struct(type_name~, fields~, loc~) =>
      Struct(
        type_name~,
        fields=resolve_struct_pattern_fields(
          fields,
          resolver,
          scope,
          resolver.type_symbol_opt(type_name),
        ),
        loc~,
      )
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
  let type_parameter = { symbol, name, kind: None, loc }
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
    resolver.registry.type_member_named(owner, name) is Some(_)
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
fn Resolver::type_symbol_opt(self : Resolver, name : String) -> TypeSymbolId? {
  match self.type_binding(name) {
    Some(binding) => Some(binding.symbol)
    None => self.qualified_type_symbol_opt(name)
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
fn Resolver::publish_type_binding(
  self : Resolver,
  name : String,
  symbol : TypeSymbolId,
) -> Unit {
  self.types.push({ name, symbol })
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
fn Resolver::qualified_effect_symbol_opt(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
) -> EffectSymbolId? {
  let module_path = @module_interface.module_path_text(module_path)
  match self.module_binding(module_path) {
    Some(module_) => module_.interface.effect_symbol_named(name)
    None => None
  }
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
fn Resolver::publish_effect_binding(
  self : Resolver,
  name : String,
  symbol : EffectSymbolId,
) -> Unit {
  self.effects.push({ name, symbol })
}

///|
fn @module_interface.ModuleInterface::effect_symbol_named(
  self : @module_interface.ModuleInterface,
  name : String,
) -> EffectSymbolId? {
  for effect in self.effects {
    if effect.name == name {
      return Some(effect.symbol)
    }
  }
  None
}

///|
fn Resolver::operation_reference(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> ResolvedOperationReference {
  match self.registry.operation_named(owner, name) {
    Some(symbol) => Symbol(symbol)
    None => Unresolved(name)
  }
}

///|
fn Resolver::unqualified_operation_reference(
  self : Resolver,
  name : String,
) -> ResolvedOperationReference {
  let candidates = self.registry.operations_named(name)
  match candidates.length() {
    0 => Unresolved(name)
    1 => Symbol(candidates[0])
    _ => Ambiguous(name~, candidates~)
  }
}

///|
fn Resolver::operation_symbol(
  self : Resolver,
  owner : EffectSymbolId,
  name : String,
) -> OperationSymbolId {
  self.registry.operation_named(owner, name).unwrap()
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
          self.report(
            ConflictingTopLevelValue(
              name=binding.name,
              existing=self.binding_display(existing),
              incoming=self.binding_display(binding),
            ),
            loc,
          )
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
          self.report(
            ConflictingTopLevelValue(
              name=binding.name,
              existing=self.binding_display(existing),
              incoming=self.binding_display(binding),
            ),
            loc,
          )
        None => self.ordered_top_values.push(binding)
      }
  }
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
fn Resolver::variant_reference(
  self : Resolver,
  type_name : String,
  variant : String,
  loc : SourceSpan,
) -> ResolvedVariantReference {
  if self.qualified_variant_symbol(type_name, variant) is Some(symbol) {
    return Symbol(symbol)
  }
  if self.type_symbol_opt(type_name) is Some(owner) {
    if self.registry.variant_named(owner, variant) is Some(symbol) {
      Symbol(symbol)
    } else {
      resolver_report_qualified_variant(self, type_name, variant, loc)
      Unresolved(type_name~, variant~)
    }
  } else {
    resolver_report_qualified_variant(self, type_name, variant, loc)
    Unresolved(type_name~, variant~)
  }
}

///|
fn Resolver::qualified_variant_symbol(
  self : Resolver,
  type_name : String,
  variant : String,
) -> VariantSymbolId? {
  match qualified_name_text(type_name) {
    Some(qualified) =>
      match self.module_binding(qualified.module_path) {
        Some(module_) =>
          module_.interface.variant_symbol_named(qualified.name, variant)
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
  let candidates = self.registry.variants_named(name)
  match candidates.length() {
    0 => UnresolvedUnqualified(name)
    1 => Symbol(candidates[0])
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
    "Bool" => Some(Bool)
    "String" => Some(String)
    "Unit" => Some(Unit)
    _ => None
  }
}
