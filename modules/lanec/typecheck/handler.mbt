///|
priv struct HandlerTableCheck {
  checked : @checked.CheckedHandlerTable
  operations : Array[HandlerOperationCheck]
}

///|
priv struct HandlerOperationCheck {
  source : @desugar.DesugaredHandlerOperationArm
  signature : OperationCallSignature
  checked : @checked.CheckedHandlerOperationArm
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
  // Handler typing:
  //
  //   Gamma |- body => BodyT ! BodyEff
  //   Gamma, value : BodyT |- final => ResultT ! FinalEff
  //   ResidualSeed = (BodyEff - handled_effects) union FinalEff
  //
  // Operation arms need `ResultT` and the final residual effect to type
  // `resume : OperationResult -> ResultT ! Residual`. Since arm bodies
  // contribute to `Residual`, we first run a silent local pass using the seed,
  // compute the final residual, then check arms once with the final resume type.
  let checked_body = self.synthesize_checked_expr(scope, body)
  let checked_tables = self.check_handler_table_data(
    scope,
    handlers,
    checked_body.effect,
  )
  let handled_effects = checked_tables.map(fn(table) {
    table.checked.handled_effect
  })
  let residual_body_effect = self.handler_residual_effect(
    checked_body.effect,
    handled_effects,
    loc,
  )
  let final_scope = scope.copy()
  final_scope.bind(final_branch.binder_symbol, checked_body.type_)
  let checked_final_body = self.synthesize_checked_expr(
    final_scope,
    final_branch.body,
  )
  let result_type = checked_final_body.type_
  let residual_seed = handler_effect_union([
    residual_body_effect,
    checked_final_body.effect,
  ])
  let preliminary_arm_effects = []
  for table in checked_tables {
    for operation in table.operations {
      let arm_scope = handler_operation_scope(
        scope,
        operation.checked,
        operation.signature,
        result_type,
        residual_seed,
      )
      preliminary_arm_effects.push(
        self.preliminary_handler_arm_effect(
          arm_scope,
          operation.source.body,
          result_type,
        ),
      )
    }
  }
  let residual_effect = handler_effect_union(
    [residual_seed] + preliminary_arm_effects,
  )
  let mut complete = checked_body.expression is Some(_) &&
    checked_final_body.expression is Some(_)
  let checked_handler_tables : Array[@checked.CheckedHandlerTable] = []
  for table in checked_tables {
    let checked_operations : Array[@checked.CheckedHandlerOperationArm] = []
    for operation in table.operations {
      let arm_scope = handler_operation_scope(
        scope,
        operation.checked,
        operation.signature,
        result_type,
        residual_effect,
      )
      let checked_arm_body = self.check_checked_expr(
        arm_scope,
        operation.source.body,
        result_type,
      )
      match
        self.require_checked_expression(
          checked_arm_body,
          operation.source.body.loc(),
          "handler operation arm",
        ) {
        Some(body) =>
          checked_operations.push({
            operation: operation.checked.operation,
            type_binders: operation.checked.type_binders,
            payload_types: operation.checked.payload_types,
            payload_patterns: operation.checked.payload_patterns,
            resume_symbol: operation.checked.resume_symbol,
            resume_type: handler_resume_type(
              operation.signature,
              result_type,
              residual_effect,
            ),
            resume_binder: operation.checked.resume_binder,
            resume_loc: operation.checked.resume_loc,
            body: Some(body),
            loc: operation.checked.loc,
          })
        None => complete = false
      }
    }
    checked_handler_tables.push({
      handled_effect: table.checked.handled_effect,
      operations: checked_operations,
      loc: table.checked.loc,
    })
  }
  let final_body = match checked_final_body.expression {
    Some(body) => Some(body)
    None => {
      ignore(
        self.require_checked_expression(
          checked_final_body,
          final_branch.body.loc(),
          "handler final branch",
        ),
      )
      None
    }
  }
  if complete {
    checked_expression_with_effect(
      Handler(
        body=checked_body.expression,
        handlers=checked_handler_tables,
        final_branch={
          binder_symbol: final_branch.binder_symbol,
          binder: final_branch.binder,
          binder_loc: final_branch.binder_loc,
          body: final_body,
          loc: final_branch.loc,
        },
        type_=result_type,
        loc~,
      ),
      result_type,
      residual_effect,
    )
  } else {
    checked_expression_none_reported(result_type)
  }
}

