///|
priv struct OperationCallSignature {
  operation : OperationSymbolId
  payload : Array[@types.Type]
  result : @types.Type
  effect : @types.Effect
}

///|
fn SemanticChecker::operation_call_signature(
  self : SemanticChecker,
  name : @resolve.ResolvedEffectOperationName,
  loc : SourceSpan,
) -> OperationCallSignature? {
  let reference = match name {
    Qualified(reference~, ..)
    | Shorthand(reference~, ..)
    | Unqualified(reference~, ..) => reference
  }
  guard self.operation_symbol(reference, loc) is Some(operation) else {
    return None
  }
  guard self.declarations.checked_operation(operation) is Some(declaration) else {
    self.report_application_inference_failure("effect operation", Generic, loc)
    return None
  }
  guard self.operation_owner_effect(name, operation, loc) is Some(effect) else {
    return None
  }
  let substitution = self.operation_owner_substitution(effect, operation)
  Some({
    operation,
    payload: declaration.payload.map(fn(type_) {
      type_.substitute(substitution)
    }),
    result: declaration.result.substitute(substitution),
    effect,
  })
}

///|
fn SemanticChecker::operation_symbol(
  self : SemanticChecker,
  reference : @resolve.ResolvedOperationReference,
  loc : SourceSpan,
) -> OperationSymbolId? {
  match reference {
    Symbol(symbol) => Some(symbol)
    Unresolved(name) => {
      self.diagnostics.push({ kind: UnresolvedValue(name), loc })
      None
    }
    Ambiguous(name~, ..) => {
      self.report_application_inference_failure(
        "ambiguous effect operation " + name,
        Generic,
        loc,
      )
      None
    }
  }
}

///|
fn SemanticChecker::operation_owner_effect(
  self : SemanticChecker,
  name : @resolve.ResolvedEffectOperationName,
  operation : OperationSymbolId,
  loc : SourceSpan,
) -> @types.Effect? {
  match name {
    Qualified(owner~, ..) => Some(self.check_effect(owner))
    Shorthand(..) | Unqualified(..) => {
      guard self.resolved_source.symbols.operation_metadata(operation)
        is Some(metadata) else {
        self.report_application_inference_failure(
          "effect operation owner",
          Generic,
          loc,
        )
        return None
      }
      guard self.declarations.checked_effect(metadata.owner) is Some(effect) else {
        self.report_application_inference_failure(
          "effect operation owner",
          Generic,
          loc,
        )
        return None
      }
      if !effect.type_parameters.is_empty() {
        self.report_application_inference_failure(
          "effect operation owner",
          Generic,
          loc,
        )
        return None
      }
      Some(Singleton(metadata.owner, []))
    }
  }
}

///|
fn SemanticChecker::operation_owner_substitution(
  self : SemanticChecker,
  effect : @types.Effect,
  operation : OperationSymbolId,
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  guard self.resolved_source.symbols.operation_metadata(operation)
    is Some(metadata) else {
    return substitution
  }
  guard self.declarations.checked_effect(metadata.owner) is Some(declaration) else {
    return substitution
  }
  if effect is Singleton(symbol, arguments) && symbol == metadata.owner {
    for index in 0..<arguments.length() {
      if index < declaration.type_parameters.length() {
        substitution.insert(
          declaration.type_parameters[index].id,
          arguments[index],
        )
      }
    }
  }
  substitution
}

///|
fn SemanticChecker::check_operation_call(
  self : SemanticChecker,
  scope : TypeScope,
  name : @resolve.ResolvedEffectOperationName,
  arguments : Array[@desugar.DesugaredExpr],
  loc : SourceSpan,
) -> OperationCallSignature {
  guard self.operation_call_signature(name, loc) is Some(signature) else {
    return {
      operation: { index: -1 },
      payload: [],
      result: Error,
      effect: Empty,
    }
  }
  if signature.payload.length() != arguments.length() {
    self.report_application_arity("effect operation arity", loc)
    return signature
  }
  for index in 0..<arguments.length() {
    self.check_expr(scope, arguments[index], signature.payload[index])
  }
  signature
}

///|
fn SemanticChecker::synthesize_checked_operation_call(
  self : SemanticChecker,
  scope : TypeScope,
  name : @resolve.ResolvedEffectOperationName,
  arguments : Array[@desugar.DesugaredExpr],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard self.operation_call_signature(name, loc) is Some(signature) else {
    return checked_expression_none_reported(Error)
  }
  if signature.payload.length() != arguments.length() {
    self.report_application_arity("effect operation arity", loc)
    return checked_expression_none_reported(signature.result)
  }
  let checked_arguments = []
  let effects = [signature.effect]
  let mut complete = true
  for index in 0..<arguments.length() {
    let checked = self.check_checked_expr(
      scope,
      arguments[index],
      signature.payload[index],
    )
    effects.push(checked.effect)
    match
      self.require_checked_expression(
        checked,
        arguments[index].loc(),
        "effect operation argument",
      ) {
      Some(argument) => checked_arguments.push(argument)
      None => complete = false
    }
  }
  if !complete {
    return checked_expression_none_reported(signature.result)
  }
  let effect = effect_union(effects)
  checked_expression_with_effect(
    OperationCall(
      operation=signature.operation,
      arguments=checked_arguments,
      effect=signature.effect,
      type_=signature.result,
      loc~,
    ),
    signature.result,
    effect,
  )
}
