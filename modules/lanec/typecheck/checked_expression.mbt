///|
priv struct CheckedExpressionSynthesis {
  expression : @checked.CheckedExpr?
  type_ : @types.Type
  effect : @types.Effect
  missing_reported : Bool
}

///|
priv struct CheckedCallArguments {
  arguments : Array[@checked.CheckedCallArgument]
  effect : @types.Effect
}

///|
fn SemanticChecker::check_checked_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
  expected : @types.Type,
) -> CheckedExpressionSynthesis {
  // Checked expression construction follows the checking judgment:
  //
  //   Gamma |- e <= Expected ~~> checked_e
  //
  // Expected type information is used only by syntax nodes that are adjacent to
  // this expression: block results, if branches, function literals, calls, and
  // operation payloads.
  match expression {
    Builtin(name, loc~) => self.check_compiler_intrinsic(name, expected, loc)
    Extern(name, loc~) => self.check_extern_binding(name, expected, loc)
    ErrorRecovery(loc~) =>
      checked_expression(
        CompilerIntrinsic(name="%contextual_error", type_=expected, loc~),
        expected,
      )
    Literal(..) | Field(..) => {
      let checked = self.synthesize_checked_expr(scope, expression)
      self.expect_type(expected, checked.type_, expression.loc())
      checked
    }
    Block(items~, result~, loc~) =>
      self.check_checked_block(scope, items, result, expected, loc)
    If(condition~, then_branch~, else_branch~, loc~) =>
      self.check_checked_if(
        scope, condition, then_branch, else_branch, expected, loc,
      )
    Match(scrutinee~, arms~, loc~) =>
      self.check_checked_match(scope, scrutinee, arms, expected, loc)
    Call(callee~, arguments~, loc~) =>
      self.check_checked_call(scope, callee, arguments, expected, loc)
    EffectOperationCall(name~, generic_witnesses~, arguments~, loc~) => {
      let checked = self.synthesize_checked_operation_call(
        scope,
        name,
        generic_witnesses,
        arguments,
        Some(expected),
        loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    GenericApplication(callee~, arguments~, loc~) => {
      let checked = self.synthesize_checked_generic_application(
        scope, callee, arguments, loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    Handler(body~, handlers~, final_branch~, loc~) => {
      let checked = self.synthesize_checked_handler(
        scope, body, handlers, final_branch, loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    StructLiteral(type_name~, generic_arguments~, fields~, loc~) => {
      let checked = self.synthesize_checked_struct_literal(
        scope,
        type_name,
        generic_arguments,
        fields,
        Some(expected),
        loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    VariantCall(
      type_name~,
      generic_arguments~,
      variant~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) => {
      let checked = self.synthesize_checked_variant_call(
        scope,
        type_name,
        generic_arguments,
        variant,
        variant_generic_arguments,
        reference,
        arguments,
        Some(expected),
        loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) =>
      self.check_checked_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, expected,
        loc,
      )
    Var(..) => {
      let checked = self.synthesize_checked_expr(scope, expression)
      self.expect_type(expected, checked.type_, expression.loc())
      checked
    }
  }
}

///|
fn SemanticChecker::synthesize_checked_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
) -> CheckedExpressionSynthesis {
  // Checked expression construction follows the synthesis judgment:
  //
  //   Gamma |- e => T ~~> checked_e
  //
  // This direction computes both the synthesized type and the checked subtree.
  // Forms that need an adjacent expected type must use `check_checked_expr`
  // instead of inventing non-local inference.
  match expression {
    Literal(literal~, loc~) => {
      let type_ = literal.type_()
      checked_expression(
        Literal(literal=self.checked_literal(literal, loc), type_~, loc~),
        type_,
      )
    }
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) =>
      self.synthesize_checked_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, loc,
      )
    Var(name~, reference~, loc~) =>
      self.synthesize_checked_value_reference(scope, reference, name, loc)
    Field(base~, name~, reference~, loc~) =>
      self.synthesize_checked_field(scope, base, name, reference, loc)
    If(condition~, then_branch~, else_branch~, loc~) =>
      self.synthesize_checked_if(
        scope, condition, then_branch, else_branch, loc,
      )
    Match(scrutinee~, arms~, loc~) =>
      self.synthesize_checked_match(scope, scrutinee, arms, loc)
    Call(callee~, arguments~, loc~) =>
      self.synthesize_checked_call(scope, callee, arguments, loc)
    EffectOperationCall(name~, generic_witnesses~, arguments~, loc~) =>
      self.synthesize_checked_operation_call(
        scope,
        name,
        generic_witnesses,
        arguments,
        None,
        loc,
      )
    GenericApplication(callee~, arguments~, loc~) =>
      self.synthesize_checked_generic_application(scope, callee, arguments, loc)
    Handler(body~, handlers~, final_branch~, loc~) =>
      self.synthesize_checked_handler(scope, body, handlers, final_branch, loc)
    Block(items~, result~, loc~) =>
      self.synthesize_checked_block(scope, items, result, loc)
    StructLiteral(type_name~, generic_arguments~, fields~, loc~) =>
      self.synthesize_checked_struct_literal(
        scope,
        type_name,
        generic_arguments,
        fields,
        None,
        loc,
      )
    VariantCall(
      type_name~,
      generic_arguments~,
      variant~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.synthesize_checked_variant_call(
        scope,
        type_name,
        generic_arguments,
        variant,
        variant_generic_arguments,
        reference,
        arguments,
        None,
        loc,
      )
    Builtin(name, loc~) => self.synthesize_compiler_intrinsic(name, loc)
    Extern(name, loc~) => self.synthesize_extern_binding(name, loc)
    ErrorRecovery(..) => checked_expression_none_reported(Error)
  }
}

///|
fn SemanticChecker::synthesize_checked_generic_application(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  arguments : Array[@resolve.ResolvedGenericArgument],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let checked_callee = self.synthesize_checked_expr(scope, callee)
  guard self.require_checked_expression(
      checked_callee,
      callee.loc(),
      "generic application callee",
    )
    is Some(callee_expr) else {
    return checked_expression_none_reported(Error)
  }
  match
    self.check_explicit_generic_application(
      scope,
      callee,
      checked_callee.type_,
      arguments,
      loc,
    ) {
    Some(application) =>
      checked_expression_with_effect(
        GenericApplication(
          callee=callee_expr,
          arguments=application.arguments,
          type_=application.type_,
          loc~,
        ),
        application.type_,
        checked_callee.effect,
      )
    None => checked_expression_none_reported(Error)
  }
}

///|
fn SemanticChecker::check_checked_block(
  self : SemanticChecker,
  scope : TypeScope,
  items : Array[@desugar.DesugaredLocalItem],
  result : @desugar.DesugaredExpr,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let next_scope = scope.copy()
  let checked_items : Array[@checked.CheckedLocalItem] = []
  let effects = []
  let mut complete = true
  for item in items {
    match item {
      Let(declaration) =>
        match self.check_checked_local_let(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            checked_items.push(Let(result.declaration))
          }
          None => complete = false
        }
      Function(declaration) =>
        match self.check_checked_local_function(next_scope, declaration) {
          Some(declaration) => checked_items.push(Function(declaration))
          None => complete = false
        }
      Offer(declaration) =>
        match self.check_checked_local_offer(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            checked_items.push(Let(result.declaration))
          }
          None => complete = false
        }
      PatternLet(declaration) =>
        match self.check_checked_local_pattern_let(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            checked_items.push(PatternLet(result.declaration))
          }
          None => complete = false
        }
    }
  }
  let checked_result = self.check_checked_expr(next_scope, result, expected)
  effects.push(checked_result.effect)
  guard self.require_checked_expression(
      checked_result,
      result.loc(),
      "block result",
    )
    is Some(result) else {
    return checked_expression_none_reported(expected)
  }
  if complete {
    checked_expression_with_effect(
      Block(items=checked_items, result~, type_=expected, loc~),
      expected,
      effect_union(effects),
    )
  } else {
    checked_expression_none_reported(expected)
  }
}

///|
fn SemanticChecker::synthesize_checked_block(
  self : SemanticChecker,
  scope : TypeScope,
  items : Array[@desugar.DesugaredLocalItem],
  result : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let next_scope = scope.copy()
  let checked_items : Array[@checked.CheckedLocalItem] = []
  let effects = []
  let opened_type_parameters : Array[TypeParameterId] = []
  let mut complete = true
  for item in items {
    match item {
      Let(declaration) =>
        match self.check_checked_local_let(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            checked_items.push(Let(result.declaration))
          }
          None => complete = false
        }
      Function(declaration) =>
        match self.check_checked_local_function(next_scope, declaration) {
          Some(declaration) => checked_items.push(Function(declaration))
          None => complete = false
        }
      Offer(declaration) =>
        match self.check_checked_local_offer(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            checked_items.push(Let(result.declaration))
          }
          None => complete = false
        }
      PatternLet(declaration) =>
        match self.check_checked_local_pattern_let(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            opened_type_parameters.append(
              result.declaration.pattern.opened_type_parameters(),
            )
            checked_items.push(PatternLet(result.declaration))
          }
          None => complete = false
        }
    }
  }
  let checked_result = self.synthesize_checked_expr(next_scope, result)
  ignore(
    self.check_hidden_type_escape(
      opened_type_parameters,
      checked_result.type_,
      result.loc(),
    ),
  )
  effects.push(checked_result.effect)
  guard self.require_checked_expression(
      checked_result,
      result.loc(),
      "block result",
    )
    is Some(result) else {
    return checked_expression_none_reported(checked_result.type_)
  }
  if complete {
    checked_expression_with_effect(
      Block(items=checked_items, result~, type_=checked_result.type_, loc~),
      checked_result.type_,
      effect_union(effects),
    )
  } else {
    checked_expression_none_reported(checked_result.type_)
  }
}