///|
fn SemanticChecker::preliminary_handler_arm_effect(
  self : SemanticChecker,
  scope : TypeScope,
  body : @desugar.DesugaredExpr,
  result_type : @types.Type,
) -> @types.Effect {
  let checker = self.copy_for_silent_analysis()
  checker.check_checked_expr(scope.copy(), body, result_type).effect
}

///|
fn handler_operation_scope(
  scope : TypeScope,
  checked : @checked.CheckedHandlerOperationArm,
  signature : OperationCallSignature,
  result_type : @types.Type,
  residual_effect : @types.Effect,
) -> TypeScope {
  // Arm scope:
  //
  //   Gamma, opened_type_binders, payload_pattern_binders, resume
  //
  // Opened type/effect binders are fresh abstract parameters from the handler
  // arm. Payload patterns are already checked against the instantiated operation
  // payload types before their binders are made visible to the arm body.
  let arm_scope = scope.copy()
  for type_binder in checked.type_binders {
    arm_scope.bind_type_parameter_kind(type_binder.id, type_binder.kind)
  }
  for pattern in checked.payload_patterns {
    arm_scope.bind_checked_pattern(pattern)
  }
  arm_scope.bind(
    checked.resume_symbol,
    handler_resume_type(signature, result_type, residual_effect),
  )
  arm_scope
}

///|
fn TypeScope::bind_checked_pattern(
  self : TypeScope,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Binding(symbol~, type_~, ..) => self.bind(symbol, type_)
    Variant(generic_arguments~, arguments~, ..) => {
      for argument in generic_arguments {
        match argument {
          TypeArgument(Parameter(id)) => self.bind_type_parameter_kind(id, Type)
          EffectArgument(Parameter(id)) =>
            self.bind_type_parameter_kind(id, Effect)
          _ => ()
        }
      }
      for argument in arguments {
        self.bind_checked_pattern(argument)
      }
    }
    Struct(type_binders~, fields~, ..) => {
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          self.bind_type_parameter_kind(parameter.id, parameter.kind)
        }
      }
      for field in fields {
        self.bind_checked_pattern(field.pattern)
      }
    }
    Wildcard(..) | Literal(..) => ()
  }
}

///|
fn SemanticChecker::handler_residual_effect(
  self : SemanticChecker,
  body_effect : @types.Effect,
  handled_effects : Array[@types.Effect],
  loc : SourceSpan,
) -> @types.Effect {
  // Residual effect rule:
  //
  //   Residual = BodyEff - handled_effects
  //
  // Closed body effects must actually contain every handled singleton. Open
  // rows are allowed because the unknown residual may contain the handled
  // effect; `effect_without` removes only concrete known terms.
  let mut residual = body_effect
  let removed_effects : Array[@types.Effect] = []
  for handled in handled_effects {
    if removed_effects.any(fn(effect) { effect.equals(handled) }) {
      continue
    }
    removed_effects.push(handled)
    if !effect_is_open(residual) && !effect_contains(residual, handled) {
      self.diagnostics.push({
        kind: EffectMismatch(expected=handled, actual=residual),
        loc,
      })
    }
    residual = effect_without(residual, handled)
  }
  residual
}

///|
fn effect_is_open(effect : @types.Effect) -> Bool {
  match effect.normalize() {
    Parameter(_) => true
    Union(items) => items.any(effect_is_open)
    Empty | Singleton(_, _) => false
  }
}

///|
fn effect_contains(effect : @types.Effect, needle : @types.Effect) -> Bool {
  match effect.normalize() {
    Empty | Parameter(_) => false
    Singleton(_, _) as item => item.equals(needle)
    Union(items) => items.any(fn(item) { effect_contains(item, needle) })
  }
}

///|
fn effect_without(
  effect : @types.Effect,
  removed : @types.Effect,
) -> @types.Effect {
  match effect.normalize() {
    Empty => Empty
    Singleton(_, _) as item => if item.equals(removed) { Empty } else { item }
    Parameter(_) as item => item
    Union(items) =>
      handler_effect_union(
        items.map(fn(item) { effect_without(item, removed) }),
      )
  }
}

