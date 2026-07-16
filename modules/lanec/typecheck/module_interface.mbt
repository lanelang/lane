///|
fn SemanticChecker::module_interface(
  self : SemanticChecker,
  checked_source : @checked.CheckedSourceFile,
) -> @module_interface.ModuleInterface {
  // Interface construction is the public-boundary judgment. It exports checked
  // declarations only after validating that public signatures do not expose
  // private local nominal types or effects.
  self.check_public_interface_resolved_declarations()
  {
    module_path: @module_interface.module_path_text(checked_source.module_path),
    source_id: None,
    types: checked_source.declarations.filter_map(fn(declaration) {
      self.interface_type(declaration)
    }),
    effects: checked_source.declarations.filter_map(fn(declaration) {
      self.interface_effect(declaration)
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
    ExternalType(declaration) if declaration.is_public =>
      Some(
        External({
          symbol: declaration.symbol,
          name: declaration.name,
          loc: declaration.loc,
        }),
      )
    _ => None
  }
}

///|
fn SemanticChecker::interface_effect(
  self : SemanticChecker,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceEffect? {
  match declaration {
    Effect(declaration) if declaration.is_public => {
      for operation in declaration.operations {
        for payload in operation.payload {
          self.check_public_interface_type_fallback(payload, operation.loc)
        }
        self.check_public_interface_type_fallback(
          operation.result,
          operation.loc,
        )
      }
      Some(interface_effect(declaration))
    }
    _ => None
  }
}

///|
fn interface_effect(
  declaration : @checked.CheckedEffectDeclaration,
) -> @module_interface.ModuleInterfaceEffect {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    flavor: declaration.flavor,
    type_parameters: declaration.type_parameters,
    operations: declaration.operations.map(interface_operation),
    loc: declaration.loc,
  }
}

///|
fn interface_operation(
  operation : @checked.CheckedEffectOperationDeclaration,
) -> @module_interface.ModuleInterfaceOperation {
  {
    symbol: operation.symbol,
    name: operation.name,
    index: operation.index,
    type_parameters: operation.type_parameters,
    payload: operation.payload,
    result: operation.result,
    loc: operation.loc,
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
        let type_parameters = check_type_parameters(
          self.diagnostics,
          declaration.type_parameters,
        )
        match declaration.body {
          TypeBody(body) => {
            let result = checker.synthesize_type(body)
            self.check_public_interface_type_fallback(
              result.type_,
              declaration.loc,
            )
            aliases.push({
              name: declaration.name,
              type_parameters,
              body: TypeBody(
                normalize_type_or_error(
                  checker.diagnostics,
                  result.type_,
                  declaration.loc,
                  context="type alias body",
                ),
              ),
              kind: result.kind,
              loc: declaration.loc,
            })
          }
          EffectBody(effect) => {
            let checked = normalize_effect_or_empty(
              checker.diagnostics,
              checker.check_effect(effect),
              declaration.loc,
              context="effect alias body",
            )
            self.check_public_interface_effect_fallback_with_seen(
              checked,
              declaration.loc,
              [],
            )
            aliases.push({
              name: declaration.name,
              type_parameters,
              body: EffectBody(checked),
              kind: effect_alias_interface_kind(type_parameters),
              loc: declaration.loc,
            })
          }
        }
      }
      _ => ()
    }
  }
  aliases
}

///|
fn effect_alias_interface_kind(
  type_parameters : Array[@types.TypeParameter],
) -> @types.Kind {
  if type_parameters.is_empty() {
    Effect
  } else {
    Function(type_parameters.map(fn(parameter) { parameter.kind }), Effect)
  }
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
  // Run the escape check over resolved public annotations before the checked
  // fallback below. This gives diagnostics near the source signature and still
  // leaves alias-expanded checked types to catch synthesized escapes.
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
      Effect(declaration) if declaration.is_public =>
        for operation in declaration.operations {
          for payload in operation.payload {
            self.check_public_interface_resolved_type(payload)
          }
          self.check_public_interface_resolved_type(operation.result)
        }
      TypeAlias(declaration) if declaration.is_public =>
        if declaration.body is TypeBody(body) {
          self.check_public_interface_resolved_type(body)
        }
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
        self.check_public_interface_resolved_generic_argument(argument)
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
        self.check_public_interface_resolved_generic_argument(argument)
      }
    Primitive(_) | Alias(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::check_public_interface_resolved_generic_argument(
  self : SemanticChecker,
  argument : @resolve.ResolvedGenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.check_public_interface_resolved_type(type_)
    EffectArgument(effect) =>
      self.check_public_interface_resolved_effect(effect)
  }
}

