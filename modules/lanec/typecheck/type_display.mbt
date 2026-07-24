///|
pub struct TypeDisplayContext {
  registry : @symbol.SymbolRegistry?
  type_names : Array[(@symbol.TypeSymbolId, String)]
  effect_names : Array[(@symbol.EffectSymbolId, String)]
  type_parameter_names : Array[(@symbol.TypeParameterId, String)]
}

///|
pub fn TypeDisplayContext::from_registry(
  registry : @symbol.SymbolRegistry,
) -> TypeDisplayContext {
  {
    registry: Some(registry),
    type_names: [],
    effect_names: [],
    type_parameter_names: [],
  }
}

///|
pub fn TypeDisplayContext::from_names(
  type_names : Array[(@symbol.TypeSymbolId, String)],
  effect_names : Array[(@symbol.EffectSymbolId, String)],
  type_parameter_names : Array[(@symbol.TypeParameterId, String)],
) -> TypeDisplayContext {
  { registry: None, type_names, effect_names, type_parameter_names }
}

///|
pub fn TypeDisplayContext::type_text(
  self : TypeDisplayContext,
  type_ : @types.Type,
) -> String {
  match type_ {
    Error => "<error>"
    Primitive(primitive) => @prettyprinter.render(primitive.pretty(), width=80)
    Constructor(symbol) => self.type_symbol_text(symbol)
    Apply(callee, arguments) =>
      "\{self.type_text(callee)}[\{arguments.map(fn(argument) { self.generic_argument_text(argument) }).join(", ")}]"
    TypeLambda(parameters, body) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_parameter_binding_text(parameter) })
        .join(", ")
      "type [\{parameter_text}] => \{self.type_text(body)}"
    }
    Parameter(id) => self.type_parameter_text(id)
    Function(parameters, result, effect) => {
      let parameter_text = parameters.map(fn(parameter) {
        self.type_text(parameter)
      })
      let result_text = self.type_text(result)
      let effect_text = self.effect_text(effect)
      if effect_text == "{}" {
        "(\{parameter_text.join(", ")}) -> \{result_text}"
      } else {
        "(\{parameter_text.join(", ")}) -> \{result_text} ! \{effect_text}"
      }
    }
    Forall(parameters, body) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_parameter_binding_text(parameter) })
        .join(", ")
      "forall [\{parameter_text}]. \{self.type_text(body)}"
    }
  }
}

///|
pub fn TypeDisplayContext::effect_text(
  self : TypeDisplayContext,
  effect : @types.Effect,
) -> String {
  match effect {
    Empty => "{}"
    Io => "Io"
    Singleton(symbol, arguments) => {
      let name = self.effect_symbol_text(symbol)
      if arguments.is_empty() {
        name
      } else {
        "\{name}[\{arguments.map(fn(argument) { self.generic_argument_text(argument) }).join(", ")}]"
      }
    }
    Union(effects) =>
      "{ \{effects.map(fn(effect) { self.effect_text(effect) }).join(", ")} }"
    Parameter(id) => self.type_parameter_text(id)
  }
}

///|
pub fn TypeDisplayContext::generic_argument_text(
  self : TypeDisplayContext,
  argument : @types.GenericArgument,
) -> String {
  match argument {
    TypeArgument(type_) => self.type_text(type_)
    EffectArgument(effect) => self.effect_text(effect)
  }
}

///|
pub fn TypeDisplayContext::kind_text(
  _self : TypeDisplayContext,
  kind : @types.Kind,
) -> String {
  @prettyprinter.render(kind.pretty(), width=80)
}

///|
pub fn TypeDisplayContext::operation_text(
  self : TypeDisplayContext,
  symbol : @symbol.OperationSymbolId,
) -> String {
  if self.registry is Some(registry) &&
    registry.operation_metadata(symbol) is Some(metadata) {
    self.effect_symbol_text(metadata.owner) + "::" + metadata.name
  } else {
    @prettyprinter.render(symbol.pretty(), width=80)
  }
}

///|
fn TypeDisplayContext::type_symbol_text(
  self : TypeDisplayContext,
  symbol : @symbol.TypeSymbolId,
) -> String {
  if self.registry is Some(registry) &&
    registry.type_metadata(symbol) is Some(metadata) {
    return metadata.name
  }
  for item in self.type_names {
    let (id, name) = item
    if id == symbol {
      return name
    }
  }
  @prettyprinter.render(symbol.pretty(), width=80)
}

///|
fn TypeDisplayContext::effect_symbol_text(
  self : TypeDisplayContext,
  symbol : @symbol.EffectSymbolId,
) -> String {
  if self.registry is Some(registry) &&
    registry.effect_metadata(symbol) is Some(metadata) {
    return metadata.name
  }
  for item in self.effect_names {
    let (id, name) = item
    if id == symbol {
      return name
    }
  }
  @prettyprinter.render(symbol.pretty(), width=80)
}

///|
fn TypeDisplayContext::type_parameter_text(
  self : TypeDisplayContext,
  id : @symbol.TypeParameterId,
) -> String {
  if self.registry is Some(registry) &&
    registry.type_parameter_metadata(id) is Some(metadata) {
    return metadata.name
  }
  for item in self.type_parameter_names {
    let (candidate, name) = item
    if candidate == id {
      return name
    }
  }
  @prettyprinter.render(id.pretty(), width=80)
}

///|
pub fn TypeDisplayContext::type_parameter_binding_text(
  self : TypeDisplayContext,
  parameter : @types.TypeParameter,
) -> String {
  "\{parameter.name} : \{self.kind_text(parameter.kind)}"
}