///|
fn SemanticChecker::check_checked_if(
  self : SemanticChecker,
  scope : TypeScope,
  condition : @desugar.DesugaredExpr,
  then_branch : @desugar.DesugaredExpr,
  else_branch : @desugar.DesugaredExpr,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Gamma |- condition <= Bool ~~> checked_condition
  // Gamma |- then <= Expected ~~> checked_then
  // Gamma |- else <= Expected ~~> checked_else
  // ------------------------------------------------
  // Gamma |- if condition { then } else { else } <= Expected
  let checked_condition = self.check_checked_expr(
    scope,
    condition,
    Primitive(Bool),
  )
  guard self.require_checked_expression(checked_condition, loc, "if condition")
    is Some(condition) else {
    return checked_expression_none_reported(expected)
  }
  let checked_then_branch = self.check_checked_expr(
    scope, then_branch, expected,
  )
  guard self.require_checked_expression(
      checked_then_branch, loc, "if then branch",
    )
    is Some(then_branch) else {
    return checked_expression_none_reported(expected)
  }
  let checked_else_branch = self.check_checked_expr(
    scope, else_branch, expected,
  )
  guard self.require_checked_expression(
      checked_else_branch, loc, "if else branch",
    )
    is Some(else_branch) else {
    return checked_expression_none_reported(expected)
  }
  checked_expression_with_effect(
    If(condition~, then_branch~, else_branch~, type_=expected, loc~),
    expected,
    effect_union([
      checked_condition.effect,
      checked_then_branch.effect,
      checked_else_branch.effect,
    ]),
  )
}

