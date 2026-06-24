///|
priv struct DeclarationChecker {
  source : @resolve.ResolvedSourceFile
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
  let checker = DeclarationChecker::{ source, diagnostics: [] }
  let types = []
  let type_members = []
  let fields = []
  let variants = []
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
        types.push(CheckedTypeDeclaration::Struct(checked))
      }
      Enum(declaration) => {
        let checked = checker.check_enum(declaration)
        for variant in checked.variants {
          variants.push(variant)
        }
        types.push(Enum(checked))
      }
      TypeAlias(declaration) => checker.check_type_alias(declaration)
      _ => ()
    }
  }
  {
    declarations: { types, type_members, fields, variants },
    diagnostics: checker.diagnostics,
  }
}

///|
fn DeclarationChecker::check_type_alias(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedTypeAliasDeclaration,
) -> Unit {
  ignore(
    TypeExpressionChecker::{
      source: self.source,
      diagnostics: self.diagnostics,
      expanding: [declaration.name],
    }.synthesize_type(declaration.body),
  )
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
    is_offered: field.is_offered,
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
  check_resolved_type(self.source, self.diagnostics, type_)
}

///|
fn DeclarationChecker::check_kind(
  _self : DeclarationChecker,
  kind : @resolve.ResolvedKind,
) -> @types.Kind {
  check_resolved_kind(kind)
}

///|
fn check_resolved_type(
  source : @resolve.ResolvedSourceFile,
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  let checker = TypeExpressionChecker::{ source, diagnostics, expanding: [] }
  checker.check_value_type(type_)
}

///|
priv struct TypeExpressionChecker {
  source : @resolve.ResolvedSourceFile
  diagnostics : Array[TypeCheckDiagnostic]
  expanding : Array[String]
}

///|
fn TypeExpressionChecker::check_value_type(
  self : TypeExpressionChecker,
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  let result = self.synthesize_type(type_)
  if result.kind != Type {
    self.diagnostics.push({
      kind: KindMismatch(expected=Type, actual=result.kind),
      loc: resolved_type_loc(type_),
    })
  }
  result.type_.normalize()
}

///|
fn TypeExpressionChecker::synthesize_type(
  self : TypeExpressionChecker,
  type_ : @resolve.ResolvedType,
) -> TypeExpressionResult {
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
              kind: TypeArgumentArityMismatch(
                name=resolved_type_name(callee),
                expected=parameter_kinds.length(),
                actual=arguments.length(),
              ),
              loc,
            })
          }
          for index in 0..<arguments.length() {
            let argument_result = self.synthesize_type(arguments[index])
            checked_arguments.push(argument_result.type_)
            if index < parameter_kinds.length() &&
              argument_result.kind != parameter_kinds[index] {
              self.diagnostics.push({
                kind: KindMismatch(
                  expected=parameter_kinds[index],
                  actual=argument_result.kind,
                ),
                loc: resolved_type_loc(arguments[index]),
              })
            }
          }
          {
            type_: @types.Type::Apply(callee_result.type_, checked_arguments).normalize(),
            kind: result_kind,
          }
        }
        _ => {
          for argument in arguments {
            checked_arguments.push(self.synthesize_type(argument).type_)
          }
          self.diagnostics.push({
            kind: KindMismatch(
              expected=Function([], Type),
              actual=callee_result.kind,
            ),
            loc,
          })
          { type_: Apply(callee_result.type_, checked_arguments), kind: Type }
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
    Function(type_parameters~, parameters~, result~, ..) => {
      let checked_type_parameters = check_type_parameters(
        self.diagnostics,
        type_parameters,
      )
      let checked_parameters = parameters.map(fn(parameter) {
        self.expect_kind(parameter, Type).type_
      })
      let checked_result = self.expect_kind(result, Type).type_
      let function_type = @types.Type::Function(
        checked_parameters, checked_result,
      )
      if checked_type_parameters.is_empty() {
        { type_: function_type, kind: Type }
      } else {
        { type_: Forall(checked_type_parameters, function_type), kind: Type }
      }
    }
    Unresolved(name~, arguments~, loc~) => {
      for argument in arguments {
        ignore(self.synthesize_type(argument))
      }
      self.diagnostics.push({ kind: UnresolvedType(name), loc })
      { type_: Error, kind: Type }
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
        diagnostics: self.diagnostics,
        expanding: self.expanding.copy(),
      }
      next.expanding.push(name)
      next.synthesize_type(type_alias.body)
    }
    None => {
      self.diagnostics.push({ kind: UnresolvedType(name), loc })
      { type_: Error, kind: Type }
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
      _ => ()
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
        if find_kind_in_type(type_alias.body, symbol) is Some(kind) {
          return Some(kind)
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
        if find_kind_in_type(argument, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      None
    }
    Function(type_parameters~, parameters~, result~, ..) => {
      for parameter in parameters {
        if find_kind_in_type(parameter, symbol) is Some(kind) {
          return Some(kind)
        }
      }
      match find_kind_in_parameters(type_parameters, symbol) {
        Some(kind) => return Some(kind)
        None => ()
      }
      find_kind_in_type(result, symbol)
    }
    _ => None
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
    Function(parameters~, result~, ..) =>
      Function(parameters.map(check_resolved_kind), check_resolved_kind(result))
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
      kind: TypeArgumentArityMismatch(name~, expected=metadata.arity, actual~),
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
