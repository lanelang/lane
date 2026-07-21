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
      operation_loc=resolved_operation_name_loc(name),
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

///|
fn resolved_operation_name_loc(
  name : @resolve.ResolvedEffectOperationName,
) -> SourceSpan {
  match name {
    Qualified(loc~, ..) | Unqualified(loc~, ..) => loc
  }
}
