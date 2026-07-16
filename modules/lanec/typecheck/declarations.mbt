///|
priv struct DeclarationChecker {
  source : @resolve.ResolvedSourceFile
  imported_environment : @module_interface.ImportedEnvironment
  diagnostics : Array[TypeCheckDiagnostic]
}

///|
priv struct TypeExpressionResult {
  type_ : @types.Type
  kind : @types.Kind
}

///|
/// Checks nominal declarations and returns the checked declaration environment.
pub fn typecheck_declarations(
  source : @resolve.ResolvedSourceFile,
) -> DeclarationTypeCheckResult {
  typecheck_declarations_with_imported_environment(
    source,
    empty_imported_environment(),
  )
}

///|
fn typecheck_declarations_with_imported_environment(
  source : @resolve.ResolvedSourceFile,
  imported_environment : @module_interface.ImportedEnvironment,
) -> DeclarationTypeCheckResult {
  // Declaration checking builds Delta from imported module interfaces and local
  // nominal/effect declarations before expression bodies are checked.
  let checker = DeclarationChecker::{
    source,
    imported_environment,
    diagnostics: [],
  }
  let types = []
  let type_members = []
  let fields = []
  let variants = []
  let effects = []
  let operations = []
  for module_ in imported_environment.modules {
    append_interface_declarations(
      types, type_members, fields, variants, effects, operations, module_,
    )
  }
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => {
        let checked = checker.check_struct(declaration)
        for type_member in checked.type_members {
          type_members.push(type_member)
        }
        for field in checked.fields {
          fields.push(field)
        }
        types.push(Struct(checked))
      }
      Enum(declaration) => {
        let checked = checker.check_enum(declaration)
        for variant in checked.variants {
          variants.push(variant)
        }
        types.push(Enum(checked))
      }
      Effect(declaration) => {
        let checked = checker.check_effect(declaration)
        for operation in checked.operations {
          operations.push(operation)
        }
        effects.push(checked)
      }
      ExternalType(declaration) => {
        let checked = checker.check_external_type(declaration)
        types.push(External(checked))
      }
      TypeAlias(declaration) => checker.check_type_alias(declaration)
      _ => ()
    }
  }
  {
    declarations: { types, type_members, fields, variants, effects, operations },
    diagnostics: checker.diagnostics,
  }
}

///|
fn append_interface_declarations(
  types : Array[CheckedTypeDeclaration],
  type_members : Array[CheckedTypeMemberDeclaration],
  fields : Array[CheckedFieldDeclaration],
  variants : Array[CheckedVariantDeclaration],
  effects : Array[CheckedEffectDeclaration],
  operations : Array[CheckedEffectOperationDeclaration],
  interface : @module_interface.ModuleInterface,
) -> Unit {
  for type_ in interface.types {
    match type_ {
      Struct(declaration) => {
        let checked = interface_struct_declaration(declaration)
        for type_member in checked.type_members {
          type_members.push(type_member)
        }
        for field in checked.fields {
          fields.push(field)
        }
        types.push(Struct(checked))
      }
      Enum(declaration) => {
        let checked = interface_enum_declaration(declaration)
        for variant in checked.variants {
          variants.push(variant)
        }
        types.push(Enum(checked))
      }
    }
  }
  for effect in interface.effects {
    let checked = interface_effect_declaration(effect)
    for operation in checked.operations {
      operations.push(operation)
    }
    effects.push(checked)
  }
}

///|
fn interface_struct_declaration(
  declaration : @module_interface.ModuleInterfaceStruct,
) -> CheckedStructDeclaration {
  {
    is_public: true,
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    type_members: declaration.type_members.map(fn(type_member) {
      {
        symbol: type_member.symbol,
        type_parameter: type_member.type_parameter,
        name: type_member.name,
        kind: type_member.kind,
        index: type_member.index,
        loc: type_member.loc,
      }
    }),
    fields: declaration.fields.map(fn(field) {
      {
        symbol: field.symbol,
        name: field.name,
        index: field.index,
        type_: field.type_,
        loc: field.loc,
      }
    }),
    loc: declaration.loc,
  }
}

///|
fn interface_enum_declaration(
  declaration : @module_interface.ModuleInterfaceEnum,
) -> CheckedEnumDeclaration {
  {
    is_public: true,
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    variants: declaration.variants.map(fn(variant) {
      {
        symbol: variant.symbol,
        name: variant.name,
        index: variant.index,
        type_parameters: variant.type_parameters,
        payload: variant.payload,
        loc: variant.loc,
      }
    }),
    loc: declaration.loc,
  }
}

