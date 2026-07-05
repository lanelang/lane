///|
priv struct OperationCallSignature {
  operation : OperationSymbolId
  generic_witnesses : Array[@types.GenericArgument]
  type_binders : Array[@types.TypeParameter]
  payload : Array[@types.Type]
  result : @types.Type
  effect : @types.Effect
}

///|
fn SemanticChecker::operation_call_signature(
  self : SemanticChecker,
  scope : TypeScope,
  name : @resolve.ResolvedEffectOperationName,
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
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
    self.report_internal_typecheck_failure("effect operation", loc)
    return None
  }
  guard self.operation_owner_effect(name, operation, loc) is Some(effect) else {
    return None
  }
  let owner_substitution = self.operation_owner_substitution(effect, operation)
  let payload_templates = declaration.payload.map(fn(type_) {
    type_.substitute(owner_substitution)
  })
  let result_template = declaration.result.substitute(owner_substitution)
  guard self.operation_generic_witnesses(
      scope, declaration, payload_templates, result_template, generic_witnesses,
      arguments, expected_result, loc,
    )
    is Some(hidden) else {
    return None
  }
  Some({
    operation,
    generic_witnesses: hidden.generic_witnesses,
    type_binders: [],
    payload: payload_templates.map(fn(type_) {
      type_.substitute(hidden.substitution)
    }),
    result: result_template.substitute(hidden.substitution),
    effect,
  })
}

///|
fn SemanticChecker::handler_operation_signature(
  self : SemanticChecker,
  name : @resolve.ResolvedEffectOperationName,
  type_binders : Array[@resolve.ResolvedTypeParameter],
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
    self.report_internal_typecheck_failure("effect operation", loc)
    return None
  }
  guard self.operation_owner_effect(name, operation, loc) is Some(effect) else {
    return None
  }
  let owner_substitution = self.operation_owner_substitution(effect, operation)
  let checked_binders = []
  for index in 0..<type_binders.length() {
    let binder = type_binders[index]
    if index < declaration.type_parameters.length() && binder.kind is None {
      checked_binders.push(
        checked_type_parameter_with_kind(
          binder,
          declaration.type_parameters[index].kind,
        ),
      )
    } else {
      checked_binders.push(checked_type_parameter(binder))
    }
  }
  if checked_binders.length() != declaration.type_parameters.length() {
    self.report_application_arity("effect operation type binders", loc)
    return None
  }
  let hidden_substitution = @types.TypeSubstitution::TypeSubstitution()
  for index in 0..<checked_binders.length() {
    let expected = declaration.type_parameters[index].kind
    let actual = checked_binders[index].kind
    if actual != expected {
      self.diagnostics.push({ kind: KindMismatch(expected~, actual~), loc })
    }
    if expected == Effect {
      hidden_substitution.insert_effect(
        declaration.type_parameters[index].id,
        Parameter(checked_binders[index].id),
      )
    } else {
      hidden_substitution.insert(
        declaration.type_parameters[index].id,
        Parameter(checked_binders[index].id),
      )
    }
  }
  Some({
    operation,
    generic_witnesses: [],
    type_binders: checked_binders,
    payload: declaration.payload.map(fn(type_) {
      type_.substitute(owner_substitution).substitute(hidden_substitution)
    }),
    result: declaration.result
    .substitute(owner_substitution)
    .substitute(hidden_substitution),
    effect,
  })
}

///|
priv struct OperationGenericWitnesses {
  generic_witnesses : Array[@types.GenericArgument]
  substitution : @types.TypeSubstitution
}

///|
fn SemanticChecker::operation_generic_witnesses(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : CheckedEffectOperationDeclaration,
  payload_templates : Array[@types.Type],
  result_template : @types.Type,
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> OperationGenericWitnesses? {
  if declaration.type_parameters.length() != generic_witnesses.length() &&
    !generic_witnesses.is_empty() {
    self.report_application_arity("effect operation generic arguments", loc)
    return None
  }
  let checked = if generic_witnesses.is_empty() {
    if declaration.type_parameters.is_empty() {
      []
    } else {
      guard self.infer_application_generic_arguments(
          scope,
          declaration.type_parameters,
          payload_templates,
          arguments,
          Some(result_template),
          expected_result,
          false,
          "effect operation generic arguments",
          loc,
          true,
        )
        is Some(inferred) else {
        return None
      }
      inferred.generic_arguments
    }
  } else {
    check_resolved_generic_arguments(
      self.resolved_source,
      self.diagnostics,
      scope,
      declaration.type_parameters,
      generic_witnesses,
    )
  }
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for index in 0..<checked.length().min(declaration.type_parameters.length()) {
    substitution.insert_argument(
      declaration.type_parameters[index].id,
      checked[index],
    )
  }
  Some({ generic_witnesses: checked, substitution })
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
      self.report_internal_typecheck_failure(
        "ambiguous effect operation " + name,
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
        self.report_internal_typecheck_failure("effect operation owner", loc)
        return None
      }
      guard self.declarations.checked_effect(metadata.owner) is Some(effect) else {
        self.report_internal_typecheck_failure("effect operation owner", loc)
        return None
      }
      if !effect.type_parameters.is_empty() {
        self.report_internal_typecheck_failure("effect operation owner", loc)
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
        substitution.insert_argument(
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
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> OperationCallSignature {
  guard self.operation_call_signature(
      scope, name, generic_witnesses, arguments, expected_result, loc,
    )
    is Some(signature) else {
    return {
      operation: { index: -1 },
      generic_witnesses: [],
      type_binders: [],
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
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard self.operation_call_signature(
      scope, name, generic_witnesses, arguments, expected_result, loc,
    )
    is Some(signature) else {
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
      generic_witnesses=signature.generic_witnesses,
      arguments=checked_arguments,
      effect=signature.effect,
      type_=signature.result,
      loc~,
    ),
    signature.result,
    effect,
  )
}