///|
fn SemanticChecker::synthesize_checked_if(
  self : SemanticChecker,
  scope : TypeScope,
  condition : @desugar.DesugaredExpr,
  then_branch : @desugar.DesugaredExpr,
  else_branch : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Gamma |- condition <= Bool ~~> checked_condition
  // Gamma |- then => T ~~> checked_then
  // Gamma |- else <= T ~~> checked_else
  // -----------------------------------------
  // Gamma |- if condition { then } else { else } => T
  let checked_condition = self.check_checked_expr(
    scope,
    condition,
    Primitive(Bool),
  )
  guard self.require_checked_expression(checked_condition, loc, "if condition")
    is Some(condition) else {
    return checked_expression_none_reported(Error)
  }
  let checked_then_branch = self.synthesize_checked_expr(scope, then_branch)
  guard self.require_checked_expression(
      checked_then_branch, loc, "if then branch",
    )
    is Some(then_branch_expr) else {
    return checked_expression_none_reported(checked_then_branch.type_)
  }
  let type_ = checked_then_branch.type_
  let checked_else_branch = self.check_checked_expr(scope, else_branch, type_)
  guard self.require_checked_expression(
      checked_else_branch, loc, "if else branch",
    )
    is Some(else_branch) else {
    return checked_expression_none_reported(type_)
  }
  checked_expression_with_effect(
    If(condition~, then_branch=then_branch_expr, else_branch~, type_~, loc~),
    type_,
    effect_union([
      checked_condition.effect,
      checked_then_branch.effect,
      checked_else_branch.effect,
    ]),
  )
}

