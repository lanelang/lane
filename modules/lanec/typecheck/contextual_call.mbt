///|
priv struct NamedDirectArgument {
  name : String
  value : @desugar.DesugaredExpr
  loc : SourceSpan
}

///|
priv struct PositionalDirectArgument {
  value : @desugar.DesugaredExpr
  loc : SourceSpan
}

///|
priv struct CollectedDirectArguments {
  positional : Array[PositionalDirectArgument]
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
  // Contextual insertion is a local rewrite for direct calls to known function
  // symbols. Supplied arguments are checked first; omitted trailing auto
  // parameters are filled from exactly matching visible offers.
  guard direct_call_symbol(callee) is Some(symbol) else { return arguments }
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
fn direct_call_symbol(callee : @desugar.DesugaredExpr) -> ValueSymbolId? {
  match callee {
    Var(reference=Symbol(symbol), ..) => Some(symbol)
    GenericApplication(callee~, ..) => direct_call_symbol(callee)
    _ => None
  }
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
      self.diagnostics.push({ kind: AutoParametersMustBeTrailing, loc })
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
      Positional(value~, loc~) => {
        if positional.length() >= positional_count {
          self.diagnostics.push({ kind: AutoArgumentMustBeNamed, loc })
          return None
        }
        positional.push({ value, loc })
      }
      Named(name~, value~, loc~) => {
        if named_direct_argument(named, name) is Some(_) {
          self.diagnostics.push({ kind: DuplicateNamedArgument(name~), loc })
          return None
        }
        named.push({ name, value, loc })
      }
    }
  }
  if positional.length() != positional_count {
    self.diagnostics.push({
      kind: CallArityMismatch(
        expected=positional_count,
        actual=positional.length(),
      ),
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
  positional : Array[PositionalDirectArgument],
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
      let templates = []
      let expressions = []
      for index in 0..<positional.length() {
        templates.push(parameter_types[index])
        expressions.push(positional[index].value)
      }
      for argument in named {
        guard auto_parameter_index(parameters, argument.name, first_auto)
          is Some(index) else {
          self.diagnostics.push({
            kind: UnknownContextualArgument(name=argument.name),
            loc: argument.loc,
          })
          return None
        }
        templates.push(parameter_types[index])
        expressions.push(argument.value)
      }
      guard self.infer_contextual_callable_generic_arguments(
          scope, type_parameters, templates, expressions, result, expected_result,
          loc,
        )
        is Some(inferred) else {
        return None
      }
      Some(
        parameter_types.map(fn(parameter) {
          parameter.substitute(inferred.substitution)
        }),
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
  positional : Array[PositionalDirectArgument],
  named : Array[NamedDirectArgument],
  first_auto : Int,
  loc : SourceSpan,
) -> Array[@desugar.DesugaredCallArgument] {
  let result : Array[@desugar.DesugaredCallArgument] = []
  for argument in positional {
    result.push(Positional(value=argument.value, loc=argument.loc))
  }
  for argument in named {
    if auto_parameter_index(parameters, argument.name, first_auto) is None {
      self.diagnostics.push({
        kind: UnknownContextualArgument(name=argument.name),
        loc: argument.loc,
      })
      return result
    }
  }
  for index in first_auto..<parameters.length() {
    let parameter = parameters[index]
    match named_direct_argument(named, parameter.name) {
      Some(argument) =>
        result.push(Positional(value=argument.value, loc=argument.loc))
      None =>
        match self.contextual_offer_expr(scope, parameter_types[index], loc) {
          Some(argument) =>
            result.push(Positional(value=argument, loc=argument.loc()))
          None =>
            result.push(Positional(value=error_contextual_argument(loc), loc~))
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
  // Offer matching is exact type equality over the already-resolved flat offer
  // environment. It must not infer generics from the offer set.
  let matches = []
  for offer in scope.offers {
    if self.type_matches(expected, offer.type_, loc) {
      matches.push(offer)
    }
  }
  match matches.length() {
    0 => {
      self.diagnostics.push({ kind: MissingContextualOffer(expected~), loc })
      None
    }
    1 => {
      let offer = matches[0]
      Some(offer.expression)
    }
    _ => {
      self.diagnostics.push({
        kind: AmbiguousContextualOffer(
          expected~,
          candidates=matches.map(fn(offer) {
            self.contextual_offer_diagnostic_candidate(offer)
          }),
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
