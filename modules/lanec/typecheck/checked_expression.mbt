///|
priv struct CheckedExpressionSynthesis {
  expression : @checked.CheckedExpr?
  type_ : @types.Type
  effect : @types.Effect
  missing_reported : Bool
}

///|
priv enum CheckedExpectationMatch {
  MatchesExpectation
  MismatchesExpectation
  UndeterminedExpectationMatch
}

///|
priv struct CheckedExpressionCheck {
  synthesis : CheckedExpressionSynthesis
  expectation_match : CheckedExpectationMatch
}

///|
fn CheckedExpressionSynthesis::with_expectation_match(
  self : CheckedExpressionSynthesis,
  expectation_match : CheckedExpectationMatch,
) -> CheckedExpressionCheck {
  { synthesis: self, expectation_match }
}

///|
fn undetermined_checked_expression(
  type_ : @types.Type,
) -> CheckedExpressionCheck {
  checked_expression_none_reported(type_).with_expectation_match(
    UndeterminedExpectationMatch,
  )
}

///|
priv struct CheckedCallArguments {
  arguments : Array[@checked.CheckedCallArgument]
  effect : @types.Effect
}

///|
priv enum CheckedMismatchContext {
  OrdinaryMismatch
  ElseOmittingConditionalMismatch
}

///|
priv struct CheckedExpectation {
  type_ : @types.Type
  hidden_type_parameters : Array[TypeParameterId]
  mismatch_context : CheckedMismatchContext
}

///|
fn checked_expectation(type_ : @types.Type) -> CheckedExpectation {
  { type_, hidden_type_parameters: [], mismatch_context: OrdinaryMismatch }
}

///|
fn CheckedExpectation::with_hidden_type_parameters(
  self : CheckedExpectation,
  parameters : Array[TypeParameterId],
) -> CheckedExpectation {
  if parameters.is_empty() {
    self
  } else {
    let hidden_type_parameters = self.hidden_type_parameters.copy()
    hidden_type_parameters.append(parameters)
    { ..self, hidden_type_parameters, }
  }
}

///|
fn CheckedExpectation::for_else_omitting_conditional(
  self : CheckedExpectation,
) -> CheckedExpectation {
  { ..self, mismatch_context: ElseOmittingConditionalMismatch }
}

///|
fn checked_expectation_match(result : Bool?) -> CheckedExpectationMatch {
  match result {
    Some(true) => MatchesExpectation
    Some(false) => MismatchesExpectation
    None => UndeterminedExpectationMatch
  }
}

///|
fn merge_checked_expectation_match(
  accumulated : CheckedExpectationMatch,
  current : CheckedExpectationMatch,
) -> CheckedExpectationMatch {
  match (accumulated, current) {
    (MismatchesExpectation, _) | (_, MismatchesExpectation) =>
      MismatchesExpectation
    (UndeterminedExpectationMatch, _) | (_, UndeterminedExpectationMatch) =>
      UndeterminedExpectationMatch
    (MatchesExpectation, MatchesExpectation) => MatchesExpectation
  }
}

///|
fn SemanticChecker::expect_checked_type(
  self : SemanticChecker,
  expectation : CheckedExpectation,
  actual : @types.Type,
  loc : SourceSpan,
) -> CheckedExpectationMatch {
  let expectation_match = checked_expectation_match(
    self.type_matches(expectation.type_, actual, loc),
  )
  if expectation_match is MismatchesExpectation {
    let kind = if actual.mentions_any_type_parameter(
        expectation.hidden_type_parameters,
      ) {
      HiddenTypeEscape(type_=actual)
    } else {
      match expectation.mismatch_context {
        OrdinaryMismatch => TypeMismatch(expected=expectation.type_, actual~)
        ElseOmittingConditionalMismatch =>
          ElseOmittingConditionalRequiresUnit(actual~)
      }
    }
    self.diagnostics.push({ kind, loc })
  }
  expectation_match
}

///|
fn SemanticChecker::check_checked_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
  expected : @types.Type,
) -> CheckedExpressionSynthesis {
  self.check_checked_expr_with_expectation(
    scope,
    expression,
    checked_expectation(expected),
  ).synthesis
}