///|
fn SemanticChecker::check_public_interface_resolved_effect(
  self : SemanticChecker,
  effect : @resolve.ResolvedEffectTerm,
) -> Unit {
  match effect {
    Io(arguments~, ..)
    | Singleton(arguments~, ..)
    | Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.check_public_interface_resolved_generic_argument(argument)
      }
    Alias(arguments~, ..) =>
      for argument in arguments {
        match argument {
          TypeArgument(type_) =>
            self.check_public_interface_resolved_type(type_)
          EffectArgument(effect) =>
            self.check_public_interface_resolved_effect(effect)
        }
      }
    Union(items~, ..) =>
      for item in items {
        self.check_public_interface_resolved_effect(item)
      }
    Empty(_) | Parameter(_) => ()
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
        self.check_public_interface_generic_argument_fallback_with_seen(
          argument, loc, seen,
        )
      }
    }
    TypeLambda(_, body) =>
      self.check_public_interface_type_fallback_with_seen(body, loc, seen)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.check_public_interface_type_fallback_with_seen(
          parameter, loc, seen,
        )
      }
      self.check_public_interface_type_fallback_with_seen(result, loc, seen)
      self.check_public_interface_effect_fallback_with_seen(effect, loc, seen)
    }
    Forall(_, body) =>
      self.check_public_interface_type_fallback_with_seen(body, loc, seen)
    Error | Primitive(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::check_public_interface_generic_argument_fallback_with_seen(
  self : SemanticChecker,
  argument : @types.GenericArgument,
  loc : SourceSpan,
  seen : Array[TypeSymbolId],
) -> Unit {
  match argument {
    TypeArgument(type_) =>
      self.check_public_interface_type_fallback_with_seen(type_, loc, seen)
    EffectArgument(effect) =>
      self.check_public_interface_effect_fallback_with_seen(effect, loc, seen)
  }
}

///|
fn SemanticChecker::check_public_interface_effect_fallback_with_seen(
  self : SemanticChecker,
  effect : @types.Effect,
  loc : SourceSpan,
  seen : Array[@symbol.TypeSymbolId],
) -> Unit {
  match effect {
    Empty | Io | Parameter(_) => ()
    Singleton(symbol, arguments) => {
      self.check_public_interface_effect_fallback(symbol, loc)
      for argument in arguments {
        self.check_public_interface_generic_argument_fallback_with_seen(
          argument, loc, seen,
        )
      }
    }
    Union(effects) =>
      for item in effects {
        self.check_public_interface_effect_fallback_with_seen(item, loc, seen)
      }
  }
}

///|
fn SemanticChecker::check_public_interface_effect_fallback(
  self : SemanticChecker,
  symbol : EffectSymbolId,
  loc : SourceSpan,
) -> Unit {
  match self.private_effect_name(symbol) {
    Some(name) =>
      if !self.has_private_effect_escape_diagnostic(name) {
        self.diagnostics.push({ kind: PrivateEffectEscape(name~), loc })
      }
    None => ()
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
fn SemanticChecker::has_private_effect_escape_diagnostic(
  self : SemanticChecker,
  name : String,
) -> Bool {
  for diagnostic in self.diagnostics {
    if diagnostic.kind is PrivateEffectEscape(name=diagnostic_name) &&
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
fn SemanticChecker::private_effect_name(
  self : SemanticChecker,
  symbol : EffectSymbolId,
) -> String? {
  for declaration in self.declarations.effects {
    if declaration.symbol == symbol && !declaration.is_public {
      return Some(declaration.name)
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
