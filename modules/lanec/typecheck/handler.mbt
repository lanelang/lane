///|
fn SemanticChecker::synthesize_handler(
  self : SemanticChecker,
  scope : TypeScope,
  body : @desugar.DesugaredExpr,
  handlers : Array[@desugar.DesugaredHandlerWithBlock],
  final_branch : @desugar.DesugaredHandlerFinalBranch,
  loc : SourceSpan,
) -> @types.Type {
  ignore(self.synthesize_expr(scope, body))
  ignore(self.check_handler_tables(scope, handlers))
  ignore(final_branch)
  ignore(loc)
  Error
}

///|
fn SemanticChecker::synthesize_checked_handler(
  self : SemanticChecker,
  scope : TypeScope,
  body : @desugar.DesugaredExpr,
  handlers : Array[@desugar.DesugaredHandlerWithBlock],
  final_branch : @desugar.DesugaredHandlerFinalBranch,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let checked_body = self.synthesize_checked_expr(scope, body).expression
  let checked_handlers = self.check_handler_tables(scope, handlers)
  checked_expression(
    Handler(
      body=checked_body,
      handlers=checked_handlers,
      final_branch={
        binder_symbol: final_branch.binder_symbol,
        binder: final_branch.binder,
        binder_loc: final_branch.binder_loc,
        body: None,
        loc: final_branch.loc,
      },
      type_=Error,
      loc~,
    ),
    Error,
  )
}

///|
fn SemanticChecker::check_handler_tables(
  self : SemanticChecker,
  scope : TypeScope,
  handlers : Array[@desugar.DesugaredHandlerWithBlock],
) -> Array[@checked.CheckedHandlerTable] {
  let checked = []
  let handled_effects = []
  for handler in handlers {
    if self.check_handler_table(scope, handler, handled_effects) is Some(table) {
      handled_effects.push(table.handled_effect)
      checked.push(table)
    }
  }
  checked
}

///|
fn SemanticChecker::check_handler_table(
  self : SemanticChecker,
  scope : TypeScope,
  handler : @desugar.DesugaredHandlerWithBlock,
  handled_effects : Array[@types.Effect],
) -> @checked.CheckedHandlerTable? {
  let checked_arms = []
  let mut handled_effect : @types.Effect? = None
  for arm in handler.arms {
    guard self.operation_call_signature(arm.name, arm.loc) is Some(signature) else {
      continue
    }
    guard signature.effect is Singleton(_, _) else {
      self.diagnostics.push({
        kind: CannotInferExpression("handler effect owner"),
        loc: arm.loc,
      })
      continue
    }
    match handled_effect {
      Some(effect) =>
        if !effect.equals(signature.effect) {
          self.diagnostics.push({ kind: MixedHandlerEffects, loc: arm.loc })
          continue
        }
      None => handled_effect = Some(signature.effect)
    }
    checked_arms.push(self.check_handler_operation_arm(scope, arm, signature))
  }
  guard handled_effect is Some(effect) else { return None }
  for previous in handled_effects {
    if previous.equals(effect) {
      self.diagnostics.push({
        kind: DuplicateHandledEffect(effect),
        loc: handler.loc,
      })
    }
  }
  self.check_handler_operation_coverage(effect, checked_arms, handler.loc)
  Some({ handled_effect: effect, operations: checked_arms, loc: handler.loc })
}

///|
fn SemanticChecker::check_handler_operation_arm(
  self : SemanticChecker,
  scope : TypeScope,
  arm : @desugar.DesugaredHandlerOperationArm,
  signature : OperationCallSignature,
) -> @checked.CheckedHandlerOperationArm {
  let payload_patterns = []
  if signature.payload.length() != arm.payload_patterns.length() {
    self.diagnostics.push({
      kind: PatternArityMismatch(
        name=self.operation_display_name(signature.operation),
        expected=signature.payload.length(),
        actual=arm.payload_patterns.length(),
      ),
      loc: arm.loc,
    })
  }
  let arm_scope = scope.copy()
  let binders : Array[String] = []
  let length = if signature.payload.length() < arm.payload_patterns.length() {
    signature.payload.length()
  } else {
    arm.payload_patterns.length()
  }
  for index in 0..<length {
    payload_patterns.push(
      self.check_pattern(
        arm_scope,
        arm.payload_patterns[index],
        signature.payload[index],
        binders,
      ),
    )
  }
  {
    operation: signature.operation,
    payload_patterns,
    resume_symbol: arm.resume_symbol,
    resume_binder: arm.resume_binder,
    resume_loc: arm.resume_loc,
    body: None,
    loc: arm.loc,
  }
}

///|
fn SemanticChecker::check_handler_operation_coverage(
  self : SemanticChecker,
  handled_effect : @types.Effect,
  arms : Array[@checked.CheckedHandlerOperationArm],
  loc : SourceSpan,
) -> Unit {
  guard handled_effect is Singleton(effect_symbol, _) else { return }
  guard self.declarations.checked_effect(effect_symbol) is Some(effect) else {
    return
  }
  for operation in effect.operations {
    let payload_types = handler_operation_payload_types(
      self, handled_effect, operation,
    )
    let matrix = PatternMatrix::PatternMatrix()
    for arm in arms {
      if arm.operation == operation.symbol &&
        arm.payload_patterns.length() == payload_types.length() {
        if !matrix.is_row_useful(
            self.declarations,
            arm.payload_patterns,
            payload_types,
          ) {
          self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
        }
        matrix.add_row(arm.payload_patterns)
      }
    }
    if !matrix.is_row_exhaustive(self.declarations, payload_types) {
      self.diagnostics.push({
        kind: MissingHandlerOperation(operation.symbol),
        loc,
      })
    }
  }
}

///|
fn handler_operation_payload_types(
  checker : SemanticChecker,
  handled_effect : @types.Effect,
  operation : CheckedEffectOperationDeclaration,
) -> Array[@types.Type] {
  let substitution = checker.operation_owner_substitution(
    handled_effect,
    operation.symbol,
  )
  operation.payload.map(fn(type_) { type_.substitute(substitution) })
}

///|
fn SemanticChecker::operation_display_name(
  self : SemanticChecker,
  operation : OperationSymbolId,
) -> String {
  match self.resolved_source.symbols.operation_metadata(operation) {
    Some(metadata) => metadata.name
    None => "operation#\{operation.index}"
  }
}