///|
fn SemanticChecker::check_checked_expr_with_expectation(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
  expectation : CheckedExpectation,
) -> CheckedExpressionCheck {
  // Checked expression construction follows the checking judgment:
  //
  //   Gamma |- e <= Expected ~~> checked_e
  //
  // Expected type information is used only by syntax nodes that are adjacent to
  // this expression: block results, if branches, function literals, calls, and
  // operation payloads.
  match expression {
    Builtin(name, loc~) =>
      self.check_compiler_intrinsic(name, expectation.type_, loc)
    Extern(name, loc~) =>
      self
      .check_extern_binding(name, expectation.type_, loc)
      .with_expectation_match(MatchesExpectation)
    ErrorRecovery(loc~) =>
      checked_expression(
        ErrorRecovery(type_=expectation.type_, loc~),
        expectation.type_,
      ).with_expectation_match(MatchesExpectation)
    Literal(..) | Field(..) => {
      let synthesis = self.synthesize_checked_expr(scope, expression)
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, expression.loc()),
      )
    }
    Block(items~, result~, loc~) =>
      self.check_checked_block(scope, items, result, expectation, loc)
    If(condition~, then_branch~, else_branch~, loc~) =>
      self.check_checked_if(
        scope, condition, then_branch, else_branch, expectation, loc,
      )
    Match(scrutinee~, arms~, loc~) =>
      self.check_checked_match(scope, scrutinee, arms, expectation, loc)
    Call(callee~, arguments~, loc~) =>
      self.check_checked_call(scope, callee, arguments, expectation, loc)
    EffectOperationCall(name~, generic_witnesses~, arguments~, loc~) => {
      let synthesis = self.synthesize_checked_operation_call(
        scope,
        name,
        generic_witnesses,
        arguments,
        Some(expectation.type_),
        loc,
      )
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, loc),
      )
    }
    GenericApplication(callee~, arguments~, loc~) => {
      let synthesis = self.synthesize_checked_generic_application(
        scope, callee, arguments, loc,
      )
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, loc),
      )
    }
    Handler(body~, handlers~, final_branch~, loc~) => {
      let synthesis = self.synthesize_checked_handler(
        scope, body, handlers, final_branch, loc,
      )
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, loc),
      )
    }
    StructLiteral(
      type_name~,
      type_name_loc~,
      reference~,
      generic_arguments~,
      fields~,
      loc~
    ) => {
      let synthesis = self.synthesize_checked_struct_literal(
        scope,
        type_name,
        type_name_loc,
        reference,
        generic_arguments,
        fields,
        Some(expectation.type_),
        loc,
      )
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, loc),
      )
    }
    VariantCall(
      type_name~,
      type_name_loc~,
      generic_arguments~,
      variant~,
      variant_loc~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) => {
      let synthesis = self.synthesize_checked_variant_call(
        scope,
        type_name,
        type_name_loc,
        generic_arguments,
        variant,
        variant_loc,
        variant_generic_arguments,
        reference,
        arguments,
        Some(expectation.type_),
        loc,
      )
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, loc),
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
      self.check_checked_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, expectation,
        loc,
      )
    Var(..) => {
      let synthesis = self.synthesize_checked_expr(scope, expression)
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, expression.loc()),
      )
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
    Field(base~, name~, name_loc~, reference~, loc~) =>
      self.synthesize_checked_field(scope, base, name, name_loc, reference, loc)
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
    StructLiteral(
      type_name~,
      type_name_loc~,
      reference~,
      generic_arguments~,
      fields~,
      loc~
    ) =>
      self.synthesize_checked_struct_literal(
        scope,
        type_name,
        type_name_loc,
        reference,
        generic_arguments,
        fields,
        None,
        loc,
      )
    VariantCall(
      type_name~,
      type_name_loc~,
      generic_arguments~,
      variant~,
      variant_loc~,
      variant_generic_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.synthesize_checked_variant_call(
        scope,
        type_name,
        type_name_loc,
        generic_arguments,
        variant,
        variant_loc,
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
  expectation : CheckedExpectation,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
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
      PatternLet(declaration) =>
        match self.check_checked_local_pattern_let(next_scope, declaration) {
          Some(result) => {
            effects.push(result.effect)
            checked_items.push(PatternLet(result.declaration))
          }
          None => complete = false
        }
      Expression(expression) => {
        let checked = self.check_checked_expr(
          next_scope,
          expression,
          Primitive(Unit),
        )
        effects.push(checked.effect)
        match
          self.require_checked_expression(
            checked,
            expression.loc(),
            "sequential expression",
          ) {
          Some(expression) => checked_items.push(Expression(expression))
          None => complete = false
        }
      }
    }
  }
  let checked_result = self.check_checked_expr_with_expectation(
    next_scope, result, expectation,
  )
  effects.push(checked_result.synthesis.effect)
  guard self.require_checked_expression(
      checked_result.synthesis,
      result.loc(),
      "block result",
    )
    is Some(result) else {
    return undetermined_checked_expression(expectation.type_)
  }
  if complete {
    checked_expression_with_effect(
      Block(items=checked_items, result~, type_=expectation.type_, loc~),
      expectation.type_,
      effect_union(effects),
    ).with_expectation_match(checked_result.expectation_match)
  } else {
    undetermined_checked_expression(expectation.type_)
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
      Expression(expression) => {
        let checked = self.check_checked_expr(
          next_scope,
          expression,
          Primitive(Unit),
        )
        effects.push(checked.effect)
        match
          self.require_checked_expression(
            checked,
            expression.loc(),
            "sequential expression",
          ) {
          Some(expression) => checked_items.push(Expression(expression))
          None => complete = false
        }
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
  else_branch : @desugar.DesugaredExpr?,
  expectation : CheckedExpectation,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  guard else_branch is Some(else_branch) else {
    let checked = self.check_else_omitting_if(
      scope, condition, then_branch, loc,
    )
    let expectation_match = if checked.expectation_match is MatchesExpectation {
      self.expect_checked_type(expectation, Primitive(Unit), loc)
    } else {
      checked.expectation_match
    }
    return checked.synthesis.with_expectation_match(expectation_match)
  }
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
    return undetermined_checked_expression(expectation.type_)
  }
  let checked_then_branch = self.check_checked_expr_with_expectation(
    scope, then_branch, expectation,
  )
  guard self.require_checked_expression(
      checked_then_branch.synthesis,
      loc,
      "if then branch",
    )
    is Some(then_branch) else {
    return undetermined_checked_expression(expectation.type_)
  }
  let checked_else_branch = self.check_checked_expr_with_expectation(
    scope,
    else_branch,
    { ..expectation, type_: checked_then_branch.synthesis.type_ },
  )
  guard self.require_checked_expression(
      checked_else_branch.synthesis,
      loc,
      "if else branch",
    )
    is Some(else_branch) else {
    return undetermined_checked_expression(expectation.type_)
  }
  checked_expression_with_effect(
    If(condition~, then_branch~, else_branch~, type_=expectation.type_, loc~),
    expectation.type_,
    effect_union([
      checked_condition.effect,
      checked_then_branch.synthesis.effect,
      checked_else_branch.synthesis.effect,
    ]),
  ).with_expectation_match(
    merge_checked_expectation_match(
      checked_then_branch.expectation_match,
      checked_else_branch.expectation_match,
    ),
  )
}

