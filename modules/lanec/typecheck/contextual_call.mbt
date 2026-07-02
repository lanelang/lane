///|
priv struct NamedDirectArgument {
  name : String
  value : @desugar.DesugaredExpr
  loc : SourceSpan
}

///|
priv struct CollectedDirectArguments {
  positional : Array[@desugar.DesugaredExpr]
  named : Array[NamedDirectArgument]
}

///|
fn SemanticChecker::prepare_direct_call_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  callee_type : @types.Type,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> Array[@desugar.DesugaredCallArgument] {
  guard callee is Var(reference=Symbol(symbol), ..) else { return arguments }
  guard scope.lookup_function_parameters(symbol) is Some(parameters) else {
    return arguments
  }
  let first_auto = first_auto_parameter(parameters)
  guard first_auto is Some(first_auto) else { return arguments }
  if !self.validate_auto_parameter_suffix(parameters, first_auto, loc) {
    return arguments
  }
  guard self.collect_direct_arguments(arguments, first_auto, loc)
    is Some(collected) else {
    return arguments
  }
  guard self.direct_parameter_types(
      scope,
      callee_type,
      parameters,
      collected.positional,
      collected.named,
      first_auto,
      expected_result,
      loc,
    )
    is Some(parameter_types) else {
    return arguments
  }
  self.complete_direct_call_arguments(
    scope,
    parameters,
    parameter_types,
    collected.positional,
    collected.named,
    first_auto,
    loc,
  )
}

///|
fn first_auto_parameter(
  parameters : Array[@checked.CheckedValueParameter],
) -> Int? {
  for index in 0..<parameters.length() {
    if parameters[index].is_auto {
      return Some(index)
    }
  }
  None
}

///|
fn SemanticChecker::validate_auto_parameter_suffix(
  self : SemanticChecker,
  parameters : Array[@checked.CheckedValueParameter],
  first_auto : Int,
  loc : SourceSpan,
) -> Bool {
  for index in first_auto..<parameters.length() {
    if !parameters[index].is_auto {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="auto parameters must be trailing",
          reason=Generic,
        ),
        loc,
      })
      return false
    }
  }
  true
}

///|
fn SemanticChecker::collect_direct_arguments(
  self : SemanticChecker,
  arguments : Array[@desugar.DesugaredCallArgument],
  positional_count : Int,
  loc : SourceSpan,
) -> CollectedDirectArguments? {
  let positional = []
  let named = []
  for argument in arguments {
    match argument {
      Positional(value) => {
        if positional.length() >= positional_count {
          self.diagnostics.push({
            kind: CannotInferExpression(
              label="auto arguments must be named",
              reason=Generic,
            ),
            loc: value.loc(),
          })
          return None
        }
        positional.push(value)
      }
      Named(name~, value~, loc~) => {
        if named_direct_argument(named, name) is Some(_) {
          self.diagnostics.push({
            kind: CannotInferExpression(
              label="duplicate named argument " + name,
              reason=Generic,
            ),
            loc,
          })
          return None
        }
        named.push({ name, value, loc })
      }
    }
  }
  if positional.length() != positional_count {
    self.diagnostics.push({
      kind: CannotInferExpression(label="call arity", reason=CallArity),
      loc,
    })
    return None
  }
  Some({ positional, named })
}

///|
fn named_direct_argument(
  arguments : Array[NamedDirectArgument],
  name : String,
) -> NamedDirectArgument? {
  for argument in arguments {
    if argument.name == name {
      return Some(argument)
    }
  }
  None
}

///|
fn auto_parameter_index(
  parameters : Array[@checked.CheckedValueParameter],
  name : String,
  first_auto : Int,
) -> Int? {
  for index in first_auto..<parameters.length() {
    if parameters[index].name == name {
      return Some(index)
    }
  }
  None
}

///|
fn SemanticChecker::direct_parameter_types(
  self : SemanticChecker,
  scope : TypeScope,
  callee_type : @types.Type,
  parameters : Array[@checked.CheckedValueParameter],
  positional : Array[@desugar.DesugaredExpr],
  named : Array[NamedDirectArgument],
  first_auto : Int,
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> Array[@types.Type]? {
  match callee_type {
    Function(parameter_types, _, _) =>
      if parameter_types.length() == parameters.length() {
        Some(parameter_types)
      } else {
        None
      }
    Forall(type_parameters, Function(parameter_types, result, _)) => {
      if parameter_types.length() != parameters.length() {
        return None
      }
      let inference = TypeArgumentInference::TypeArgumentInference(
        type_parameters,
      )
      for index in 0..<positional.length() {
        if self.synthesize_argument_for_type_arguments(scope, positional[index])
          is Some(actual) {
          inference.collect(parameter_types[index], actual)
        }
      }
      for argument in named {
        guard auto_parameter_index(parameters, argument.name, first_auto)
          is Some(index) else {
          self.diagnostics.push({
            kind: CannotInferExpression(
              label="unknown contextual argument " + argument.name,
              reason=Generic,
            ),
            loc: argument.loc,
          })
          return None
        }
        if self.synthesize_argument_for_type_arguments(scope, argument.value)
          is Some(actual) {
          inference.collect(parameter_types[index], actual)
        }
      }
      if expected_result is Some(expected) {
        inference.collect(result, expected)
      }
      guard inference.substitution() is Some(substitution) else {
        self.diagnostics.push({
          kind: CannotInferExpression(
            label="type arguments",
            reason=TypeArguments,
          ),
          loc,
        })
        return None
      }
      Some(
        parameter_types.map(fn(parameter) { parameter.substitute(substitution) }),
      )
    }
    _ => None
  }
}

///|
fn SemanticChecker::complete_direct_call_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  parameters : Array[@checked.CheckedValueParameter],
  parameter_types : Array[@types.Type],
  positional : Array[@desugar.DesugaredExpr],
  named : Array[NamedDirectArgument],
  first_auto : Int,
  loc : SourceSpan,
) -> Array[@desugar.DesugaredCallArgument] {
  let result : Array[@desugar.DesugaredCallArgument] = []
  for argument in positional {
    result.push(Positional(argument))
  }
  for argument in named {
    if auto_parameter_index(parameters, argument.name, first_auto) is None {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="unknown contextual argument " + argument.name,
          reason=Generic,
        ),
        loc: argument.loc,
      })
      return result
    }
  }
  for index in first_auto..<parameters.length() {
    let parameter = parameters[index]
    match named_direct_argument(named, parameter.name) {
      Some(argument) => result.push(Positional(argument.value))
      None =>
        match self.contextual_offer_expr(scope, parameter_types[index], loc) {
          Some(argument) => result.push(Positional(argument))
          None => result.push(Positional(error_contextual_argument(loc)))
        }
    }
  }
  result
}

///|
fn SemanticChecker::contextual_offer_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expected : @types.Type,
  loc : SourceSpan,
) -> @desugar.DesugaredExpr? {
  let matches = []
  for offer in scope.offers {
    if type_matches(expected, offer.type_) {
      matches.push(offer)
    }
  }
  match matches.length() {
    0 => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="missing contextual offer",
          reason=ContextualOffer,
        ),
        loc,
      })
      None
    }
    1 => {
      let offer = matches[0]
      Some(offer.expression)
    }
    _ => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="ambiguous contextual offer",
          reason=ContextualOffer,
        ),
        loc,
      })
      None
    }
  }
}

///|
fn error_contextual_argument(loc : SourceSpan) -> @desugar.DesugaredExpr {
  Builtin("%contextual_error", loc~)
}