///|
fn SemanticChecker::check_checked_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let checked_scrutinee = self.synthesize_checked_expr(scope, scrutinee)
  guard self.require_checked_expression(
      checked_scrutinee,
      scrutinee.loc(),
      "match scrutinee",
    )
    is Some(scrutinee) else {
    return checked_expression_none_reported(expected)
  }
  let matrix = PatternMatrix::PatternMatrix()
  let checked_arms : Array[@checked.CheckedMatchArm] = []
  let effects = [checked_scrutinee.effect]
  let mut complete = true
  for arm in arms {
    let arm_scope = scope.copy()
    let pattern = self.check_match_pattern(
      arm_scope,
      arm.pattern,
      checked_scrutinee.type_,
    )
    if !matrix.is_useful(self.declarations, pattern, checked_scrutinee.type_) {
      self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
    }
    matrix.add(pattern)
    let opened_type_parameters = pattern.opened_type_parameters()
    let checked_body = if opened_type_parameters.is_empty() {
      self.check_checked_expr(arm_scope, arm.body, expected)
    } else {
      let synthesized = self.synthesize_checked_expr(arm_scope, arm.body)
      if !self.check_hidden_type_escape(
          opened_type_parameters,
          synthesized.type_,
          arm.body.loc(),
        ) {
        self.expect_type(expected, synthesized.type_, arm.body.loc())
      }
      synthesized
    }
    match
      self.require_checked_expression(checked_body, arm.body.loc(), "match arm") {
      Some(body) => {
        effects.push(checked_body.effect)
        checked_arms.push({ pattern, body, loc: arm.loc })
      }
      None => complete = false
    }
  }
  if !matrix.is_exhaustive(self.declarations, checked_scrutinee.type_) {
    self.diagnostics.push({
      kind: NonExhaustiveMatch(
        type_=checked_scrutinee.type_,
        witness=matrix.missing_witness(
          self.declarations,
          checked_scrutinee.type_,
        ),
      ),
      loc,
    })
  }
  if complete {
    checked_expression_with_effect(
      Match(scrutinee~, arms=checked_arms, type_=expected, loc~),
      expected,
      effect_union(effects),
    )
  } else {
    checked_expression_none_reported(expected)
  }
}