///|
fn SemanticChecker::synthesize_checked_if(
  self : SemanticChecker,
  scope : TypeScope,
  condition : @desugar.DesugaredExpr,
  then_branch : @desugar.DesugaredExpr,
  else_branch : @desugar.DesugaredExpr?,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard else_branch is Some(else_branch) else {
    return self.check_else_omitting_if(scope, condition, then_branch, loc).synthesis
  }
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
fn SemanticChecker::check_else_omitting_if(
  self : SemanticChecker,
  scope : TypeScope,
  condition : @desugar.DesugaredExpr,
  then_branch : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  let checked_condition = self.check_checked_expr(
    scope,
    condition,
    Primitive(Bool),
  )
  guard self.require_checked_expression(checked_condition, loc, "if condition")
    is Some(condition) else {
    return undetermined_checked_expression(Primitive(Unit))
  }
  let unit_type : @types.Type = Primitive(Unit)
  let checked_then_branch = self.check_checked_expr_with_expectation(
    scope,
    then_branch,
    checked_expectation(unit_type).for_else_omitting_conditional(),
  )
  guard self.require_checked_expression(
      checked_then_branch.synthesis,
      loc,
      "if then branch",
    )
    is Some(then_branch_expr) else {
    return undetermined_checked_expression(unit_type)
  }
  let else_loc : SourceSpan = {
    start_offset: loc.end_offset,
    end_offset: loc.end_offset,
    start_line: loc.end_line,
    start_column: loc.end_column,
    end_line: loc.end_line,
    end_column: loc.end_column,
  }
  let else_branch : @checked.CheckedExpr = Literal(
    literal=Unit,
    type_=unit_type,
    loc=else_loc,
  )
  checked_expression_with_effect(
    If(
      condition~,
      then_branch=then_branch_expr,
      else_branch~,
      type_=unit_type,
      loc~,
    ),
    unit_type,
    effect_union([
      checked_condition.effect,
      checked_then_branch.synthesis.effect,
    ]),
  ).with_expectation_match(checked_then_branch.expectation_match)
}

///|
fn SemanticChecker::check_checked_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  expectation : CheckedExpectation,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  let checked_scrutinee = self.synthesize_checked_expr(scope, scrutinee)
  guard self.require_checked_expression(
      checked_scrutinee,
      scrutinee.loc(),
      "match scrutinee",
    )
    is Some(scrutinee) else {
    return undetermined_checked_expression(expectation.type_)
  }
  let matrix = PatternMatrix::PatternMatrix()
  let checked_arms : Array[@checked.CheckedMatchArm] = []
  let effects = [checked_scrutinee.effect]
  let mut complete = true
  let mut expectation_match = MatchesExpectation
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
    let checked_body = self.check_checked_expr_with_expectation(
      arm_scope,
      arm.body,
      expectation.with_hidden_type_parameters(opened_type_parameters),
    )
    expectation_match = merge_checked_expectation_match(
      expectation_match,
      checked_body.expectation_match,
    )
    match
      self.require_checked_expression(
        checked_body.synthesis,
        arm.body.loc(),
        "match arm",
      ) {
      Some(body) => {
        effects.push(checked_body.synthesis.effect)
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
  matrix.report_computation_error(self.diagnostics, loc)
  if complete {
    checked_expression_with_effect(
      Match(scrutinee~, arms=checked_arms, type_=expectation.type_, loc~),
      expectation.type_,
      effect_union(effects),
    ).with_expectation_match(expectation_match)
  } else {
    undetermined_checked_expression(expectation.type_)
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
  matrix.report_computation_error(self.diagnostics, loc)
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
  expectation : CheckedExpectation,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  // Checked call in checking mode first synthesizes the call under the expected
  // result type so generic callees can use that adjacent result information,
  // then enforces the ordinary expected/actual equality.
  let synthesis = self.synthesize_checked_call_with_expected(
    scope,
    callee,
    arguments,
    Some(expectation.type_),
    loc,
  )
  synthesis.with_expectation_match(
    self.expect_checked_type(expectation, synthesis.type_, loc),
  )
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
  let body_scope = function_body_scope(
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
  expectation : CheckedExpectation,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  match expectation.type_ {
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
        return undetermined_checked_expression(expectation.type_)
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
        { ..expectation, type_: expected_body.substitute(substitution) },
        loc,
      )
      guard checked.synthesis.expression
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
      ).with_expectation_match(checked.expectation_match)
    }
    Function(expected_parameters, expected_result, expected_effect) => {
      if !type_parameters.is_empty() {
        self.report_application_arity("generic function arity", loc)
        return undetermined_checked_expression(expectation.type_)
      }
      self
      .check_monomorphic_function_literal(
        scope,
        parameters,
        return_type,
        effect,
        body,
        expected_parameters,
        expected_result,
        Some(expected_effect),
        expectation.hidden_type_parameters,
        loc,
      )
      .with_expectation_match(MatchesExpectation)
    }
    Error =>
      checked_expression_none_reported(Error).with_expectation_match(
        MatchesExpectation,
      )
    _ => {
      let synthesis = self.synthesize_checked_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, loc,
      )
      synthesis.with_expectation_match(
        self.expect_checked_type(expectation, synthesis.type_, loc),
      )
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
  name_loc : SourceSpan,
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
        name_loc,
        loc,
      )
    Deferred(_) =>
      match
        decompose_nominal_or_report(
          self.diagnostics,
          checked_base.type_,
          loc,
          context="field receiver type",
        ) {
        Nominal(symbol, _) => {
          guard self.declarations.checked_struct(symbol) is Some(declaration) &&
            declaration.field_named(name) is Some(field_declaration) else {
            self.diagnostics.push({ kind: UnknownField(name~), loc })
            return checked_expression_none_reported(Error)
          }
          self.checked_field_from_symbol(
            base,
            checked_base.type_,
            checked_base.effect,
            field_declaration.symbol,
            name,
            name_loc,
            loc,
          )
        }
        NotNominal =>
          if checked_base.type_ is Error {
            checked_expression_none_reported(Error)
          } else {
            self.diagnostics.push({ kind: NotAStruct(checked_base.type_), loc })
            checked_expression_none_reported(Error)
          }
        ComputationFailed => checked_expression_none_reported(Error)
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
  name_loc : SourceSpan,
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
    Field(base~, field~, name~, name_loc~, type_~, loc~),
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
