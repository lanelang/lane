///|
pub struct TypeDisplayContext {
  registry : @symbol.SymbolRegistry
}

///|
pub fn TypeDisplayContext::from_registry(
  registry : @symbol.SymbolRegistry,
) -> TypeDisplayContext {
  { registry, }
}

///|
pub fn TypeDisplayContext::type_text(
  self : TypeDisplayContext,
  type_ : @types.Type,
) -> String {
  self.type_text_at(type_, [], [])
}

///|
pub fn TypeDisplayContext::type_text_with_tuple_presentations(
  self : TypeDisplayContext,
  type_ : @types.Type,
  presentations : Array[@types.TuplePresentation],
) -> String {
  self.type_text_at(type_, presentations, [])
}

///|
fn tuple_presentation_path(
  path : Array[@types.TuplePresentationPathStep],
  step : @types.TuplePresentationPathStep,
) -> Array[@types.TuplePresentationPathStep] {
  let result = path.copy()
  result.push(step)
  result
}

///|
fn tuple_item_count_at(
  presentations : Array[@types.TuplePresentation],
  path : Array[@types.TuplePresentationPathStep],
) -> Int? {
  for presentation in presentations {
    if presentation.path == path {
      return Some(presentation.item_count)
    }
  }
  None
}

///|
fn TypeDisplayContext::type_text_at(
  self : TypeDisplayContext,
  type_ : @types.Type,
  presentations : Array[@types.TuplePresentation],
  path : Array[@types.TuplePresentationPathStep],
) -> String {
  if tuple_item_count_at(presentations, path) is Some(item_count) {
    match decompose_presented_tuple(type_, item_count) {
      Some(items) => {
        let item_text = []
        for index in 0..<items.length() {
          item_text.push(
            self.type_text_at(
              items[index],
              presentations,
              tuple_presentation_path(path, TupleItem(index)),
            ),
          )
        }
        return "(\{item_text.join(", ")})"
      }
      None => return self.type_text(type_)
    }
  }
  match type_ {
    Error => "<error>"
    Primitive(primitive) => @prettyprinter.render(primitive.pretty(), width=80)
    Constructor(symbol) => self.type_symbol_text(symbol)
    Apply(callee, arguments) => {
      let callee_text = self.type_text_at(
        callee,
        presentations,
        tuple_presentation_path(path, TypeApplicationCallee),
      )
      let argument_text = []
      for index in 0..<arguments.length() {
        argument_text.push(
          self.generic_argument_text_at(
            arguments[index],
            presentations,
            tuple_presentation_path(path, TypeApplicationArgument(index)),
          ),
        )
      }
      "\{callee_text}[\{argument_text.join(", ")}]"
    }
    TypeLambda(parameters, body) => {
      let parameter_text = parameters
        .map(fn(parameter) { self.type_parameter_binding_text(parameter) })
        .join(", ")
      let body_text = self.type_text_at(
        body,
        presentations,
        tuple_presentation_path(path, TypeLambdaBody),
      )
      "type [\{parameter_text}] => \{body_text}"
    }
    Parameter(id) => self.type_parameter_text(id)
    Function(parameters, result, effect) => {
      let parameter_text = []
      for index in 0..<parameters.length() {
        parameter_text.push(
          self.type_text_at(
            parameters[index],
            presentations,
            tuple_presentation_path(path, FunctionParameter(index)),
          ),
        )
      }
      let result_text = self.type_text_at(
        result,
        presentations,
        tuple_presentation_path(path, FunctionResult),
      )
      let effect_text = self.effect_text_at(
        effect,
        presentations,
        tuple_presentation_path(path, FunctionEffect),
      )
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
      let body_text = self.type_text_at(body, presentations, path)
      "forall [\{parameter_text}]. \{body_text}"
    }
  }
}

///|
fn decompose_presented_tuple(
  type_ : @types.Type,
  item_count : Int,
) -> Array[@types.Type]? {
  if item_count < 2 {
    return None
  }
  let items = []
  let mut remaining = type_
  for _ in 0..<(item_count - 1) {
    guard remaining is Apply(_, [TypeArgument(left), TypeArgument(right)]) else {
      return None
    }
    items.push(left)
    remaining = right
  }
  items.push(remaining)
  Some(items)
}

///|
fn TypeDisplayContext::generic_argument_text_at(
  self : TypeDisplayContext,
  argument : @types.GenericArgument,
  presentations : Array[@types.TuplePresentation],
  path : Array[@types.TuplePresentationPathStep],
) -> String {
  match argument {
    TypeArgument(type_) => self.type_text_at(type_, presentations, path)
    EffectArgument(effect) => self.effect_text_at(effect, presentations, path)
  }
}

///|
fn TypeDisplayContext::effect_text_at(
  self : TypeDisplayContext,
  effect : @types.Effect,
  presentations : Array[@types.TuplePresentation],
  path : Array[@types.TuplePresentationPathStep],
) -> String {
  match effect {
    Empty => "{}"
    Io => "Io"
    Singleton(symbol, arguments) => {
      let name = self.effect_symbol_text(symbol)
      let term_path = tuple_presentation_path(path, EffectTerm)
      let argument_text = []
      for index in 0..<arguments.length() {
        argument_text.push(
          self.generic_argument_text_at(
            arguments[index],
            presentations,
            tuple_presentation_path(term_path, TypeApplicationArgument(index)),
          ),
        )
      }
      if argument_text.is_empty() {
        name
      } else {
        "\{name}[\{argument_text.join(", ")}]"
      }
    }
    Union(effects) => {
      let item_text = []
      for index in 0..<effects.length() {
        item_text.push(
          self.effect_text_at(
            effects[index],
            presentations,
            tuple_presentation_path(path, EffectUnionItem(index)),
          ),
        )
      }
      "{ \{item_text.join(", ")} }"
    }
    Parameter(id) => self.type_parameter_text(id)
  }
}

///|
pub fn TypeDisplayContext::effect_text(
  self : TypeDisplayContext,
  effect : @types.Effect,
) -> String {
  self.effect_text_at(effect, [], [])
}

///|
pub fn TypeDisplayContext::generic_argument_text(
  self : TypeDisplayContext,
  argument : @types.GenericArgument,
) -> String {
  self.generic_argument_text_at(argument, [], [])
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
  match self.registry.operation_metadata(symbol) {
    Some(metadata) =>
      self.effect_symbol_text(metadata.owner) + "::" + metadata.name
    None => @prettyprinter.render(symbol.pretty(), width=80)
  }
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
pub fn TypeDisplayContext::type_parameter_binding_text(
  self : TypeDisplayContext,
  parameter : @types.TypeParameter,
) -> String {
  "\{parameter.name} : \{self.kind_text(parameter.kind)}"
}
