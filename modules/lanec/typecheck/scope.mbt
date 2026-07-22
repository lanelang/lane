///|
priv struct ValueTypeBinding {
  symbol : ValueSymbolId
  type_ : @types.Type
  parameters : Array[@checked.CheckedValueParameter]?
}

///|
priv struct ContextualOffer {
  symbol : ValueSymbolId
  name : String
  expression : @desugar.DesugaredExpr
  type_ : @types.Type
  source_id : String?
  loc : SourceSpan
}

///|
priv struct ContextualOfferScope {
  visible_by_name : Map[String, Array[ContextualOffer]]
}

///|
priv struct TypeParameterKindBinding {
  symbol : TypeParameterId
  kind : @types.Kind
}

///|
priv struct TypeScope {
  values : Array[ValueTypeBinding]
  offers : ContextualOfferScope
  type_parameters : Array[TypeParameterKindBinding]
  provisional_effect_parameters : Array[TypeParameterId]
  expected_effect : @types.Effect?
}

///|
fn SemanticChecker::root_scope(self : SemanticChecker) -> TypeScope {
  {
    values: self.value_types.copy(),
    offers: self.offers.copy(),
    type_parameters: [],
    provisional_effect_parameters: [],
    expected_effect: None,
  }
}

///|
fn SemanticChecker::ordered_root_scope(self : SemanticChecker) -> TypeScope {
  {
    values: self.ordered_value_types.copy(),
    offers: self.ordered_offers.copy(),
    type_parameters: [],
    provisional_effect_parameters: [],
    expected_effect: None,
  }
}

///|
fn TypeScope::bind(
  self : TypeScope,
  symbol : ValueSymbolId,
  name : String,
  type_ : @types.Type,
) -> Unit {
  self.values.push({ symbol, type_, parameters: None })
  self.offers.hide(name)
}

///|
fn TypeScope::bind_function(
  self : TypeScope,
  symbol : ValueSymbolId,
  name : String,
  type_ : @types.Type,
  parameters : Array[@checked.CheckedValueParameter],
) -> Unit {
  self.values.push({ symbol, type_, parameters: Some(parameters) })
  self.offers.hide(name)
}

///|
fn TypeScope::lookup(self : TypeScope, symbol : ValueSymbolId) -> @types.Type? {
  for index = self.values.length() - 1; index >= 0; index = index - 1 {
    let binding = self.values[index]
    if binding.symbol == symbol {
      return Some(binding.type_)
    }
  }
  None
}

///|
fn TypeScope::lookup_function_parameters(
  self : TypeScope,
  symbol : ValueSymbolId,
) -> Array[@checked.CheckedValueParameter]? {
  for index = self.values.length() - 1; index >= 0; index = index - 1 {
    let binding = self.values[index]
    if binding.symbol == symbol {
      return binding.parameters
    }
  }
  None
}

///|
fn TypeScope::copy(self : TypeScope) -> TypeScope {
  {
    values: self.values.copy(),
    offers: self.offers.copy(),
    type_parameters: self.type_parameters.copy(),
    provisional_effect_parameters: self.provisional_effect_parameters.copy(),
    expected_effect: self.expected_effect,
  }
}

///|
fn TypeScope::with_expected_effect(
  self : TypeScope,
  effect : @types.Effect,
) -> TypeScope {
  {
    values: self.values.copy(),
    offers: self.offers.copy(),
    type_parameters: self.type_parameters.copy(),
    provisional_effect_parameters: self.provisional_effect_parameters.copy(),
    expected_effect: Some(effect),
  }
}

///|
fn TypeScope::without_expected_effect(self : TypeScope) -> TypeScope {
  {
    values: self.values.copy(),
    offers: self.offers.copy(),
    type_parameters: self.type_parameters.copy(),
    provisional_effect_parameters: self.provisional_effect_parameters.copy(),
    expected_effect: None,
  }
}

///|
fn TypeScope::bind_type_parameter_kind(
  self : TypeScope,
  symbol : TypeParameterId,
  kind : @types.Kind,
) -> Unit {
  self.type_parameters.push({ symbol, kind })
}

///|
fn TypeScope::bind_provisional_effect_parameter(
  self : TypeScope,
  symbol : TypeParameterId,
) -> Unit {
  self.bind_type_parameter_kind(symbol, Effect)
  self.provisional_effect_parameters.push(symbol)
}

