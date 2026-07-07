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
priv struct OperationSelection {
  operation : OperationSymbolId
  declaration : CheckedEffectOperationDeclaration
  owner : EffectSymbolId
  owner_declaration : CheckedEffectDeclaration
}

///|
priv struct OperationInstantiation {
  selection : OperationSelection
  effect : @types.Effect
  payload_templates : Array[@types.Type]
  result_template : @types.Type
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
  // Perform-site operation typing has two substitutions:
  //
  //   Owner[O...]::op[H...](args...)
  //   Sub_owner = [O / owner_params]
  //   Sub_hidden = [H / operation_type_params]
  //
  // Owner arguments come from the selected singleton effect. Operation hidden
  // witnesses are explicit or inferred from payload arguments and expected
  // result type, following the same local generic inference boundary as calls.
  guard self.instantiate_operation_owner(
      scope,
      name,
      generic_witnesses,
      arguments,
      expected_result,
      self.current_expected_effect(),
      loc,
    )
    is Some(instantiation) else {
    return None
  }
  guard self.operation_generic_witnesses(
      scope,
      instantiation.selection.declaration,
      instantiation.payload_templates,
      instantiation.result_template,
      generic_witnesses,
      arguments,
      expected_result,
      loc,
    )
    is Some(hidden) else {
    return None
  }
  Some({
    operation: instantiation.selection.operation,
    generic_witnesses: hidden.generic_witnesses,
    type_binders: [],
    payload: instantiation.payload_templates.map(fn(type_) {
      type_.substitute(hidden.substitution)
    }),
    result: instantiation.result_template.substitute(hidden.substitution),
    effect: instantiation.effect,
  })
}

