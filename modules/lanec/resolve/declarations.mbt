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
        self.publish_local_type_binding(
          declaration.name,
          symbols.define_type(
            declaration.name,
            Struct,
            declaration.type_parameters.length(),
            declaration.name_loc,
          ),
          syntax_type_parameter_kinds(declaration.type_parameters),
          declaration.is_public,
        )
      }
      Enum(declaration) => {
        self.report_type_effect_conflict_if_effect_exists(
          declaration.name,
          "type",
          declaration.loc,
        )
        self.publish_local_type_binding(
          declaration.name,
          symbols.define_type(
            declaration.name,
            Enum,
            declaration.type_parameters.length(),
            declaration.name_loc,
          ),
          syntax_type_parameter_kinds(declaration.type_parameters),
          declaration.is_public,
        )
      }
      Effect(declaration) => {
        self.report_effect_type_conflict_if_type_exists(
          declaration.name,
          declaration.loc,
        )
        self.publish_local_effect_binding(
          declaration.name,
          symbols.define_effect(
            declaration.name,
            declaration.type_parameters.length(),
            declaration.name_loc,
          ),
          syntax_type_parameter_kinds(declaration.type_parameters),
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
            self.publish_local_type_binding(
              declaration.name,
              symbols.define_type(
                declaration.name,
                External,
                declaration.type_parameters.length(),
                declaration.name_loc,
              ),
              syntax_type_parameter_kinds(declaration.type_parameters),
              declaration.is_public,
            )
          }
          Effect(_) => {
            self.report_effect_type_conflict_if_type_exists(
              declaration.name,
              declaration.loc,
            )
            self.publish_local_effect_binding(
              declaration.name,
              symbols.define_effect(
                declaration.name,
                declaration.type_parameters.length(),
                declaration.name_loc,
                flavor=External,
              ),
              syntax_type_parameter_kinds(declaration.type_parameters),
            )
          }
        }
      TypeAlias(declaration) => {
        self.report_type_effect_conflict_if_effect_exists(
          declaration.name,
          "type alias",
          declaration.loc,
        )
        let binding : TypeAliasBinding = {
          symbol: symbols.define_type_alias(
            declaration.name,
            declaration.name_loc,
          ),
          name: declaration.name,
          owner_module_path: None,
          is_effect: declaration.body is EffectBody(_),
          parameter_kinds: syntax_type_parameter_kinds(
            declaration.type_parameters,
          ),
          import_origin: None,
        }
        self.type_aliases.push(binding)
        self.local_module.type_aliases.push(binding)
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
      Let(declaration) => {
        let symbol = symbols.define_value(
          declaration.name,
          TopLevelValue,
          declaration.name_loc,
        )
        let type_annotation = declaration.type_annotation.map(fn(type_) {
          type_.resolve_type(self, self.scope([]))
        })
        self.publish_complete_top_level_binding(
          {
            name: declaration.name,
            reference: Symbol(symbol),
            type_: type_annotation,
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
          self.canonical_basic_abi.register_local_variant(
            self.local_module.path_text,
            declaration.name,
            variant.name,
            symbol,
          )
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
      ExternalType(_) | TypeAlias(_) | Function(_) | Let(_) => ()
    }
  }
}

///|
/// Resolves one top-level declaration after the global headers are known.
///
/// Example: `fn f() -> Int { 1 }` resolves through the function path, while
/// `offer int_ops : Add[Int] = value` resolves as an offered let binding.
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
    symbol: resolver.type_alias_binding(self.name).unwrap().symbol,
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
    is_offered: self.is_offered,
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
  let symbol = resolver.value_symbol(self.name)
  let type_annotation = match resolver.top_value_binding(self.name) {
    Some(binding) => binding.type_
    None =>
      self.type_annotation.map(fn(type_) { type_.resolve_type(resolver, scope) })
  }
  let declaration = self.resolve_let_with_resolved_type(
    resolver, scope, symbol, type_annotation,
  )
  resolver.publish_top_level_let(declaration, self.name_loc)
  declaration
}

///|
fn Resolver::publish_top_level_let(
  self : Resolver,
  declaration : ResolvedLetDeclaration,
  loc : SourceSpan,
) -> Unit {
  let binding = {
    name: declaration.name,
    reference: Symbol(declaration.symbol),
    type_: declaration.type_annotation,
    kind: Plain,
    source: CurrentSource,
    import_origin: None,
  }
  self.publish_ordered_top_level_binding(binding, loc)
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
  let symbol = resolver.registry.define_value(self.name, kind, self.name_loc)
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
  scope.define_value(self.name, symbol, type_annotation)
  {
    is_public: self.is_public,
    is_offered: self.is_offered,
    symbol,
    name: self.name,
    name_loc: self.name_loc,
    type_annotation,
    initializer,
    loc: self.loc,
  }
}