///|
fn TypeScope::bind_resolved_type_parameter_kinds(
  self : TypeScope,
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Unit {
  for parameter in parameters {
    self.bind_type_parameter_kind(
      parameter.symbol,
      resolve_type_parameter_kind(parameter),
    )
  }
}

///|
fn TypeScope::with_type_parameter_kinds(
  self : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
) -> TypeScope {
  let scope = self.copy()
  scope.bind_resolved_type_parameter_kinds(type_parameters)
  scope
}

///|
fn SemanticChecker::function_body_scope(
  self : SemanticChecker,
  parent : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@checked.CheckedValueParameter],
) -> TypeScope {
  let scope = parent.with_type_parameter_kinds(type_parameters)
  for parameter in parameters {
    scope.bind(parameter.symbol, parameter.name, parameter.type_)
    if parameter.is_offered {
      self.bind_offer_symbol(
        scope,
        parameter.symbol,
        Some(parameter.name),
        parameter.type_,
        parameter.loc,
      )
    }
  }
  scope
}

///|
fn TypeScope::type_parameter_kind(
  self : TypeScope,
  symbol : TypeParameterId,
) -> @types.Kind? {
  for index = self.type_parameters.length() - 1; index >= 0; index = index - 1 {
    let binding = self.type_parameters[index]
    if binding.symbol == symbol {
      return Some(binding.kind)
    }
  }
  None
}

///|
fn SemanticChecker::offer_symbol(
  self : SemanticChecker,
  offers : ContextualOfferScope,
  symbol : ValueSymbolId,
  name : String?,
  type_ : @types.Type,
  loc : SourceSpan,
) -> Unit {
  guard require_contextual_offer_name(self.diagnostics, name, loc) is Some(name) else {
    return
  }
  offer_symbol_with_source_id(offers, symbol, name, type_, None, loc)
}

///|
fn offer_symbol_with_source_id(
  offers : ContextualOfferScope,
  symbol : ValueSymbolId,
  name : String,
  type_ : @types.Type,
  source_id : String?,
  loc : SourceSpan,
) -> Unit {
  offers.add_visible(contextual_offer(symbol, name, type_, source_id, loc))
}

///|
fn SemanticChecker::bind_offer_symbol(
  self : SemanticChecker,
  scope : TypeScope,
  symbol : ValueSymbolId,
  name : String?,
  type_ : @types.Type,
  loc : SourceSpan,
) -> Unit {
  guard require_contextual_offer_name(self.diagnostics, name, loc) is Some(name) else {
    return
  }
  scope.offers.bind(contextual_offer(symbol, name, type_, None, loc))
}

///|
fn require_contextual_offer_name(
  diagnostics : Array[TypeCheckDiagnostic],
  name : String?,
  loc : SourceSpan,
) -> String? {
  match name {
    Some(name) => Some(name)
    None => {
      diagnostics.push({
        kind: InternalTypecheckFailure(
          label="offered binding is missing its declaration name",
        ),
        loc,
      })
      None
    }
  }
}

///|
fn contextual_offer(
  symbol : ValueSymbolId,
  name : String,
  type_ : @types.Type,
  source_id : String?,
  loc : SourceSpan,
) -> ContextualOffer {
  let expression = @desugar.DesugaredExpr::Var(
    name~,
    reference=Symbol(symbol),
    loc~,
  )
  { symbol, name, expression, type_, source_id, loc }
}

///|
fn contextual_offer_diagnostic_candidate(
  offer : ContextualOffer,
) -> ContextualOfferDiagnosticCandidate {
  {
    name: offer.name,
    type_: offer.type_,
    source_id: offer.source_id,
    loc: offer.loc,
  }
}

///|
fn ContextualOfferScope::ContextualOfferScope() -> ContextualOfferScope {
  { visible_by_name: Map([]) }
}

///|
fn ContextualOfferScope::copy(
  self : ContextualOfferScope,
) -> ContextualOfferScope {
  { visible_by_name: self.visible_by_name.copy() }
}

///|
fn ContextualOfferScope::hide(
  self : ContextualOfferScope,
  name : String,
) -> Unit {
  self.visible_by_name[name] = []
}

///|
fn ContextualOfferScope::add_visible(
  self : ContextualOfferScope,
  offer : ContextualOffer,
) -> Unit {
  let visible = match self.visible_by_name.get(offer.name) {
    Some(offers) => offers.copy()
    None => []
  }
  if !visible.any(fn(current) { current.symbol == offer.symbol }) {
    visible.push(offer)
    self.visible_by_name[offer.name] = visible
  }
}

///|
fn ContextualOfferScope::bind(
  self : ContextualOfferScope,
  offer : ContextualOffer,
) -> Unit {
  self.visible_by_name[offer.name] = [offer]
}

///|
fn ContextualOfferScope::each_visible(
  self : ContextualOfferScope,
  consume : (ContextualOffer) -> Unit,
) -> Unit {
  for _, offers in self.visible_by_name {
    for offer in offers {
      consume(offer)
    }
  }
}