///|
fn SemanticChecker::handler_operation_signature(
  self : SemanticChecker,
  scope : TypeScope,
  name : @resolve.ResolvedEffectOperationName,
  type_binders : Array[@resolve.ResolvedTypeParameter],
  owner_hint : @types.Effect?,
  loc : SourceSpan,
) -> OperationCallSignature? {
  // Handler arms open operation-level hidden type parameters instead of
  // supplying witnesses:
  //
  //   with Owner::op[X...](payloads..., resume) => body
  //
  // The opened binders must match the operation parameter arity and kind. They
  // substitute the operation hidden parameters in payload/result types while
  // remaining abstract inside the arm scope.
  guard self.instantiate_operation_owner(
      scope,
      name,
      [],
      [],
      None,
      owner_hint,
      loc,
    )
    is Some(instantiation) else {
    return None
  }
  let checked_binders = []
  for index in 0..<type_binders.length() {
    let binder = type_binders[index]
    if index < instantiation.selection.declaration.type_parameters.length() &&
      binder.kind is None {
      checked_binders.push(
        checked_type_parameter_with_kind(
          binder,
          instantiation.selection.declaration.type_parameters[index].kind,
        ),
      )
    } else {
      checked_binders.push(checked_type_parameter(binder))
    }
  }
  if checked_binders.length() !=
    instantiation.selection.declaration.type_parameters.length() {
    self.report_application_arity("effect operation type binders", loc)
    return None
  }
  let hidden_substitution = @types.TypeSubstitution::TypeSubstitution()
  for index in 0..<checked_binders.length() {
    let expected = instantiation.selection.declaration.type_parameters[index].kind
    let actual = checked_binders[index].kind
    if actual != expected {
      self.diagnostics.push({ kind: KindMismatch(expected~, actual~), loc })
    }
    if expected == Effect {
      hidden_substitution.insert_effect(
        instantiation.selection.declaration.type_parameters[index].id,
        Parameter(checked_binders[index].id),
      )
    } else {
      hidden_substitution.insert(
        instantiation.selection.declaration.type_parameters[index].id,
        Parameter(checked_binders[index].id),
      )
    }
  }
  Some({
    operation: instantiation.selection.operation,
    generic_witnesses: [],
    type_binders: checked_binders,
    payload: instantiation.payload_templates.map(fn(type_) {
      type_.substitute(hidden_substitution)
    }),
    result: instantiation.result_template.substitute(hidden_substitution),
    effect: instantiation.effect,
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
  // Operation witness rule:
  //
  //   Gamma |- arg_i => Actual_i
  //   collect(P_i, Actual_i)
  //   collect(R, Expected)
  //   all operation type parameters are bound
  //   ---------------------------------------
  //   hidden witnesses and substitution
  //
  // Empty written witnesses mean "infer all"; a non-empty list must be complete.
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
          {
            parameter_templates: payload_templates,
            argument_expressions: arguments,
            result_template: Some(result_template),
            expected_result,
            effect_template: None,
            expected_effect: None,
            collect_result_first: false,
            failure_label: "effect operation generic arguments",
            loc,
            report_failure: true,
          },
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
fn SemanticChecker::instantiate_operation_owner(
  self : SemanticChecker,
  scope : TypeScope,
  name : @resolve.ResolvedEffectOperationName,
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  owner_hint : @types.Effect?,
  loc : SourceSpan,
) -> OperationInstantiation? {
  guard self.select_operation(name, loc) is Some(selection) else { return None }
  guard self.infer_operation_owner(
      scope, name, selection, generic_witnesses, arguments, expected_result, owner_hint,
      loc,
    )
    is Some(effect) else {
    return None
  }
  let owner_substitution = operation_owner_substitution(selection, effect)
  Some({
    selection,
    effect,
    payload_templates: selection.declaration.payload.map(fn(type_) {
      type_.substitute(owner_substitution)
    }),
    result_template: selection.declaration.result.substitute(owner_substitution),
  })
}

///|
fn SemanticChecker::select_operation(
  self : SemanticChecker,
  name : @resolve.ResolvedEffectOperationName,
  loc : SourceSpan,
) -> OperationSelection? {
  let reference = match name {
    Qualified(reference~, ..) | Unqualified(reference~, ..) => reference
  }
  let operation = match reference {
    Symbol(symbol) => symbol
    Unresolved(name) => {
      self.diagnostics.push({ kind: UnresolvedValue(name), loc })
      return None
    }
    Ambiguous(name~, ..) => {
      self.report_internal_typecheck_failure(
        "ambiguous effect operation " + name,
        loc,
      )
      return None
    }
  }
  guard self.declarations.checked_operation(operation) is Some(declaration) else {
    self.report_internal_typecheck_failure("effect operation", loc)
    return None
  }
  guard self.resolved_source.symbols.operation_metadata(operation)
    is Some(metadata) else {
    self.report_internal_typecheck_failure("effect operation owner", loc)
    return None
  }
  guard self.declarations.checked_effect(metadata.owner)
    is Some(owner_declaration) else {
    self.report_internal_typecheck_failure("effect operation owner", loc)
    return None
  }
  Some({ operation, declaration, owner: metadata.owner, owner_declaration })
}

///|
fn SemanticChecker::infer_operation_owner(
  self : SemanticChecker,
  scope : TypeScope,
  name : @resolve.ResolvedEffectOperationName,
  selection : OperationSelection,
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  owner_hint : @types.Effect?,
  loc : SourceSpan,
) -> @types.Effect? {
  match name {
    Qualified(owner~, ..) => Some(self.check_effect(owner))
    Unqualified(..) => {
      if selection.owner_declaration.type_parameters.is_empty() {
        return Some(Singleton(selection.owner, []))
      }
      self.infer_operation_owner_from_arguments(
        scope, selection, generic_witnesses, arguments, expected_result, owner_hint,
        loc,
      )
    }
  }
}

///|
fn SemanticChecker::infer_operation_owner_from_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  selection : OperationSelection,
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
  arguments : Array[@desugar.DesugaredExpr],
  expected_result : @types.Type?,
  expected_effect : @types.Effect?,
  loc : SourceSpan,
) -> @types.Effect? {
  let hidden_substitution = self.explicit_operation_witness_substitution(
    scope,
    selection.declaration,
    generic_witnesses,
  )
  let payload_templates = selection.declaration.payload.map(fn(type_) {
    type_.substitute(hidden_substitution)
  })
  let result_template = selection.declaration.result.substitute(
    hidden_substitution,
  )
  guard self.infer_application_generic_arguments(
      scope,
      selection.owner_declaration.type_parameters,
      {
        parameter_templates: payload_templates,
        argument_expressions: arguments,
        result_template: Some(result_template),
        expected_result,
        effect_template: Some(operation_owner_effect_template(selection)),
        expected_effect,
        collect_result_first: false,
        failure_label: "effect operation owner arguments",
        loc,
        report_failure: true,
      },
    )
    is Some(inferred) else {
    return None
  }
  Some(Singleton(selection.owner, inferred.generic_arguments))
}

///|
fn operation_owner_effect_template(
  selection : OperationSelection,
) -> @types.Effect {
  Singleton(
    selection.owner,
    selection.owner_declaration.type_parameters.map(fn(parameter) {
      parameter.generic_argument()
    }),
  )
}

///|
fn operation_owner_substitution(
  selection : OperationSelection,
  effect : @types.Effect,
) -> @types.TypeSubstitution {
  if effect is Singleton(symbol, arguments) && symbol == selection.owner {
    variant_type_substitution(
      selection.owner_declaration.type_parameters,
      arguments,
    )
  } else {
    empty_type_substitution()
  }
}

///|
fn SemanticChecker::explicit_operation_witness_substitution(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : CheckedEffectOperationDeclaration,
  generic_witnesses : Array[@resolve.ResolvedGenericArgument],
) -> @types.TypeSubstitution {
  if generic_witnesses.length() != declaration.type_parameters.length() {
    return empty_type_substitution()
  }
  let checked = check_resolved_generic_arguments(
    self.resolved_source,
    self.diagnostics,
    scope,
    declaration.type_parameters,
    generic_witnesses,
  )
  variant_generic_argument_substitution(declaration.type_parameters, checked)
}

///|
fn SemanticChecker::operation_owner_substitution(
  self : SemanticChecker,
  effect : @types.Effect,
  operation : OperationSymbolId,
) -> @types.TypeSubstitution {
  guard self.resolved_source.symbols.operation_metadata(operation)
    is Some(metadata) else {
    return empty_type_substitution()
  }
  guard self.declarations.checked_effect(metadata.owner) is Some(declaration) else {
    return empty_type_substitution()
  }
  if effect is Singleton(symbol, arguments) && symbol == metadata.owner {
    variant_type_substitution(declaration.type_parameters, arguments)
  } else {
    empty_type_substitution()
  }
}

///|
fn empty_type_substitution() -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
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
  // Non-checked expression path used by ordinary type checking:
  //
  //   Gamma |- Owner::op[H...](arg_i...) <= Expected?
  //
  // Payloads check against the instantiated operation payload types. The
  // operation's latent effect is returned in the signature for callers that
  // build checked expressions.
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
  // Checked perform expression:
  //
  //   Gamma |- arg_i <= P_i ~~> checked_arg_i ! E_i
  //   -------------------------------------------------------
  //   Gamma |- perform op(arg_i...) => R ! {OwnerEffect, E_i...}
  //
  // The checked node stores only the operation's own effect as `effect`; the
  // synthesis result includes payload-evaluation effects as well.
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
