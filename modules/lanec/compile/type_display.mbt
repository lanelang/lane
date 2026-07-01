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
        .map(fn(argument) { self.type_text(argument) })
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
    Function(parameters, result) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_text(parameter) })
        .join(", ")
      let result_text = self.type_text(result)
      "(\{parameter_text}) -> \{result_text}"
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
