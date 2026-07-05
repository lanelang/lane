///|
priv struct TypeDisplayContext {
  registry : @symbol.SymbolRegistry
}

///|
fn TypeDisplayContext::from_registry(
  registry : @symbol.SymbolRegistry,
) -> TypeDisplayContext {
  { registry, }
}

///|
fn TypeDisplayContext::type_text(
  self : TypeDisplayContext,
  type_ : @types.Type,
) -> String {
  match type_ {
    Error => "<error>"
    Primitive(primitive) => @prettyprinter.render(primitive.pretty(), width=80)
    Constructor(symbol) => self.type_symbol_text(symbol)
    Apply(callee, arguments) => {
      let callee_text = self.type_text(callee)
      let argument_text = arguments
        .map(fn(argument) { self.generic_argument_text(argument) })
        .join(", ")
      "\{callee_text}[\{argument_text}]"
    }
    TypeLambda(parameters, body) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_parameter_binding_text(parameter) })
        .join(", ")
      let body_text = self.type_text(body)
      "type [\{parameter_text}] => \{body_text}"
    }
    Parameter(id) => self.type_parameter_text(id)
    Function(parameters, result, effect) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_text(parameter) })
        .join(", ")
      let result_text = self.type_text(result)
      let effect_text = self.effect_text(effect)
      if effect_text == "{}" {
        "(\{parameter_text}) -> \{result_text}"
      } else {
        "(\{parameter_text}) -> \{result_text} ! \{effect_text}"
      }
    }
    Forall(parameters, body) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_parameter_binding_text(parameter) })
        .join(", ")
      let body_text = self.type_text(body)
      "forall [\{parameter_text}]. \{body_text}"
    }
  }
}

///|
fn TypeDisplayContext::effect_text(
  self : TypeDisplayContext,
  effect : @types.Effect,
) -> String {
  match effect {
    Empty => "{}"
    Singleton(symbol, arguments) => {
      let name = self.effect_symbol_text(symbol)
      if arguments.is_empty() {
        name
      } else {
        let arguments = arguments
          .map(fn(argument) { self.generic_argument_text(argument) })
          .join(", ")
        "\{name}[\{arguments}]"
      }
    }
    Parameter(id) => self.type_parameter_text(id)
    Union(effects) =>
      "{ \{effects.map(fn(effect) { self.effect_text(effect) }).join(", ")} }"
  }
}

///|
fn TypeDisplayContext::generic_argument_text(
  self : TypeDisplayContext,
  argument : @types.GenericArgument,
) -> String {
  match argument {
    TypeArgument(type_) => self.type_text(type_)
    EffectArgument(effect) => self.effect_text(effect)
  }
}

///|
fn TypeDisplayContext::kind_text(
  _self : TypeDisplayContext,
  kind : @types.Kind,
) -> String {
  @prettyprinter.render(kind.pretty(), width=80)
}

///|
fn TypeDisplayContext::type_symbol_text(
  self : TypeDisplayContext,
  symbol : @symbol.TypeSymbolId,
) -> String {
  match self.registry.type_metadata(symbol) {
    Some(metadata) => metadata.name
    None => @prettyprinter.render(symbol.pretty(), width=80)
  }
}

///|
fn TypeDisplayContext::effect_symbol_text(
  self : TypeDisplayContext,
  symbol : @symbol.EffectSymbolId,
) -> String {
  match self.registry.effect_metadata(symbol) {
    Some(metadata) => metadata.name
    None => @prettyprinter.render(symbol.pretty(), width=80)
  }
}

///|
fn TypeDisplayContext::type_parameter_text(
  self : TypeDisplayContext,
  id : @symbol.TypeParameterId,
) -> String {
  match self.registry.type_parameter_metadata(id) {
    Some(metadata) => metadata.name
    None => @prettyprinter.render(id.pretty(), width=80)
  }
}

///|
fn TypeDisplayContext::type_parameter_binding_text(
  self : TypeDisplayContext,
  parameter : @types.TypeParameter,
) -> String {
  "\{parameter.name} : \{self.kind_text(parameter.kind)}"
}
