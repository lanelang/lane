///|
fn SemanticChecker::module_interface(
  self : SemanticChecker,
  checked_source : @checked.CheckedSourceFile,
) -> @module_interface.ModuleInterface {
  self.check_public_interface_resolved_declarations()
  {
    module_path: @module_interface.module_path_text(checked_source.module_path),
    types: checked_source.declarations.filter_map(fn(declaration) {
      self.interface_type(declaration)
    }),
    type_aliases: self.interface_type_aliases(),
    values: checked_source.declarations.filter_map(fn(declaration) {
      self.interface_value(declaration)
    }),
    optimization_hints: [],
  }
}

///|
fn SemanticChecker::interface_type(
  self : SemanticChecker,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceType? {
  match declaration {
    Struct(declaration) if declaration.is_public => {
      for field in declaration.fields {
        self.check_public_interface_type_fallback(field.type_, field.loc)
      }
      Some(Struct(interface_struct(declaration)))
    }
    Enum(declaration) if declaration.is_public => {
      for variant in declaration.variants {
        for payload in variant.payload {
          self.check_public_interface_type_fallback(payload, variant.loc)
        }
      }
      Some(Enum(interface_enum(declaration)))
    }
    _ => None
  }
}

///|
fn interface_struct(
  declaration : @checked.CheckedStructDeclaration,
) -> @module_interface.ModuleInterfaceStruct {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    type_members: declaration.type_members.map(interface_type_member),
    fields: declaration.fields.map(interface_field),
    loc: declaration.loc,
  }
}

///|
fn interface_type_member(
  declaration : @checked.CheckedTypeMemberDeclaration,
) -> @module_interface.ModuleInterfaceTypeMember {
  {
    symbol: declaration.symbol,
    type_parameter: declaration.type_parameter,
    name: declaration.name,
    kind: declaration.kind,
    index: declaration.index,
    loc: declaration.loc,
  }
}

///|
fn interface_field(
  declaration : @checked.CheckedFieldDeclaration,
) -> @module_interface.ModuleInterfaceField {
  {
    symbol: declaration.symbol,
    is_offered: declaration.is_offered,
    name: declaration.name,
    index: declaration.index,
    type_: declaration.type_,
    loc: declaration.loc,
  }
}

///|
fn interface_enum(
  declaration : @checked.CheckedEnumDeclaration,
) -> @module_interface.ModuleInterfaceEnum {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    variants: declaration.variants.map(interface_variant),
    loc: declaration.loc,
  }
}

///|
fn interface_variant(
  declaration : @checked.CheckedVariantDeclaration,
) -> @module_interface.ModuleInterfaceVariant {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    index: declaration.index,
    type_parameters: declaration.type_parameters,
    payload: declaration.payload,
    loc: declaration.loc,
  }
}

///|
fn SemanticChecker::interface_type_aliases(
  self : SemanticChecker,
) -> Array[@module_interface.ModuleInterfaceTypeAlias] {
  let aliases : Array[@module_interface.ModuleInterfaceTypeAlias] = []
  for declaration in self.resolved_source.declarations {
    match declaration {
      TypeAlias(declaration) if declaration.is_public => {
        let checker = TypeExpressionChecker::{
          source: self.resolved_source,
          imported_environment: self.imported_environment,
          diagnostics: self.diagnostics,
          expanding: [declaration.name],
        }
        let result = checker.synthesize_type(declaration.body)
        self.check_public_interface_type_fallback(result.type_, declaration.loc)
        aliases.push({
          name: declaration.name,
          body: result.type_.normalize(),
          kind: result.kind,
          loc: declaration.loc,
        })
      }
      _ => ()
    }
  }
  aliases
}

