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
priv struct ContextualProviderParameter {
  name : String
  type_ : @types.Type
}

///|
priv enum ContextualOfferResolution {
  UniqueContextualOffer(@desugar.DesugaredExpr)
  MissingContextualOfferResolution(@types.Type)
  AmbiguousContextualOfferResolution(@types.Type, Array[ContextualOffer])
  ContextualOfferComputationFailed
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
  match self.resolve_contextual_offer(scope, expected, loc, []) {
    UniqueContextualOffer(expression) => Some(expression)
    MissingContextualOfferResolution(expected) => {
      self.diagnostics.push({ kind: MissingContextualOffer(expected~), loc })
      None
    }
    AmbiguousContextualOfferResolution(expected, candidates) => {
      self.diagnostics.push({
        kind: AmbiguousContextualOffer(
          expected~,
          candidates=candidates.map(contextual_offer_diagnostic_candidate),
        ),
        loc,
      })
      None
    }
    ContextualOfferComputationFailed => None
  }
}

///|
fn SemanticChecker::resolve_contextual_offer(
  self : SemanticChecker,
  scope : TypeScope,
  expected : @types.Type,
  loc : SourceSpan,
  active_goals : Array[@types.Type],
) -> ContextualOfferResolution {
  // Exact evidence is selected before providers. A provider is an ordinary
  // offered function whose parameters are all contextual; its generic
  // arguments are determined only from the requested result type.
  let exact_matches = []
  let mut computation_failed = false
  scope.offers.each_visible(fn(offer) {
    match self.type_matches(expected, offer.type_, loc) {
      Some(true) => exact_matches.push(offer)
      Some(false) => ()
      None => computation_failed = true
    }
  })
  if computation_failed {
    return ContextualOfferComputationFailed
  }
  if exact_matches.length() == 1 {
    return UniqueContextualOffer(exact_matches[0].expression)
  }
  if exact_matches.length() > 1 {
    return AmbiguousContextualOfferResolution(expected, exact_matches)
  }
  for active in active_goals {
    match self.type_matches(expected, active, loc) {
      Some(true) => return MissingContextualOfferResolution(expected)
      Some(false) => ()
      None => return ContextualOfferComputationFailed
    }
  }
  let next_goals = active_goals.copy()
  next_goals.push(expected)
  let provider_matches = []
  let mut blocked : ContextualOfferResolution? = None
  scope.offers.each_visible(fn(offer) {
    guard self.contextual_provider_parameters(scope, offer, expected, loc)
      is Some(parameters) else {
      return
    }
    let arguments = []
    for parameter in parameters {
      match
        self.resolve_contextual_offer(scope, parameter.type_, loc, next_goals) {
        UniqueContextualOffer(expression) =>
          arguments.push(
            @desugar.DesugaredCallArgument::Named(
              name=parameter.name,
              value=expression,
              loc~,
            ),
          )
        failure => {
          if blocked is None {
            blocked = Some(failure)
          }
          return
        }
      }
    }
    provider_matches.push(
      (
        offer,
        @desugar.DesugaredExpr::Call(callee=offer.expression, arguments~, loc~),
      ),
    )
  })
  if provider_matches.length() == 1 {
    return UniqueContextualOffer(provider_matches[0].1)
  }
  if provider_matches.length() > 1 {
    return AmbiguousContextualOfferResolution(
      expected,
      provider_matches.map(fn(match_) { match_.0 }),
    )
  }
  match blocked {
    Some(failure) => failure
    None => MissingContextualOfferResolution(expected)
  }
}

///|
fn SemanticChecker::contextual_provider_parameters(
  self : SemanticChecker,
  scope : TypeScope,
  offer : ContextualOffer,
  expected : @types.Type,
  loc : SourceSpan,
) -> Array[ContextualProviderParameter]? {
  guard scope.lookup_function_parameters(offer.symbol) is Some(parameters) else {
    return None
  }
  if parameters.any(fn(parameter) { !parameter.is_auto }) {
    return None
  }
  let (parameter_types, result) = match offer.type_ {
    Function(parameter_types, result, _) => (parameter_types, result)
    Forall(type_parameters, Function(parameter_types, result, _)) => {
      guard self.infer_application_generic_arguments(scope, type_parameters, {
          parameter_templates: [],
          argument_expressions: [],
          result_template: Some(result),
          expected_result: Some(expected),
          effect_template: None,
          expected_effect: None,
          collect_result_first: true,
          failure_label: "contextual provider result",
          loc,
          report_failure: false,
        })
        is Some(inferred) else {
        return None
      }
      (
        parameter_types.map(fn(parameter) {
          parameter.substitute(inferred.substitution)
        }),
        result.substitute(inferred.substitution),
      )
    }
    _ => return None
  }
  guard parameter_types.length() == parameters.length() else { return None }
  guard self.type_matches(expected, result, loc) is Some(true) else {
    return None
  }
  let result = []
  for index in 0..<parameters.length() {
    result.push({ name: parameters[index].name, type_: parameter_types[index] })
  }
  Some(result)
}

///|
fn error_contextual_argument(loc : SourceSpan) -> @desugar.DesugaredExpr {
  ErrorRecovery(loc~)
}