///|
fn SemanticChecker::synthesize_checked_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let checked_scrutinee = self.synthesize_checked_expr(scope, scrutinee)
  guard self.require_checked_expression(
      checked_scrutinee,
      scrutinee.loc(),
      "match scrutinee",
    )
    is Some(scrutinee) else {
    return checked_expression_none_reported(Error)
  }
  let matrix = PatternMatrix::PatternMatrix()
  let checked_arms : Array[@checked.CheckedMatchArm] = []
  let effects = [checked_scrutinee.effect]
  let mut result : @types.Type = Error
  let mut has_result = false
  let mut complete = true
  for arm in arms {
    let arm_scope = scope.copy()
    let pattern = self.check_match_pattern(
      arm_scope,
      arm.pattern,
      checked_scrutinee.type_,
    )
    if !matrix.is_useful(self.declarations, pattern, checked_scrutinee.type_) {
      self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
    }
    matrix.add(pattern)
    let checked_body = self.synthesize_checked_expr(arm_scope, arm.body)
    ignore(
      self.check_hidden_type_escape(
        pattern.opened_type_parameters(),
        checked_body.type_,
        arm.body.loc(),
      ),
    )
    if has_result {
      self.expect_type(result, checked_body.type_, arm.loc)
    } else {
      result = checked_body.type_
      has_result = true
    }
    match
      self.require_checked_expression(checked_body, arm.body.loc(), "match arm") {
      Some(body) => {
        effects.push(checked_body.effect)
        checked_arms.push({ pattern, body, loc: arm.loc })
      }
      None => complete = false
    }
  }
  if !has_result {
    self.diagnostics.push({ kind: EmptyMatchNeedsExpectedType, loc })
  }
  if !matrix.is_exhaustive(self.declarations, checked_scrutinee.type_) {
    self.diagnostics.push({
      kind: NonExhaustiveMatch(
        type_=checked_scrutinee.type_,
        witness=matrix.missing_witness(
          self.declarations,
          checked_scrutinee.type_,
        ),
      ),
      loc,
    })
  }
  if complete {
    checked_expression_with_effect(
      Match(scrutinee~, arms=checked_arms, type_=result, loc~),
      result,
      effect_union(effects),
    )
  } else {
    checked_expression_none_reported(result)
  }
}

///|
fn SemanticChecker::synthesize_checked_call(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  self.synthesize_checked_call_with_expected(
    scope,
    callee,
    arguments,
    None,
    loc,
  )
}

///|
fn SemanticChecker::synthesize_checked_call_with_expected(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let checked_callee = self.synthesize_checked_expr(scope, callee)
  guard self.require_checked_expression(
      checked_callee,
      callee.loc(),
      "call callee",
    )
    is Some(checked_callee_expr) else {
    return checked_expression_none_reported(Error)
  }
  let diagnostic_count = self.diagnostics.length()
  let arguments = self.prepare_direct_call_arguments(
    scope,
    callee,
    checked_callee.type_,
    arguments,
    expected_result,
    loc,
  )
  if self.diagnostics.length() != diagnostic_count {
    return checked_expression_none_reported(Error)
  }
  match checked_callee.type_ {
    Function(parameters, result, effect) => {
      guard self.check_checked_call_arguments(scope, parameters, arguments, loc)
        is Some(checked_arguments) else {
        return checked_expression_none_reported(result)
      }
      checked_expression_with_effect(
        Call(
          callee=checked_callee_expr,
          arguments=checked_arguments.arguments,
          type_=result,
          loc~,
        ),
        result,
        effect_union([checked_callee.effect, checked_arguments.effect, effect]),
      )
    }
    Forall(type_parameters, body) => {
      guard self.instantiate_generic_callable(
          scope,
          type_parameters,
          body,
          arguments,
          expected_result,
          generic_callable_inference_label(callee),
          loc,
          true,
        )
        is Some(instantiated) else {
        return checked_expression_none_reported(Error)
      }
      guard self.check_checked_call_arguments(
          scope,
          instantiated.parameters,
          arguments,
          loc,
        )
        is Some(checked_arguments) else {
        return checked_expression_none_reported(instantiated.result)
      }
      let callee = generic_applied_callee(
        checked_callee_expr,
        instantiated.generic_arguments,
        Function(
          instantiated.parameters,
          instantiated.result,
          instantiated.effect,
        ),
        loc,
      )
      checked_expression_with_effect(
        Call(
          callee~,
          arguments=checked_arguments.arguments,
          type_=instantiated.result,
          loc~,
        ),
        instantiated.result,
        effect_union([
          checked_callee.effect,
          checked_arguments.effect,
          instantiated.effect,
        ]),
      )
    }
    Error => checked_expression_none_reported(Error)
    type_ => {
      self.diagnostics.push({ kind: NotCallable(type_), loc })
      checked_expression_none_reported(Error)
    }
  }
}