///|
fn interface_effect_declaration(
  declaration : @module_interface.ModuleInterfaceEffect,
) -> CheckedEffectDeclaration {
  {
    is_public: true,
    symbol: declaration.symbol,
    name: declaration.name,
    flavor: @symbol.EffectFlavor::Algebraic,
    type_parameters: declaration.type_parameters,
    operations: declaration.operations.map(fn(operation) {
      {
        symbol: operation.symbol,
        name: operation.name,
        index: operation.index,
        type_parameters: operation.type_parameters,
        payload: operation.payload,
        result: operation.result,
        loc: operation.loc,
      }
    }),
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_type_alias(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedTypeAliasDeclaration,
) -> Unit {
  let actual_kind = match declaration.body {
    TypeBody(body) =>
      TypeExpressionChecker::{
        source: self.source,
        imported_environment: self.imported_environment,
        diagnostics: self.diagnostics,
        expanding: [declaration.name],
      }.synthesize_type(body).kind
    EffectBody(effect) => {
      ignore(
        TypeExpressionChecker::{
          source: self.source,
          imported_environment: self.imported_environment,
          diagnostics: self.diagnostics,
          expanding: [declaration.name],
        }.check_effect(effect),
      )
      type_alias_kind(declaration.type_parameters, Effect)
    }
  }
  if declaration.result_kind is Some(result_kind) {
    let expected_kind = type_alias_kind(
      declaration.type_parameters,
      check_resolved_kind(result_kind),
    )
    if expected_kind != actual_kind {
      self.diagnostics.push({
        kind: KindMismatch(expected=expected_kind, actual=actual_kind),
        loc: resolved_kind_loc(result_kind),
      })
    }
  }
}

///|
fn type_alias_kind(
  parameters : Array[@resolve.ResolvedTypeParameter],
  result : @types.Kind,
) -> @types.Kind {
  if parameters.is_empty() {
    result
  } else {
    Function(parameters.map(resolve_type_parameter_kind), result)
  }
}

///|
fn resolved_kind_loc(kind : @resolve.ResolvedKind) -> SourceSpan {
  match kind {
    Type(loc~) | Effect(loc~) | Function(loc~, ..) => loc
  }
}

///|
fn DeclarationChecker::check_effect(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedEffectDeclaration,
) -> CheckedEffectDeclaration {
  let type_parameters = self.check_type_parameters(declaration.type_parameters)
  let operations = declaration.operations.map(fn(operation) {
    self.check_operation(operation)
  })
  {
    is_public: declaration.is_public,
    symbol: declaration.symbol,
    name: declaration.name,
    flavor: declaration.flavor,
    type_parameters,
    operations,
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_external_type(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedExternalTypeDeclaration,
) -> CheckedExternalTypeDeclaration {
  if !declaration.type_parameters.is_empty() {
    self.diagnostics.push({
      kind: ExternalTypeParametersNotSupported(name=declaration.name),
      loc: declaration.loc,
    })
  }
  {
    is_public: declaration.is_public,
    symbol: declaration.symbol,
    name: declaration.name,
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_operation(
  self : DeclarationChecker,
  operation : @resolve.ResolvedEffectOperationDeclaration,
) -> CheckedEffectOperationDeclaration {
  let type_parameters = self.check_type_parameters(operation.type_parameters)
  {
    symbol: operation.symbol,
    name: operation.name,
    index: operation.index,
    type_parameters,
    payload: operation.payload.map(fn(type_) { self.check_type(type_) }),
    result: self.check_type(operation.result),
    loc: operation.loc,
  }
}

///|
fn DeclarationChecker::check_struct(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedStructDeclaration,
) -> CheckedStructDeclaration {
  let type_parameters = self.check_type_parameters(declaration.type_parameters)
  let type_members = []
  let fields = []
  for item in declaration.members {
    match item {
      TypeMember(type_member) =>
        type_members.push(self.check_type_member(type_member))
      Field(field) => fields.push(self.check_field(field))
    }
  }
  {
    is_public: declaration.is_public,
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters,
    type_members,
    fields,
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_type_member(
  self : DeclarationChecker,
  type_member : @resolve.ResolvedTypeMemberDeclaration,
) -> CheckedTypeMemberDeclaration {
  let kind = self.check_kind(type_member.kind)
  {
    symbol: type_member.symbol,
    type_parameter: checked_type_parameter_with_kind(
      type_member.type_parameter,
      kind,
    ),
    name: type_member.name,
    kind,
    index: type_member.index,
    loc: type_member.loc,
  }
}

///|
fn DeclarationChecker::check_field(
  self : DeclarationChecker,
  field : @resolve.ResolvedFieldDeclaration,
) -> CheckedFieldDeclaration {
  {
    symbol: field.symbol,
    name: field.name,
    index: field.index,
    type_: self.check_type(field.type_),
    loc: field.loc,
  }
}

///|
fn DeclarationChecker::check_enum(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedEnumDeclaration,
) -> CheckedEnumDeclaration {
  let type_parameters = self.check_type_parameters(declaration.type_parameters)
  let variants = []
  for variant in declaration.variants {
    variants.push(self.check_variant(variant))
  }
  {
    is_public: declaration.is_public,
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters,
    variants,
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_variant(
  self : DeclarationChecker,
  variant : @resolve.ResolvedEnumVariant,
) -> CheckedVariantDeclaration {
  {
    symbol: variant.symbol,
    name: variant.name,
    index: variant.index,
    type_parameters: self.check_type_parameters(variant.type_parameters),
    payload: variant.payload.map(fn(type_) { self.check_type(type_) }),
    loc: variant.loc,
  }
}

///|
fn DeclarationChecker::check_type_parameters(
  self : DeclarationChecker,
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Array[@types.TypeParameter] {
  check_type_parameters(self.diagnostics, parameters)
}

///|
fn DeclarationChecker::check_type(
  self : DeclarationChecker,
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  check_resolved_type_with_imported_environment(
    self.source,
    self.imported_environment,
    self.diagnostics,
    type_,
  )
}

///|
fn DeclarationChecker::check_kind(
  _self : DeclarationChecker,
  kind : @resolve.ResolvedKind,
) -> @types.Kind {
  check_resolved_kind(kind)
}

///|
fn check_resolved_type_with_imported_environment(
  source : @resolve.ResolvedSourceFile,
  imported_environment : @module_interface.ImportedEnvironment,
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  let checker = TypeExpressionChecker::{
    source,
    imported_environment,
    diagnostics,
    expanding: [],
  }
  checker.check_value_type(type_)
}

///|
fn check_resolved_nominal_generic_arguments(
  source : @resolve.ResolvedSourceFile,
  diagnostics : Array[TypeCheckDiagnostic],
  parameters : Array[@types.TypeParameter],
  arguments : Array[@resolve.ResolvedGenericArgument],
) -> Array[@types.GenericArgument] {
  let checked = []
  for index in 0..<arguments.length() {
    let argument = if index < parameters.length() {
      check_resolved_generic_argument(
        source,
        diagnostics,
        { values: [], offers: [], type_parameters: [], expected_effect: None },
        parameters[index].kind,
        arguments[index],
      )
    } else {
      check_resolved_generic_argument(
        source,
        diagnostics,
        { values: [], offers: [], type_parameters: [], expected_effect: None },
        Type,
        arguments[index],
      )
    }
    checked.push(argument)
  }
  checked
}

///|
fn check_resolved_generic_arguments(
  source : @resolve.ResolvedSourceFile,
  diagnostics : Array[TypeCheckDiagnostic],
  scope : TypeScope,
  parameters : Array[@types.TypeParameter],
  arguments : Array[@resolve.ResolvedGenericArgument],
) -> Array[@types.GenericArgument] {
  let checked = []
  for index in 0..<arguments.length() {
    if index < parameters.length() {
      checked.push(
        check_resolved_generic_argument(
          source,
          diagnostics,
          scope,
          parameters[index].kind,
          arguments[index],
        ),
      )
    } else {
      checked.push(
        check_resolved_generic_argument(
          source,
          diagnostics,
          scope,
          Type,
          arguments[index],
        ),
      )
    }
  }
  checked
}

///|
fn check_resolved_generic_argument(
  source : @resolve.ResolvedSourceFile,
  diagnostics : Array[TypeCheckDiagnostic],
  scope : TypeScope,
  expected : @types.Kind,
  argument : @resolve.ResolvedGenericArgument,
) -> @types.GenericArgument {
  let checker = TypeExpressionChecker::{
    source,
    imported_environment: empty_imported_environment(),
    diagnostics,
    expanding: [],
  }
  match (expected, argument) {
    (Effect, EffectArgument(effect)) =>
      EffectArgument(
        normalize_effect_or_empty(
          checker.diagnostics,
          checker.check_effect(effect),
          resolved_generic_argument_loc(argument),
          context="generic effect argument",
        ),
      )
    (Effect, TypeArgument(type_)) => {
      let result = checker.synthesize_type(type_)
      let actual = resolved_type_kind_with_scope(scope, type_, result.kind)
      if actual == Effect && result.type_ is Parameter(symbol) {
        EffectArgument(Parameter(symbol))
      } else {
        diagnostics.push({
          kind: KindMismatch(expected=Effect, actual~),
          loc: resolved_type_loc(type_),
        })
        EffectArgument(Empty)
      }
    }
    (expected, TypeArgument(type_)) => {
      let result = checker.synthesize_type(type_)
      let actual = resolved_type_kind_with_scope(scope, type_, result.kind)
      if actual != expected {
        diagnostics.push({
          kind: KindMismatch(expected~, actual~),
          loc: resolved_type_loc(type_),
        })
      }
      TypeArgument(
        normalize_type_or_error(
          checker.diagnostics,
          result.type_,
          resolved_type_loc(type_),
          context="generic type argument",
        ),
      )
    }
    (expected, EffectArgument(effect)) => {
      ignore(checker.check_effect(effect))
      diagnostics.push({
        kind: KindMismatch(expected~, actual=Effect),
        loc: resolved_generic_argument_loc(argument),
      })
      TypeArgument(Error)
    }
  }
}

///|
fn resolved_type_kind_with_scope(
  scope : TypeScope,
  type_ : @resolve.ResolvedType,
  fallback : @types.Kind,
) -> @types.Kind {
  match type_ {
    Parameter(symbol~, ..) =>
      match scope.type_parameter_kind(symbol) {
        Some(kind) => kind
        None => fallback
      }
    _ => fallback
  }
}

///|
priv struct TypeExpressionChecker {
  source : @resolve.ResolvedSourceFile
  imported_environment : @module_interface.ImportedEnvironment
  diagnostics : Array[TypeCheckDiagnostic]
  expanding : Array[String]
}

///|
priv struct QualifiedAliasName {
  module_path : String
  name : String
}

///|
fn TypeExpressionChecker::check_value_type(
  self : TypeExpressionChecker,
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  // Value-level type rule:
  //
  //   Gamma_type |- T : K
  //   K = Type
  //   ------------------
  //   Gamma_type |- T value-type
  let result = self.synthesize_type(type_)
  if result.kind != Type {
    self.diagnostics.push({
      kind: KindMismatch(expected=Type, actual=result.kind),
      loc: resolved_type_loc(type_),
    })
  }
  normalize_type_or_error(
    self.diagnostics,
    result.type_,
    resolved_type_loc(type_),
    context="value type annotation",
  )
}

///|
fn TypeExpressionChecker::synthesize_type(
  self : TypeExpressionChecker,
  type_ : @resolve.ResolvedType,
) -> TypeExpressionResult {
  // Type expression synthesis computes both the core type expression and its
  // kind. Type application is general: the callee may be any type-level
  // expression whose kind is [K_i...] -> K.
  match type_ {
    Primitive(primitive, ..) => { type_: Primitive(primitive), kind: Type }
    Constructor(symbol~, ..) => {
      let kind = self.type_constructor_kind(symbol)
      if kind is Function(parameter_kinds, _) && parameter_kinds.is_empty() {
        { type_: Constructor(symbol), kind: Type }
      } else {
        { type_: Constructor(symbol), kind }
      }
    }
    Alias(name~, loc~) => self.expand_alias(name, loc)
    Apply(callee~, arguments~, loc~) => {
      let callee_result = self.synthesize_type(callee)
      let checked_arguments = []
      match callee_result.kind {
        Function(parameter_kinds, result_kind) => {
          if parameter_kinds.length() != arguments.length() {
            self.diagnostics.push({
              kind: GenericArgumentArityMismatch(
                subject=Named(name=resolved_type_name(callee)),
                expected=parameter_kinds.length(),
                actual=arguments.length(),
              ),
              loc,
            })
          }
          for index in 0..<arguments.length() {
            if index < parameter_kinds.length() {
              checked_arguments.push(
                self.check_generic_argument(
                  parameter_kinds[index],
                  arguments[index],
                ),
              )
            } else {
              checked_arguments.push(
                self.check_generic_argument(Type, arguments[index]),
              )
            }
          }
          {
            type_: normalize_type_or_error(
              self.diagnostics,
              Apply(callee_result.type_, checked_arguments),
              loc,
              context="type application",
            ),
            kind: result_kind,
          }
        }
        _ => {
          for argument in arguments {
            checked_arguments.push(self.check_generic_argument(Type, argument))
          }
          self.diagnostics.push({
            kind: KindMismatch(
              expected=Function([], Type),
              actual=callee_result.kind,
            ),
            loc,
          })
          { type_: Error, kind: Type }
        }
      }
    }
    TypeLambda(parameters~, body~, ..) => {
      let checked_parameters = check_type_parameters(
        self.diagnostics,
        parameters,
      )
      let body_result = self.synthesize_type(body)
      {
        type_: TypeLambda(checked_parameters, body_result.type_),
        kind: Function(
          checked_parameters.map(fn(parameter) { parameter.kind }),
          body_result.kind,
        ),
      }
    }
    Parameter(symbol~, ..) => {
      let kind = match self.find_type_parameter_kind(symbol) {
        Some(kind) => kind
        None => Type
      }
      { type_: Parameter(symbol), kind }
    }
    Function(type_parameters~, parameters~, result~, effect~, ..) => {
      let checked_type_parameters = check_type_parameters(
        self.diagnostics,
        type_parameters,
      )
      let checked_parameters = parameters.map(fn(parameter) {
        self.expect_kind(parameter, Type).type_
      })
      let checked_result = self.expect_kind(result, Type).type_
      let checked_effect = self.check_effect(effect)
      let function_type = @types.Type::Function(
        checked_parameters, checked_result, checked_effect,
      )
      if checked_type_parameters.is_empty() {
        { type_: function_type, kind: Type }
      } else {
        { type_: Forall(checked_type_parameters, function_type), kind: Type }
      }
    }
    Unresolved(name~, arguments~, loc~) => {
      for argument in arguments {
        ignore(self.check_generic_argument(Type, argument))
      }
      self.diagnostics.push({ kind: UnresolvedType(name), loc })
      { type_: Error, kind: Type }
    }
  }
}

///|
fn TypeExpressionChecker::check_generic_argument(
  self : TypeExpressionChecker,
  expected : @types.Kind,
  argument : @resolve.ResolvedGenericArgument,
) -> @types.GenericArgument {
  // Generic arguments are checked by the expected kind and keep their argument
  // category. Effect-kind arguments must remain EffectArgument values; they are
  // not encoded as ordinary TypeArgument nodes.
  match (expected, argument) {
    (Effect, EffectArgument(effect)) =>
      EffectArgument(
        normalize_effect_or_empty(
          self.diagnostics,
          self.check_effect(effect),
          resolved_generic_argument_loc(argument),
          context="generic effect argument",
        ),
      )
    (Effect, TypeArgument(type_)) => {
      let result = self.synthesize_type(type_)
      if result.kind == Effect && result.type_ is Parameter(symbol) {
        EffectArgument(Parameter(symbol))
      } else {
        self.diagnostics.push({
          kind: KindMismatch(expected=Effect, actual=result.kind),
          loc: resolved_type_loc(type_),
        })
        EffectArgument(Empty)
      }
    }
    (expected, TypeArgument(type_)) => {
      let result = self.synthesize_type(type_)
      if result.kind != expected {
        self.diagnostics.push({
          kind: KindMismatch(expected~, actual=result.kind),
          loc: resolved_type_loc(type_),
        })
      }
      TypeArgument(
        normalize_type_or_error(
          self.diagnostics,
          result.type_,
          resolved_type_loc(type_),
          context="generic type argument",
        ),
      )
    }
    (expected, EffectArgument(effect)) => {
      ignore(self.check_effect(effect))
      self.diagnostics.push({
        kind: KindMismatch(expected~, actual=Effect),
        loc: resolved_generic_argument_loc(argument),
      })
      TypeArgument(Error)
    }
  }
}

///|
fn TypeExpressionChecker::expect_kind(
  self : TypeExpressionChecker,
  type_ : @resolve.ResolvedType,
  expected : @types.Kind,
) -> TypeExpressionResult {
  let result = self.synthesize_type(type_)
  if result.kind != expected {
    self.diagnostics.push({
      kind: KindMismatch(expected~, actual=result.kind),
      loc: resolved_type_loc(type_),
    })
  }
  result
}

///|
fn TypeExpressionChecker::expand_alias(
  self : TypeExpressionChecker,
  name : String,
  loc : SourceSpan,
) -> TypeExpressionResult {
  if self.expanding.contains(name) {
    self.diagnostics.push({ kind: TypeAliasCycle(name~), loc })
    return { type_: Error, kind: Type }
  }
  match self.find_alias(name) {
    Some(type_alias) => {
      let next = {
        source: self.source,
        imported_environment: self.imported_environment,
        diagnostics: self.diagnostics,
        expanding: self.expanding.copy(),
      }
      next.expanding.push(name)
      match type_alias.body {
        TypeBody(body) => next.synthesize_type(body)
        EffectBody(_) => {
          self.diagnostics.push({
            kind: KindMismatch(expected=Type, actual=Effect),
            loc,
          })
          { type_: Error, kind: Type }
        }
      }
    }
    None =>
      match self.find_interface_alias(name) {
        Some(type_alias) =>
          match type_alias.body {
            TypeBody(body) => { type_: body, kind: type_alias.kind }
            EffectBody(_) => {
              self.diagnostics.push({
                kind: KindMismatch(expected=Type, actual=type_alias.kind),
                loc,
              })
              { type_: Error, kind: Type }
            }
          }
        None => {
          self.diagnostics.push({ kind: UnresolvedType(name), loc })
          { type_: Error, kind: Type }
        }
      }
  }
}

///|
fn TypeExpressionChecker::find_alias(
  self : TypeExpressionChecker,
  name : String,
) -> @resolve.ResolvedTypeAliasDeclaration? {
  for declaration in self.source.declarations {
    match declaration {
      TypeAlias(type_alias) if type_alias.name == name =>
        return Some(type_alias)
      _ => ()
    }
  }
  None
}

///|
fn TypeExpressionChecker::find_interface_alias(
  self : TypeExpressionChecker,
  name : String,
) -> @module_interface.ModuleInterfaceTypeAlias? {
  match qualified_alias_name(name) {
    Some(qualified) =>
      match self.imported_environment.find(qualified.module_path) {
        Some(module_) => {
          for type_alias in module_.type_aliases {
            if type_alias.name == qualified.name {
              return Some(type_alias)
            }
          }
          return None
        }
        None => return None
      }
    None => ()
  }
  for module_ in self.imported_environment.modules {
    for type_alias in module_.type_aliases {
      if type_alias.name == name {
        return Some(type_alias)
      }
    }
  }
  None
}

///|
fn qualified_alias_name(name : String) -> QualifiedAliasName? {
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
fn TypeExpressionChecker::type_constructor_kind(
  self : TypeExpressionChecker,
  symbol : TypeSymbolId,
) -> @types.Kind {
  for declaration in self.source.declarations {
    match declaration {
      Struct(declaration) if declaration.symbol == symbol =>
        return nominal_kind(declaration.type_parameters)
      Enum(declaration) if declaration.symbol == symbol =>
        return nominal_kind(declaration.type_parameters)
      ExternalType(declaration) if declaration.symbol == symbol =>
        return nominal_kind(declaration.type_parameters)
      _ => ()
    }
  }
  for module_ in self.imported_environment.modules {
    for type_ in module_.types {
      match type_ {
        Struct(declaration) if declaration.symbol == symbol =>
          return interface_nominal_kind(declaration.type_parameters)
        Enum(declaration) if declaration.symbol == symbol =>
          return interface_nominal_kind(declaration.type_parameters)
        _ => ()
      }
    }
  }
  Type
}

///|
fn TypeExpressionChecker::find_type_parameter_kind(
  self : TypeExpressionChecker,
  symbol : TypeParameterId,
) -> @types.Kind? {
  for declaration in self.source.declarations {
    match declaration {
      Struct(declaration) => {
        if find_kind_in_parameters(declaration.type_parameters, symbol)
          is Some(kind) {
          return Some(kind)
        }
        for item in declaration.members {
          match item {
            TypeMember(type_member) =>
              if type_member.type_parameter.symbol == symbol {
                return Some(check_resolved_kind(type_member.kind))
              }
            Field(field) =>
              if find_kind_in_type(field.type_, symbol) is Some(kind) {
                return Some(kind)
              }
          }
        }
      }
      Enum(declaration) => {
        if find_kind_in_parameters(declaration.type_parameters, symbol)
          is Some(kind) {
          return Some(kind)
        }
        for variant in declaration.variants {
          if find_kind_in_parameters(variant.type_parameters, symbol)
            is Some(kind) {
            return Some(kind)
          }
          for payload in variant.payload {
            if find_kind_in_type(payload, symbol) is Some(kind) {
              return Some(kind)
            }
          }
        }
      }
      Function(declaration) =>
        if find_kind_in_parameters(declaration.type_parameters, symbol)
          is Some(kind) {
          return Some(kind)
        }
      TypeAlias(type_alias) =>
        match type_alias.body {
          TypeBody(body) =>
            if find_kind_in_type(body, symbol) is Some(kind) {
              return Some(kind)
            }
          EffectBody(effect) =>
            if find_kind_in_effect(effect, symbol) is Some(kind) {
              return Some(kind)
            }
        }
      ExternalType(declaration) =>
        if find_kind_in_parameters(declaration.type_parameters, symbol)
          is Some(kind) {
          return Some(kind)
        }
      Effect(declaration) => {
        if find_kind_in_parameters(declaration.type_parameters, symbol)
          is Some(kind) {
          return Some(kind)
        }
        for operation in declaration.operations {
          if find_kind_in_parameters(operation.type_parameters, symbol)
            is Some(kind) {
            return Some(kind)
          }
          for payload in operation.payload {
            if find_kind_in_type(payload, symbol) is Some(kind) {
              return Some(kind)
            }
          }
          if find_kind_in_type(operation.result, symbol) is Some(kind) {
            return Some(kind)
          }
        }
      }
      Let(_) | Offer(_) => ()
    }
  }
  None
}

///|
fn find_kind_in_parameters(
  parameters : Array[@resolve.ResolvedTypeParameter],
  symbol : TypeParameterId,
) -> @types.Kind? {
  for parameter in parameters {
    if parameter.symbol == symbol {
      return Some(resolve_type_parameter_kind(parameter))
    }
  }
  None
}

///|
fn find_kind_in_type(
  type_ : @resolve.ResolvedType,
  symbol : TypeParameterId,
) -> @types.Kind? {
  match type_ {
    TypeLambda(parameters~, body~, ..) =>
      match find_kind_in_parameters(parameters, symbol) {
        Some(kind) => Some(kind)
        None => find_kind_in_type(body, symbol)
      }
    Apply(callee~, arguments~, ..) => {
      match find_kind_in_type(callee, symbol) {
        Some(kind) => return Some(kind)
        None => ()
      }
      for argument in arguments {
        if find_kind_in_generic_argument(argument, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
    Function(type_parameters~, parameters~, result~, effect~, ..) => {
      for parameter in parameters {
        if find_kind_in_type(parameter, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      match find_kind_in_parameters(type_parameters, symbol) {
        Some(kind) => return Some(kind)
        None => ()
      }
      match find_kind_in_type(result, symbol) {
        Some(kind) => Some(kind)
        None => find_kind_in_effect(effect, symbol)
      }
    }
    _ => None
  }
}

///|
fn find_kind_in_effect(
  effect : @resolve.ResolvedEffectTerm,
  symbol : TypeParameterId,
) -> @types.Kind? {
  match effect {
    Empty(..) => None
    Io(arguments~, ..) => {
      for argument in arguments {
        if find_kind_in_generic_argument(argument, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
    Singleton(arguments~, ..) => {
      for argument in arguments {
        if find_kind_in_generic_argument(argument, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
    Parameter(symbol=effect_symbol, ..) =>
      if effect_symbol == symbol {
        Some(Effect)
      } else {
        None
      }
    Alias(arguments~, ..) => {
      for argument in arguments {
        if find_kind_in_effect_alias_argument(argument, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
    Union(items~, ..) => {
      for item in items {
        if find_kind_in_effect(item, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
    Unresolved(arguments~, ..) => {
      for argument in arguments {
        if find_kind_in_generic_argument(argument, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
  }
}

///|
fn find_kind_in_generic_argument(
  argument : @resolve.ResolvedGenericArgument,
  symbol : TypeParameterId,
) -> @types.Kind? {
  match argument {
    TypeArgument(type_) => find_kind_in_type(type_, symbol)
    EffectArgument(effect) => find_kind_in_effect(effect, symbol)
  }
}

///|
fn check_type_parameters(
  diagnostics : Array[TypeCheckDiagnostic],
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Array[@types.TypeParameter] {
  for index in 0..<parameters.length() {
    for previous in 0..<index {
      if parameters[index].name == parameters[previous].name {
        diagnostics.push({
          kind: DuplicateTypeParameter(name=parameters[index].name),
          loc: parameters[index].loc,
        })
      }
    }
  }
  parameters.map(checked_type_parameter)
}

///|
fn nominal_kind(
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> @types.Kind {
  if parameters.is_empty() {
    Type
  } else {
    Function(parameters.map(resolve_type_parameter_kind), Type)
  }
}

///|
fn interface_nominal_kind(
  parameters : Array[@types.TypeParameter],
) -> @types.Kind {
  if parameters.is_empty() {
    Type
  } else {
    Function(parameters.map(fn(parameter) { parameter.kind }), Type)
  }
}

///|
fn checked_type_parameter(
  parameter : @resolve.ResolvedTypeParameter,
) -> @types.TypeParameter {
  checked_type_parameter_with_kind(
    parameter,
    resolve_type_parameter_kind(parameter),
  )
}

///|
fn resolve_type_parameter_kind(
  parameter : @resolve.ResolvedTypeParameter,
) -> @types.Kind {
  match parameter.kind {
    Some(kind) => check_resolved_kind(kind)
    None => Type
  }
}

///|
fn check_resolved_kind(kind : @resolve.ResolvedKind) -> @types.Kind {
  match kind {
    Type(..) => Type
    Effect(..) => Effect
    Function(parameters~, result~, ..) =>
      Function(parameters.map(check_resolved_kind), check_resolved_kind(result))
  }
}

///|
fn find_kind_in_effect_alias_argument(
  argument : @resolve.ResolvedEffectAliasArgument,
  symbol : TypeParameterId,
) -> @types.Kind? {
  match argument {
    TypeArgument(type_) => find_kind_in_type(type_, symbol)
    EffectArgument(effect) => find_kind_in_effect(effect, symbol)
  }
}

///|
fn resolved_type_loc(type_ : @resolve.ResolvedType) -> SourceSpan {
  match type_ {
    Primitive(_, loc~) => loc
    Constructor(loc~, ..) => loc
    Alias(loc~, ..) => loc
    Apply(loc~, ..) => loc
    TypeLambda(loc~, ..) => loc
    Parameter(loc~, ..) => loc
    Function(loc~, ..) => loc
    Unresolved(loc~, ..) => loc
  }
}

///|
fn resolved_generic_argument_loc(
  argument : @resolve.ResolvedGenericArgument,
) -> SourceSpan {
  match argument {
    TypeArgument(type_) => resolved_type_loc(type_)
    EffectArgument(effect) => resolved_effect_loc(effect)
  }
}

///|
fn resolved_type_name(type_ : @resolve.ResolvedType) -> String {
  match type_ {
    Primitive(primitive, ..) => @prettyprinter.render(primitive, width=80)
    Constructor(name~, ..) | Alias(name~, ..) | Unresolved(name~, ..) => name
    Parameter(name~, ..) => name
    Apply(callee~, ..) => resolved_type_name(callee)
    TypeLambda(..) => "<type-lambda>"
    Function(..) => "<function-type>"
  }
}

///|
fn check_type_arity(
  symbols : @symbol.SymbolRegistry,
  diagnostics : Array[TypeCheckDiagnostic],
  symbol : TypeSymbolId,
  name : String,
  actual : Int,
  loc : SourceSpan,
) -> Unit {
  if symbols.type_metadata(symbol) is Some(metadata) && metadata.arity != actual {
    diagnostics.push({
      kind: GenericArgumentArityMismatch(
        subject=Named(name~),
        expected=metadata.arity,
        actual~,
      ),
      loc,
    })
  }
}

///|
fn checked_type_parameter_with_kind(
  parameter : @resolve.ResolvedTypeParameter,
  kind : @types.Kind,
) -> @types.TypeParameter {
  { id: parameter.symbol, name: parameter.name, kind }
}