///|
fn SemanticChecker::interface_value(
  self : SemanticChecker,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceValue? {
  match declaration {
    Function(declaration) if declaration.is_public => {
      self.check_public_interface_type_fallback(
        declaration.type_,
        declaration.loc,
      )
      Some({
        symbol: declaration.symbol,
        kind: Function,
        name: declaration.name,
        type_: declaration.type_,
        parameters: Some(declaration.parameters.map(interface_value_parameter)),
        loc: declaration.loc,
      })
    }
    Let(declaration) if declaration.is_public && declaration.name is Some(name) => {
      self.check_public_interface_type_fallback(
        declaration.type_,
        declaration.loc,
      )
      Some({
        symbol: declaration.symbol,
        kind: self.interface_value_kind(declaration.symbol),
        name,
        type_: declaration.type_,
        parameters: None,
        loc: declaration.loc,
      })
    }
    _ => None
  }
}

///|
fn SemanticChecker::check_public_interface_resolved_declarations(
  self : SemanticChecker,
) -> Unit {
  for declaration in self.resolved_source.declarations {
    match declaration {
      Struct(declaration) if declaration.is_public =>
        for member_ in declaration.members {
          match member_ {
            Field(field) =>
              self.check_public_interface_resolved_type(field.type_)
            _ => ()
          }
        }
      Enum(declaration) if declaration.is_public =>
        for variant in declaration.variants {
          for payload in variant.payload {
            self.check_public_interface_resolved_type(payload)
          }
        }
      TypeAlias(declaration) if declaration.is_public =>
        self.check_public_interface_resolved_type(declaration.body)
      Function(declaration) if declaration.is_public => {
        for parameter in declaration.parameters {
          self.check_public_interface_resolved_type(parameter.type_)
        }
        self.check_public_interface_resolved_type(declaration.return_type)
      }
      Let(declaration) if declaration.is_public =>
        match declaration.type_annotation {
          Some(type_) => self.check_public_interface_resolved_type(type_)
          None => ()
        }
      Offer(declaration) if declaration.is_public =>
        self.check_public_interface_resolved_type(declaration.type_annotation)
      _ => ()
    }
  }
}

///|
fn SemanticChecker::check_public_interface_resolved_type(
  self : SemanticChecker,
  type_ : @resolve.ResolvedType,
) -> Unit {
  match type_ {
    Constructor(symbol~, loc~, ..) =>
      self.check_public_interface_nominal(symbol, loc, [])
    Apply(callee~, arguments~, ..) => {
      self.check_public_interface_resolved_type(callee)
      for argument in arguments {
        self.check_public_interface_resolved_type(argument)
      }
    }
    TypeLambda(body~, ..) => self.check_public_interface_resolved_type(body)
    Function(parameters~, result~, ..) => {
      for parameter in parameters {
        self.check_public_interface_resolved_type(parameter)
      }
      self.check_public_interface_resolved_type(result)
    }
    Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.check_public_interface_resolved_type(argument)
      }
    Primitive(_) | Alias(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::check_public_interface_type_fallback(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
) -> Unit {
  self.check_public_interface_type_fallback_with_seen(type_, loc, [])
}

///|
fn SemanticChecker::check_public_interface_type_fallback_with_seen(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
  seen : Array[TypeSymbolId],
) -> Unit {
  match type_ {
    Constructor(symbol) =>
      self.check_public_interface_nominal_fallback(symbol, loc, seen)
    Apply(callee, arguments) => {
      self.check_public_interface_type_fallback_with_seen(callee, loc, seen)
      for argument in arguments {
        self.check_public_interface_type_fallback_with_seen(argument, loc, seen)
      }
    }
    TypeLambda(_, body) =>
      self.check_public_interface_type_fallback_with_seen(body, loc, seen)
    Function(parameters, result) => {
      for parameter in parameters {
        self.check_public_interface_type_fallback_with_seen(
          parameter, loc, seen,
        )
      }
      self.check_public_interface_type_fallback_with_seen(result, loc, seen)
    }
    Forall(_, body) =>
      self.check_public_interface_type_fallback_with_seen(body, loc, seen)
    Error | Primitive(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::check_public_interface_nominal(
  self : SemanticChecker,
  symbol : TypeSymbolId,
  loc : SourceSpan,
  seen : Array[TypeSymbolId],
) -> Unit {
  if seen.contains(symbol) {
    return
  }
  seen.push(symbol)
  match self.private_nominal_type_name(symbol) {
    Some(name) => self.diagnostics.push({ kind: PrivateTypeEscape(name~), loc })
    None => ()
  }
}

///|
fn SemanticChecker::check_public_interface_nominal_fallback(
  self : SemanticChecker,
  symbol : TypeSymbolId,
  loc : SourceSpan,
  seen : Array[TypeSymbolId],
) -> Unit {
  if seen.contains(symbol) {
    return
  }
  seen.push(symbol)
  match self.private_nominal_type_name(symbol) {
    Some(name) =>
      if !self.has_private_type_escape_diagnostic(name) {
        self.diagnostics.push({ kind: PrivateTypeEscape(name~), loc })
      }
    None => ()
  }
}

///|
fn SemanticChecker::has_private_type_escape_diagnostic(
  self : SemanticChecker,
  name : String,
) -> Bool {
  for diagnostic in self.diagnostics {
    if diagnostic.kind is PrivateTypeEscape(name=diagnostic_name) &&
      diagnostic_name == name {
      return true
    }
  }
  false
}

///|
fn SemanticChecker::private_nominal_type_name(
  self : SemanticChecker,
  symbol : TypeSymbolId,
) -> String? {
  for declaration in self.declarations.types {
    match declaration {
      Struct(declaration) if declaration.symbol == symbol =>
        if declaration.is_public {
          return None
        } else {
          return Some(declaration.name)
        }
      Enum(declaration) if declaration.symbol == symbol =>
        if declaration.is_public {
          return None
        } else {
          return Some(declaration.name)
        }
      _ => ()
    }
  }
  None
}

///|
fn interface_value_parameter(
  parameter : @checked.CheckedValueParameter,
) -> @module_interface.ModuleInterfaceValueParameter {
  {
    symbol: parameter.symbol,
    is_auto: parameter.is_auto,
    is_offered: parameter.is_offered,
    name: parameter.name,
    type_: parameter.type_,
    loc: parameter.loc,
  }
}

///|
fn SemanticChecker::interface_value_kind(
  self : SemanticChecker,
  symbol : ValueSymbolId,
) -> @module_interface.ModuleInterfaceValueKind {
  for declaration in self.resolved_source.declarations {
    match declaration {
      Offer(declaration) if declaration.symbol == symbol => return Offer
      _ => ()
    }
  }
  Let
}