///|
fn SemanticChecker::check_checked_call(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Checked call in checking mode first synthesizes the call under the expected
  // result type so generic callees can use that adjacent result information,
  // then enforces the ordinary expected/actual equality.
  let checked = self.synthesize_checked_call_with_expected(
    scope,
    callee,
    arguments,
    Some(expected),
    loc,
  )
  self.expect_type(expected, checked.type_, loc)
  checked
}

///|
fn generic_applied_callee(
  callee : @checked.CheckedExpr,
  generic_arguments : Array[@types.GenericArgument],
  type_ : @types.Type,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  // Non-generic calls keep the value callee directly. Generic calls insert the
  // explicit checked generic application inferred by local call checking.
  if generic_arguments.is_empty() {
    callee
  } else {
    GenericApplication(callee~, arguments=generic_arguments, type_~, loc~)
  }
}

///|
fn SemanticChecker::check_checked_call_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  parameters : Array[@types.Type],
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> CheckedCallArguments? {
  // Checked argument rule:
  //
  //   Gamma |- arg_i <= P_i ~~> checked_arg_i ! E_i
  //   ------------------------------------------------
  //   checked call arguments with effect union {E_i...}
  //
  // Callee effects are added by the caller; this helper accounts only for
  // argument evaluation.
  if !self.check_application_arity(
      parameters.length(),
      arguments.length(),
      loc,
      true,
    ) {
    return None
  }
  let checked_arguments : Array[@checked.CheckedCallArgument] = []
  let effects = []
  let mut complete = true
  for index in 0..<parameters.length() {
    let checked = self.check_checked_call_argument(
      scope,
      arguments[index],
      parameters[index],
    )
    match
      self.require_checked_expression(
        checked,
        arguments[index].value_expr().loc(),
        "call argument",
      ) {
      Some(value) =>
        checked_arguments.push({ value, loc: arguments[index].loc() })
      None => complete = false
    }
    effects.push(checked.effect)
  }
  if complete {
    Some({ arguments: checked_arguments, effect: effect_union(effects) })
  } else {
    None
  }
}

///|
fn SemanticChecker::check_checked_call_argument(
  self : SemanticChecker,
  scope : TypeScope,
  argument : @desugar.DesugaredCallArgument,
  parameter : @types.Type,
) -> CheckedExpressionSynthesis {
  match argument {
    Positional(value~, ..) => self.check_checked_expr(scope, value, parameter)
    Named(name~, value~, loc~) => {
      self.diagnostics.push({ kind: InvalidNamedArgument(name~), loc })
      self.check_checked_expr(scope, value, parameter)
    }
  }
}

