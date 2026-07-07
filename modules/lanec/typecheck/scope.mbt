///|
priv struct ValueTypeBinding {
  symbol : ValueSymbolId
  type_ : @types.Type
  parameters : Array[@checked.CheckedValueParameter]?
}

///|
priv struct ContextualOffer {
  root : ValueSymbolId
  path : Array[FieldSymbolId]
  expression : @desugar.DesugaredExpr
  type_ : @types.Type
  source_id : String?
  loc : SourceSpan
}

///|
priv struct TypeParameterKindBinding {
  symbol : TypeParameterId
  kind : @types.Kind
}

///|
priv struct TypeScope {
  values : Array[ValueTypeBinding]
  offers : Array[ContextualOffer]
  type_parameters : Array[TypeParameterKindBinding]
  expected_effect : @types.Effect?
}

///|
fn SemanticChecker::root_scope(self : SemanticChecker) -> TypeScope {
  {
    values: self.value_types.copy(),
    offers: self.offers.copy(),
    type_parameters: [],
    expected_effect: None,
  }
}

///|
fn SemanticChecker::ordered_root_scope(self : SemanticChecker) -> TypeScope {
  {
    values: self.ordered_value_types.copy(),
    offers: self.ordered_offers.copy(),
    type_parameters: [],
    expected_effect: None,
  }
}

///|
fn TypeScope::bind(
  self : TypeScope,
  symbol : ValueSymbolId,
  type_ : @types.Type,
) -> Unit {
  self.values.push({ symbol, type_, parameters: None })
}

///|
fn TypeScope::bind_function(
  self : TypeScope,
  symbol : ValueSymbolId,
  type_ : @types.Type,
  parameters : Array[@checked.CheckedValueParameter],
) -> Unit {
  self.values.push({ symbol, type_, parameters: Some(parameters) })
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
    expected_effect: Some(effect),
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
    scope.bind(parameter.symbol, parameter.type_)
    if parameter.is_offered {
      self.offer_symbol(
        scope.offers,
        parameter.symbol,
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
  offers : Array[ContextualOffer],
  symbol : ValueSymbolId,
  type_ : @types.Type,
  loc : SourceSpan,
) -> Unit {
  self.offer_symbol_with_source_id(offers, symbol, type_, None, loc)
}

///|
fn SemanticChecker::offer_symbol_with_source_id(
  self : SemanticChecker,
  offers : Array[ContextualOffer],
  symbol : ValueSymbolId,
  type_ : @types.Type,
  source_id : String?,
  loc : SourceSpan,
) -> Unit {
  let name = match self.source.symbols.value_metadata(symbol) {
    Some(metadata) => metadata.name
    None => "<unknown>"
  }
  let expression = @desugar.DesugaredExpr::Var(
    name~,
    reference=Symbol(symbol),
    loc~,
  )
  self.offer_expression(offers, symbol, [], expression, type_, source_id, loc)
}

///|
fn SemanticChecker::offer_expression(
  self : SemanticChecker,
  offers : Array[ContextualOffer],
  root : ValueSymbolId,
  path : Array[FieldSymbolId],
  expression : @desugar.DesugaredExpr,
  type_ : @types.Type,
  source_id : String?,
  loc : SourceSpan,
) -> Unit {
  if !contains_contextual_offer(offers, root, path) {
    offers.push({ root, path, expression, type_, source_id, loc })
  }
  self.offer_forwarding_fields(
    offers, root, path, expression, type_, source_id, loc,
  )
}

///|
fn SemanticChecker::contextual_offer_diagnostic_candidate(
  self : SemanticChecker,
  offer : ContextualOffer,
) -> ContextualOfferDiagnosticCandidate {
  {
    name: self.contextual_offer_name(offer),
    type_: offer.type_,
    source_id: offer.source_id,
    loc: offer.loc,
  }
}

///|
fn SemanticChecker::contextual_offer_name(
  self : SemanticChecker,
  offer : ContextualOffer,
) -> String {
  let root = match self.source.symbols.value_metadata(offer.root) {
    Some(metadata) => metadata.name
    None => "<unknown>"
  }
  if offer.path.is_empty() {
    return root
  }
  let parts = [root]
  for field in offer.path {
    let name = match self.source.symbols.field_metadata(field) {
      Some(metadata) => metadata.name
      None => "<unknown>"
    }
    parts.push(name)
  }
  parts.join(".")
}

///|
fn contains_contextual_offer(
  offers : Array[ContextualOffer],
  root : ValueSymbolId,
  path : Array[FieldSymbolId],
) -> Bool {
  offers.any(fn(offer) {
    offer.root == root && field_path_equals(offer.path, path)
  })
}

///|
fn field_path_equals(
  left : Array[FieldSymbolId],
  right : Array[FieldSymbolId],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn SemanticChecker::offer_forwarding_fields(
  self : SemanticChecker,
  offers : Array[ContextualOffer],
  root : ValueSymbolId,
  path : Array[FieldSymbolId],
  expression : @desugar.DesugaredExpr,
  type_ : @types.Type,
  source_id : String?,
  loc : SourceSpan,
) -> Unit {
  guard type_.decompose_nominal() is Some((owner, arguments)) else { return }
  guard self.declarations.checked_struct(owner) is Some(declaration) else {
    return
  }
  let substitution = declaration.nominal_substitution(arguments)
  for field in declaration.fields {
    if field.is_offered && !path.contains(field.symbol) {
      let field_type = field.type_.substitute(substitution)
      let field_path = path.copy()
      field_path.push(field.symbol)
      let field_expr = @desugar.DesugaredExpr::Field(
        base=expression,
        name=field.name,
        reference=Symbol(field.symbol),
        loc~,
      )
      self.offer_expression(
        offers, root, field_path, field_expr, field_type, source_id, loc,
      )
    }
  }
}
