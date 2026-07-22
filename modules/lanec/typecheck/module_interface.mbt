///|
fn SemanticChecker::module_interface(
  self : SemanticChecker,
  checked_source : @checked.CheckedSourceFile,
) -> @module_interface.ModuleInterface {
  // Interface construction is the public-boundary judgment. It exports checked
  // declarations only after validating that public signatures do not expose
  // private local nominal types or effects.
  let module_path = @module_interface.module_path_text(
    checked_source.module_path,
  )
  let types = checked_source.declarations.filter_map(fn(declaration) {
    interface_type(declaration)
  })
  let effects = checked_source.declarations.filter_map(fn(declaration) {
    interface_effect_entry(declaration)
  })
  let interface : @module_interface.ModuleInterface = {
    module_path,
    source_id: None,
    type_references: self.interface_type_references(module_path, types),
    effect_references: self.interface_effect_references(module_path, effects),
    types,
    effects,
    type_aliases: self.interface_type_aliases(),
    values: checked_source.declarations.filter_map(fn(declaration) {
      self.interface_value(declaration)
    }),
    optimization_hints: [],
  }
  self.check_public_interface(interface)
  interface
}

///|
fn SemanticChecker::interface_type_references(
  self : SemanticChecker,
  module_path : String,
  types : Array[@module_interface.ModuleInterfaceType],
) -> Array[@module_interface.ModuleInterfaceTypeReference] {
  let references = []
  for type_ in types {
    match type_ {
      Struct(declaration) =>
        append_interface_type_reference(
          references,
          declaration.symbol,
          module_path,
          declaration.name,
        )
      Enum(declaration) =>
        append_interface_type_reference(
          references,
          declaration.symbol,
          module_path,
          declaration.name,
        )
      External(declaration) =>
        append_interface_type_reference(
          references,
          declaration.symbol,
          module_path,
          declaration.name,
        )
    }
  }
  for imported in self.imported_environment.modules {
    for reference in imported.type_references {
      append_interface_type_reference(
        references,
        reference.symbol,
        reference.module_path,
        reference.name,
      )
    }
  }
  references
}

///|
fn append_interface_type_reference(
  references : Array[@module_interface.ModuleInterfaceTypeReference],
  symbol : TypeSymbolId,
  module_path : String,
  name : String,
) -> Unit {
  for reference in references {
    if reference.symbol == symbol {
      return
    }
  }
  references.push({ symbol, module_path, name })
}

///|
fn SemanticChecker::interface_effect_references(
  self : SemanticChecker,
  module_path : String,
  effects : Array[@module_interface.ModuleInterfaceEffect],
) -> Array[@module_interface.ModuleInterfaceEffectReference] {
  let references = []
  for effect in effects {
    append_interface_effect_reference(
      references,
      effect.symbol,
      module_path,
      effect.name,
    )
  }
  for imported in self.imported_environment.modules {
    for reference in imported.effect_references {
      append_interface_effect_reference(
        references,
        reference.symbol,
        reference.module_path,
        reference.name,
      )
    }
  }
  references
}

///|
fn append_interface_effect_reference(
  references : Array[@module_interface.ModuleInterfaceEffectReference],
  symbol : EffectSymbolId,
  module_path : String,
  name : String,
) -> Unit {
  for reference in references {
    if reference.symbol == symbol {
      return
    }
  }
  references.push({ symbol, module_path, name })
}