///|
fn SemanticChecker::synthesize_checked_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  effect : @resolve.ResolvedEffectTerm?,
  body : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let (parameter_types, checked_parameters) = self.synthesize_function_literal_parameters(
    parameters,
  )
  let body_scope = self.function_body_scope(
    scope, type_parameters, checked_parameters,
  )
  let checked_effect = match effect {
    Some(effect) => self.check_effect(effect)
    None => Empty
  }
  let (result_type, checked_body) = if return_type is Some(type_annotation) {
    let result_type = self.check_type(type_annotation)
    (
      result_type,
      self.check_checked_expr(
        body_scope.with_expected_effect(checked_effect),
        body,
        result_type,
      ),
    )
  } else {
    let checked_body = self.synthesize_checked_expr(
      body_scope.with_expected_effect(checked_effect),
      body,
    )
    (checked_body.type_, checked_body)
  }
  self.expect_effect(checked_effect, checked_body.effect, body.loc())
  guard self.require_checked_expression(
      checked_body,
      body.loc(),
      "function body",
    )
    is Some(body) else {
    return checked_expression_none_reported(
      Function(parameter_types, result_type, checked_effect),
    )
  }
  let function_type = @types.Type::Function(
    parameter_types, result_type, checked_effect,
  )
  let checked_type_parameters = check_type_parameters(
    self.diagnostics,
    type_parameters,
  )
  let type_ = if type_parameters.is_empty() {
    function_type
  } else {
    Forall(checked_type_parameters, function_type)
  }
  checked_expression(
    FunctionLiteral(
      type_parameters=checked_type_parameters,
      parameters=checked_parameters,
      return_type=result_type,
      body~,
      type_~,
      loc~,
    ),
    type_,
  )
}

///|
fn SemanticChecker::check_checked_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  effect : @resolve.ResolvedEffectTerm?,
  body : @desugar.DesugaredExpr,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match expected {
    Forall(expected_parameters, expected_body) => {
      // Checked forall introduction mirrors the non-building checker:
      //
      //   Gamma, A_i |- fn body <= ExpectedBody[A_i]
      //   ------------------------------------------
      //   Gamma |- fn[A_i](...) <= forall A_i. ExpectedBody
      //
      // The local binder symbols replace the expected forall parameter ids
      // before checking the body.
      let checked_type_parameters = check_type_parameters(
        self.diagnostics,
        type_parameters,
      )
      if type_parameters.length() != expected_parameters.length() {
        self.report_application_arity("generic function arity", loc)
        return checked_expression_none_reported(expected)
      }
      let substitution = @types.TypeSubstitution::TypeSubstitution()
      for index in 0..<expected_parameters.length() {
        substitution.insert(
          expected_parameters[index].id,
          Parameter(type_parameters[index].symbol),
        )
      }
      let scope = scope.with_type_parameter_kinds(type_parameters)
      let checked = self.check_checked_function_literal(
        scope,
        [],
        parameters,
        return_type,
        effect,
        body,
        expected_body.substitute(substitution),
        loc,
      )
      guard checked.expression
        is Some(
          FunctionLiteral(parameters~, return_type~, body~, type_~, loc~, ..)
        ) else {
        return checked
      }
      let type_ : @types.Type = Forall(checked_type_parameters, type_)
      checked_expression(
        FunctionLiteral(
          type_parameters=checked_type_parameters,
          parameters~,
          return_type~,
          body~,
          type_~,
          loc~,
        ),
        type_,
      )
    }
    Function(expected_parameters, expected_result, expected_effect) => {
      if !type_parameters.is_empty() {
        self.report_application_arity("generic function arity", loc)
        return checked_expression_none_reported(expected)
      }
      self.check_monomorphic_function_literal(
        scope,
        parameters,
        return_type,
        effect,
        body,
        expected_parameters,
        expected_result,
        Some(expected_effect),
        loc,
      )
    }
    Error => checked_expression_none_reported(Error)
    _ => {
      let checked = self.synthesize_checked_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
  }
}

///|
fn SemanticChecker::synthesize_checked_value_reference(
  self : SemanticChecker,
  scope : TypeScope,
  reference : @resolve.ResolvedValueReference,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match reference {
    Symbol(symbol) =>
      self.synthesize_checked_symbol_value(scope, symbol, name, loc)
    Unresolved(name) => {
      self.diagnostics.push({ kind: UnresolvedValue(name), loc })
      checked_expression_none(Error)
    }
  }
}