///|
fn handler_effect_union(effects : Array[@types.Effect]) -> @types.Effect {
  let items = []
  for effect in effects {
    match effect.normalize() {
      Empty => ()
      Union(nested) =>
        for item in nested {
          push_unique_effect(items, item)
        }
      item => push_unique_effect(items, item)
    }
  }
  match items.length() {
    0 => Empty
    1 => items[0]
    _ => Union(items)
  }
}

///|
fn push_unique_effect(
  effects : Array[@types.Effect],
  effect : @types.Effect,
) -> Unit {
  if !effect_is_empty(effect) && !effects.any(fn(item) { item.equals(effect) }) {
    effects.push(effect)
  }
}

///|
fn HandlerOperationCheck::to_checked(
  self : HandlerOperationCheck,
) -> @checked.CheckedHandlerOperationArm {
  self.checked
}

///|
fn checked_handler_operations(
  operations : Array[HandlerOperationCheck],
) -> Array[@checked.CheckedHandlerOperationArm] {
  operations.map(HandlerOperationCheck::to_checked)
}

///|
fn SemanticChecker::check_handler_table_data(
  self : SemanticChecker,
  scope : TypeScope,
  handlers : Array[@desugar.DesugaredHandlerWithBlock],
  body_effect : @types.Effect,
) -> Array[HandlerTableCheck] {
  let checked = []
  let handled_effects = []
  for handler in handlers {
    if self.check_handler_table(scope, handler, handled_effects, body_effect)
      is Some(table) {
      handled_effects.push(table.checked.handled_effect)
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
  body_effect : @types.Effect,
) -> HandlerTableCheck? {
  // A `with` block handles exactly one singleton effect. All operation arms in
  // the block must belong to that same owner effect, and later coverage uses
  // the effect declaration's complete operation set.
  let operations = []
  let mut handled_effect : @types.Effect? = None
  for arm in handler.arms {
    guard self.handler_operation_signature(
        scope,
        arm.name,
        arm.type_binders,
        handler_operation_owner_hint(handled_effect, body_effect),
        arm.loc,
      )
      is Some(signature) else {
      continue
    }
    guard signature.effect is Singleton(_, _) else {
      self.diagnostics.push({
        kind: InternalTypecheckFailure(label="handler effect owner"),
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
    let checked = self.check_handler_operation_arm(scope, arm, signature)
    operations.push({ source: arm, signature, checked })
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
  self.check_handler_operation_coverage(
    effect,
    checked_handler_operations(operations),
    handler.loc,
  )
  Some({
    checked: {
      handled_effect: effect,
      operations: checked_handler_operations(operations),
      loc: handler.loc,
    },
    operations,
  })
}

///|
fn handler_operation_owner_hint(
  handled_effect : @types.Effect?,
  body_effect : @types.Effect,
) -> @types.Effect? {
  match handled_effect {
    Some(effect) => Some(effect)
    None => Some(body_effect)
  }
}

///|
fn SemanticChecker::check_handler_operation_arm(
  self : SemanticChecker,
  scope : TypeScope,
  arm : @desugar.DesugaredHandlerOperationArm,
  signature : OperationCallSignature,
) -> @checked.CheckedHandlerOperationArm {
  // Handler operation arm data checking:
  //
  //   Gamma |- pattern_i <= Payload_i ~~> checked_pattern_i
  //
  // The arm body is intentionally left unchecked here because it needs the
  // final handler result and residual effect to type `resume`.
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
    type_binders: signature.type_binders,
    payload_types: signature.payload,
    payload_patterns,
    resume_symbol: arm.resume_symbol,
    resume_type: Error,
    resume_binder: arm.resume_binder,
    resume_loc: arm.resume_loc,
    body: None,
    loc: arm.loc,
  }
}

///|
fn handler_resume_type(
  signature : OperationCallSignature,
  result_type : @types.Type,
  residual_effect : @types.Effect,
) -> @types.Type {
  // resume : OperationResult -> HandlerResult ! Residual
  Function([signature.result], result_type, residual_effect)
}

///|
fn SemanticChecker::check_handler_operation_coverage(
  self : SemanticChecker,
  handled_effect : @types.Effect,
  arms : Array[@checked.CheckedHandlerOperationArm],
  loc : SourceSpan,
) -> Unit {
  // Coverage is per operation and reuses the pattern matrix:
  //
  //   for every operation op in handled effect:
  //     operation arms for op are useful and exhaustive over op payload types
  //
  // The resume binder is not part of the pattern matrix.
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