///|
fn interface_type(
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceType? {
  match declaration {
    Struct(declaration) if declaration.is_public =>
      Some(Struct(interface_struct(declaration)))
    Enum(declaration) if declaration.is_public =>
      Some(Enum(interface_enum(declaration)))
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
fn interface_effect_entry(
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceEffect? {
  match declaration {
    Effect(declaration) if declaration.is_public =>
      Some(interface_effect(declaration))
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
  _self : SemanticChecker,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceValue? {
  match declaration {
    Function(declaration) if declaration.is_public =>
      Some({
        symbol: declaration.symbol,
        kind: Function,
        is_offered: declaration.is_offered,
        name: declaration.name,
        type_: declaration.type_,
        parameters: Some(declaration.parameters.map(interface_value_parameter)),
        loc: declaration.loc,
      })
    Let(declaration) if declaration.is_public && declaration.name is Some(name) =>
      Some({
        symbol: declaration.symbol,
        kind: Let,
        is_offered: declaration.is_offered,
        name,
        type_: declaration.type_,
        parameters: None,
        loc: declaration.loc,
      })
    _ => None
  }
}

///|
priv enum PublicInterfaceEscape {
  Type(TypeSymbolId, String, SourceSpan)
  Effect(EffectSymbolId, String, SourceSpan)
}

///|
fn SemanticChecker::check_public_interface(
  self : SemanticChecker,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  let escapes : Array[PublicInterfaceEscape] = []
  self.collect_resolved_public_interface_escapes(escapes)
  self.collect_checked_public_interface_escapes(interface, escapes)
  for escape in escapes {
    match escape {
      Type(_, name, loc) =>
        self.diagnostics.push({ kind: PrivateTypeEscape(name~), loc })
      Effect(_, name, loc) =>
        self.diagnostics.push({ kind: PrivateEffectEscape(name~), loc })
    }
  }
}

///|
fn SemanticChecker::collect_resolved_public_interface_escapes(
  self : SemanticChecker,
  escapes : Array[PublicInterfaceEscape],
) -> Unit {
  // Resolved annotations provide precise source locations. The checked
  // interface pass below only adds escapes exposed by synthesis or aliases.
  for declaration in self.resolved_source.declarations {
    match declaration {
      Struct(declaration) if declaration.is_public =>
        for member_ in declaration.members {
          match member_ {
            Field(field) =>
              self.collect_resolved_public_interface_type(field.type_, escapes)
            _ => ()
          }
        }
      Enum(declaration) if declaration.is_public =>
        for variant in declaration.variants {
          for payload in variant.payload {
            self.collect_resolved_public_interface_type(payload, escapes)
          }
        }
      Effect(declaration) if declaration.is_public =>
        for operation in declaration.operations {
          for payload in operation.payload {
            self.collect_resolved_public_interface_type(payload, escapes)
          }
          self.collect_resolved_public_interface_type(operation.result, escapes)
        }
      TypeAlias(declaration) if declaration.is_public =>
        if declaration.body is TypeBody(body) {
          self.collect_resolved_public_interface_type(body, escapes)
        }
      Function(declaration) if declaration.is_public => {
        for parameter in declaration.parameters {
          self.collect_resolved_public_interface_type(parameter.type_, escapes)
        }
        self.collect_resolved_public_interface_type(
          declaration.return_type,
          escapes,
        )
        self.collect_resolved_public_interface_effect(
          declaration.effect,
          escapes,
        )
      }
      Let(declaration) if declaration.is_public =>
        match declaration.type_annotation {
          Some(type_) =>
            self.collect_resolved_public_interface_type(type_, escapes)
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn SemanticChecker::collect_resolved_public_interface_type(
  self : SemanticChecker,
  type_ : @resolve.ResolvedType,
  escapes : Array[PublicInterfaceEscape],
) -> Unit {
  match type_ {
    Constructor(symbol~, loc~, ..) =>
      self.collect_public_interface_nominal(symbol, loc, escapes, [])
    Apply(callee~, arguments~, ..) => {
      self.collect_resolved_public_interface_type(callee, escapes)
      for argument in arguments {
        self.collect_resolved_public_interface_generic_argument(
          argument, escapes,
        )
      }
    }
    TypeLambda(body~, ..) =>
      self.collect_resolved_public_interface_type(body, escapes)
    Function(parameters~, result~, effect~, ..) => {
      for parameter in parameters {
        self.collect_resolved_public_interface_type(parameter, escapes)
      }
      self.collect_resolved_public_interface_type(result, escapes)
      self.collect_resolved_public_interface_effect(effect, escapes)
    }
    Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_resolved_public_interface_generic_argument(
          argument, escapes,
        )
      }
    Primitive(_) | Alias(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::collect_resolved_public_interface_generic_argument(
  self : SemanticChecker,
  argument : @resolve.ResolvedGenericArgument,
  escapes : Array[PublicInterfaceEscape],
) -> Unit {
  match argument {
    TypeArgument(type_) =>
      self.collect_resolved_public_interface_type(type_, escapes)
    EffectArgument(effect) =>
      self.collect_resolved_public_interface_effect(effect, escapes)
  }
}

///|
fn SemanticChecker::collect_resolved_public_interface_effect(
  self : SemanticChecker,
  effect : @resolve.ResolvedEffectTerm,
  escapes : Array[PublicInterfaceEscape],
) -> Unit {
  match effect {
    Singleton(symbol~, arguments~, loc~, ..) => {
      self.collect_public_interface_effect_symbol(symbol, loc, escapes)
      for argument in arguments {
        self.collect_resolved_public_interface_generic_argument(
          argument, escapes,
        )
      }
    }
    Io(arguments~, ..) | Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_resolved_public_interface_generic_argument(
          argument, escapes,
        )
      }
    Alias(arguments~, ..) =>
      for argument in arguments {
        match argument {
          TypeArgument(type_) =>
            self.collect_resolved_public_interface_type(type_, escapes)
          EffectArgument(effect) =>
            self.collect_resolved_public_interface_effect(effect, escapes)
        }
      }
    Union(items~, ..) =>
      for item in items {
        self.collect_resolved_public_interface_effect(item, escapes)
      }
    Empty(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::collect_checked_public_interface_escapes(
  self : SemanticChecker,
  interface : @module_interface.ModuleInterface,
  escapes : Array[PublicInterfaceEscape],
) -> Unit {
  for type_ in interface.types {
    match type_ {
      Struct(declaration) =>
        for field in declaration.fields {
          self.collect_public_interface_type(field.type_, field.loc, escapes, [])
        }
      Enum(declaration) =>
        for variant in declaration.variants {
          for payload in variant.payload {
            self.collect_public_interface_type(payload, variant.loc, escapes, [])
          }
        }
      External(_) => ()
    }
  }
  for effect in interface.effects {
    for operation in effect.operations {
      for payload in operation.payload {
        self.collect_public_interface_type(payload, operation.loc, escapes, [])
      }
      self.collect_public_interface_type(
        operation.result,
        operation.loc,
        escapes,
        [],
      )
    }
  }
  for type_alias in interface.type_aliases {
    match type_alias.body {
      TypeBody(type_) =>
        self.collect_public_interface_type(type_, type_alias.loc, escapes, [])
      EffectBody(effect) =>
        self.collect_public_interface_effect(effect, type_alias.loc, escapes, [])
    }
  }
  for value in interface.values {
    self.collect_public_interface_type(value.type_, value.loc, escapes, [])
  }
}

///|
fn SemanticChecker::collect_public_interface_type(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
  escapes : Array[PublicInterfaceEscape],
  seen : Array[TypeSymbolId],
) -> Unit {
  match type_ {
    Constructor(symbol) =>
      self.collect_public_interface_nominal(symbol, loc, escapes, seen)
    Apply(callee, arguments) => {
      self.collect_public_interface_type(callee, loc, escapes, seen)
      for argument in arguments {
        self.collect_public_interface_generic_argument(
          argument, loc, escapes, seen,
        )
      }
    }
    TypeLambda(_, body) =>
      self.collect_public_interface_type(body, loc, escapes, seen)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.collect_public_interface_type(parameter, loc, escapes, seen)
      }
      self.collect_public_interface_type(result, loc, escapes, seen)
      self.collect_public_interface_effect(effect, loc, escapes, seen)
    }
    Forall(_, body) =>
      self.collect_public_interface_type(body, loc, escapes, seen)
    Error | Primitive(_) | Parameter(_) => ()
  }
}

///|
fn SemanticChecker::collect_public_interface_generic_argument(
  self : SemanticChecker,
  argument : @types.GenericArgument,
  loc : SourceSpan,
  escapes : Array[PublicInterfaceEscape],
  seen : Array[TypeSymbolId],
) -> Unit {
  match argument {
    TypeArgument(type_) =>
      self.collect_public_interface_type(type_, loc, escapes, seen)
    EffectArgument(effect) =>
      self.collect_public_interface_effect(effect, loc, escapes, seen)
  }
}

///|
fn SemanticChecker::collect_public_interface_effect(
  self : SemanticChecker,
  effect : @types.Effect,
  loc : SourceSpan,
  escapes : Array[PublicInterfaceEscape],
  seen : Array[@symbol.TypeSymbolId],
) -> Unit {
  match effect {
    Empty | Io | Parameter(_) => ()
    Singleton(symbol, arguments) => {
      self.collect_public_interface_effect_symbol(symbol, loc, escapes)
      for argument in arguments {
        self.collect_public_interface_generic_argument(
          argument, loc, escapes, seen,
        )
      }
    }
    Union(effects) =>
      for item in effects {
        self.collect_public_interface_effect(item, loc, escapes, seen)
      }
  }
}

///|
fn SemanticChecker::collect_public_interface_effect_symbol(
  self : SemanticChecker,
  symbol : EffectSymbolId,
  loc : SourceSpan,
  escapes : Array[PublicInterfaceEscape],
) -> Unit {
  match self.private_effect_name(symbol) {
    Some(name) => {
      for escape in escapes {
        if escape is Effect(existing, _, _) && existing == symbol {
          return
        }
      }
      escapes.push(Effect(symbol, name, loc))
    }
    None => ()
  }
}

///|
fn SemanticChecker::collect_public_interface_nominal(
  self : SemanticChecker,
  symbol : TypeSymbolId,
  loc : SourceSpan,
  escapes : Array[PublicInterfaceEscape],
  seen : Array[TypeSymbolId],
) -> Unit {
  if seen.contains(symbol) {
    return
  }
  seen.push(symbol)
  match self.private_nominal_type_name(symbol) {
    Some(name) => {
      for escape in escapes {
        if escape is Type(existing, _, _) && existing == symbol {
          return
        }
      }
      escapes.push(Type(symbol, name, loc))
    }
    None => ()
  }
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