///|
fn SemanticChecker::synthesize_checked_symbol_value(
  self : SemanticChecker,
  scope : TypeScope,
  symbol : ValueSymbolId,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard scope.lookup(symbol) is Some(type_) else {
    self.diagnostics.push({ kind: UnresolvedValue(name), loc })
    return checked_expression_none(Error)
  }
  checked_expression(Value(name~, symbol~, type_~, loc~), type_)
}

///|
fn SemanticChecker::synthesize_checked_field(
  self : SemanticChecker,
  scope : TypeScope,
  base : @desugar.DesugaredExpr,
  name : String,
  reference : @resolve.ResolvedFieldReference,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let checked_base = self.synthesize_checked_expr(scope, base)
  guard self.require_checked_expression(checked_base, base.loc(), "field base")
    is Some(base) else {
    return checked_expression_none_reported(Error)
  }
  match reference {
    Symbol(field) =>
      self.checked_field_from_symbol(
        base,
        checked_base.type_,
        checked_base.effect,
        field,
        name,
        loc,
      )
    Deferred(_) =>
      if checked_base.type_.decompose_nominal() is Some((symbol, _)) {
        guard self.source.symbols.field_named(symbol, name) is Some(field) else {
          self.diagnostics.push({ kind: UnknownField(name~), loc })
          return checked_expression_none_reported(Error)
        }
        self.checked_field_from_symbol(
          base,
          checked_base.type_,
          checked_base.effect,
          field,
          name,
          loc,
        )
      } else if checked_base.type_ is Error {
        checked_expression_none_reported(Error)
      } else {
        self.diagnostics.push({ kind: NotAStruct(checked_base.type_), loc })
        checked_expression_none_reported(Error)
      }
    Unresolved(..) => {
      self.diagnostics.push({ kind: UnknownField(name~), loc })
      checked_expression_none_reported(Error)
    }
  }
}

///|
fn SemanticChecker::checked_field_from_symbol(
  self : SemanticChecker,
  base : @checked.CheckedExpr,
  base_type : @types.Type,
  base_effect : @types.Effect,
  field : FieldSymbolId,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let type_ = self.declarations.field_type(
    self.diagnostics,
    base_type,
    field,
    name,
    loc,
  )
  checked_expression_with_effect(
    Field(base~, field~, name~, type_~, loc~),
    type_,
    base_effect,
  )
}

///|
fn checked_expression(
  expression : @checked.CheckedExpr,
  type_ : @types.Type,
) -> CheckedExpressionSynthesis {
  checked_expression_with_effect(expression, type_, Empty)
}

///|
fn checked_expression_with_effect(
  expression : @checked.CheckedExpr,
  type_ : @types.Type,
  effect : @types.Effect,
) -> CheckedExpressionSynthesis {
  { expression: Some(expression), type_, effect, missing_reported: false }
}

///|
fn checked_expression_none(type_ : @types.Type) -> CheckedExpressionSynthesis {
  { expression: None, type_, effect: Empty, missing_reported: false }
}

///|
fn checked_expression_none_reported(
  type_ : @types.Type,
) -> CheckedExpressionSynthesis {
  { expression: None, type_, effect: Empty, missing_reported: true }
}

///|
fn SemanticChecker::require_checked_expression(
  self : SemanticChecker,
  checked : CheckedExpressionSynthesis,
  loc : SourceSpan,
  label : String,
) -> @checked.CheckedExpr? {
  match checked.expression {
    Some(expression) => Some(expression)
    None => {
      if !checked.missing_reported {
        self.diagnostics.push({
          kind: InternalTypecheckFailure(label="checked " + label),
          loc,
        })
      }
      None
    }
  }
}
