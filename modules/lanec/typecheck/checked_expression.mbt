///|
priv struct CheckedExpressionSynthesis {
  expression : @checked.CheckedExpr?
  type_ : @types.Type
  missing_reported : Bool
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
  // Only desugared forms that can use direct expected context are constructed
  // here. The remaining forms continue to use the existing type-only checker
  // until their checked-node rules are moved over one by one.
  match expression {
    Builtin(name, loc~) =>
      // `builtin` is unsafe and opaque to the checker. The adjacent expected
      // type is the whole type of the resulting checked node.
      checked_expression(UnsafeBuiltin(name~, type_=expected, loc~), expected)
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
    StructLiteral(type_name~, type_arguments~, fields~, loc~) => {
      let checked = self.synthesize_checked_struct_literal(
        scope,
        type_name,
        type_arguments,
        fields,
        Some(expected),
        loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    VariantCall(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      reference~,
      arguments~,
      loc~
    ) => {
      let checked = self.synthesize_checked_variant_call(
        scope,
        type_name,
        type_arguments,
        variant,
        variant_type_arguments,
        reference,
        arguments,
        Some(expected),
        loc,
      )
      self.expect_type(expected, checked.type_, loc)
      checked
    }
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, loc~) =>
      self.check_checked_function_literal(
        scope, type_parameters, parameters, return_type, body, expected, loc,
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
  // This initial slice covers source forms whose checked node does not need a
  // recursive checked subtree. Compound expressions still return their
  // synthesized type through the existing checker and no checked node.
  match expression {
    Literal(literal~, loc~) => {
      let type_ = literal.type_()
      checked_expression(
        Literal(literal=self.checked_literal(literal, loc), type_~, loc~),
        type_,
      )
    }
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, loc~) =>
      self.synthesize_checked_function_literal(
        scope, type_parameters, parameters, return_type, body, loc,
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
    StructLiteral(type_name~, type_arguments~, fields~, loc~) =>
      self.synthesize_checked_struct_literal(
        scope,
        type_name,
        type_arguments,
        fields,
        None,
        loc,
      )
    VariantCall(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.synthesize_checked_variant_call(
        scope,
        type_name,
        type_arguments,
        variant,
        variant_type_arguments,
        reference,
        arguments,
        None,
        loc,
      )
    Builtin(_, loc~) => {
      self.diagnostics.push({ kind: CannotInferExpression("builtin"), loc })
      checked_expression_none_reported(Error)
    }
    _ => checked_expression_none(self.synthesize_expr(scope, expression))
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
  let mut complete = true
  for item in items {
    match item {
      Let(declaration) =>
        match self.check_checked_local_let(next_scope, declaration) {
          Some(declaration) => checked_items.push(Let(declaration))
          None => complete = false
        }
      Function(declaration) =>
        match self.check_checked_local_function(next_scope, declaration) {
          Some(declaration) => checked_items.push(Function(declaration))
          None => complete = false
        }
      Offer(declaration) =>
        match self.check_checked_local_offer(next_scope, declaration) {
          Some(declaration) => checked_items.push(Let(declaration))
          None => complete = false
        }
      PatternLet(declaration) =>
        match self.check_checked_local_pattern_let(next_scope, declaration) {
          Some(declaration) => checked_items.push(PatternLet(declaration))
          None => complete = false
        }
    }
  }
  let checked_result = self.check_checked_expr(next_scope, result, expected)
  guard self.require_checked_expression(
      checked_result,
      result.loc(),
      "block result",
    )
    is Some(result) else {
    return checked_expression_none_reported(expected)
  }
  if complete {
    checked_expression(
      Block(items=checked_items, result~, type_=expected, loc~),
      expected,
    )
  } else {
    checked_expression_none_reported(expected)
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
  let condition = self.check_checked_expr(scope, condition, Primitive(Bool))
  guard self.require_checked_expression(condition, loc, "if condition")
    is Some(condition) else {
    return checked_expression_none_reported(expected)
  }
  let then_branch = self.check_checked_expr(scope, then_branch, expected)
  guard self.require_checked_expression(then_branch, loc, "if then branch")
    is Some(then_branch) else {
    return checked_expression_none_reported(expected)
  }
  let else_branch = self.check_checked_expr(scope, else_branch, expected)
  guard self.require_checked_expression(else_branch, loc, "if else branch")
    is Some(else_branch) else {
    return checked_expression_none_reported(expected)
  }
  checked_expression(
    If(condition~, then_branch~, else_branch~, type_=expected, loc~),
    expected,
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
  let condition = self.check_checked_expr(scope, condition, Primitive(Bool))
  guard self.require_checked_expression(condition, loc, "if condition")
    is Some(condition) else {
    return checked_expression_none_reported(Error)
  }
  let then_branch = self.synthesize_checked_expr(scope, then_branch)
  guard self.require_checked_expression(then_branch, loc, "if then branch")
    is Some(then_branch_expr) else {
    return checked_expression_none_reported(then_branch.type_)
  }
  let type_ = then_branch.type_
  let else_branch = self.check_checked_expr(scope, else_branch, type_)
  guard self.require_checked_expression(else_branch, loc, "if else branch")
    is Some(else_branch) else {
    return checked_expression_none_reported(type_)
  }
  checked_expression(
    If(condition~, then_branch=then_branch_expr, else_branch~, type_~, loc~),
    type_,
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
    let checked_body = self.check_checked_expr(arm_scope, arm.body, expected)
    match
      self.require_checked_expression(checked_body, arm.body.loc(), "match arm") {
      Some(body) => checked_arms.push({ pattern, body, loc: arm.loc })
      None => complete = false
    }
  }
  if !matrix.is_exhaustive(self.declarations, checked_scrutinee.type_) {
    self.diagnostics.push({
      kind: NonExhaustiveMatch(checked_scrutinee.type_),
      loc,
    })
  }
  if complete {
    checked_expression(
      Match(scrutinee~, arms=checked_arms, type_=expected, loc~),
      expected,
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
    self.check_hidden_type_escape(
      pattern.opened_type_parameters(),
      checked_body.type_,
      arm.body.loc(),
    )
    if has_result {
      self.expect_type(result, checked_body.type_, arm.loc)
    } else {
      result = checked_body.type_
      has_result = true
    }
    match
      self.require_checked_expression(checked_body, arm.body.loc(), "match arm") {
      Some(body) => checked_arms.push({ pattern, body, loc: arm.loc })
      None => complete = false
    }
  }
  if !has_result {
    self.diagnostics.push({ kind: CannotInferExpression("empty match"), loc })
  }
  if !matrix.is_exhaustive(self.declarations, checked_scrutinee.type_) {
    self.diagnostics.push({
      kind: NonExhaustiveMatch(checked_scrutinee.type_),
      loc,
    })
  }
  if complete {
    checked_expression(
      Match(scrutinee~, arms=checked_arms, type_=result, loc~),
      result,
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
  if callee is Builtin(name, loc=callee_loc) &&
    expected_result is Some(expected_result) {
    return self.synthesize_checked_builtin_callee_call(
      scope, name, arguments, expected_result, callee_loc, loc,
    )
  }
  let checked_callee = self.synthesize_checked_expr(scope, callee)
  guard self.require_checked_expression(
      checked_callee,
      callee.loc(),
      "call callee",
    )
    is Some(checked_callee_expr) else {
    return checked_expression_none_reported(Error)
  }
  let arguments = self.prepare_direct_call_arguments(
    scope,
    callee,
    checked_callee.type_,
    arguments,
    expected_result,
    loc,
  )
  match checked_callee.type_ {
    Function(parameters, result) => {
      guard self.check_checked_call_arguments(scope, parameters, arguments, loc)
        is Some(arguments) else {
        return checked_expression_none_reported(result)
      }
      checked_expression(
        Call(callee=checked_callee_expr, arguments~, type_=result, loc~),
        result,
      )
    }
    Forall(type_parameters, body) => {
      guard self.instantiate_generic_callable(
          scope, type_parameters, body, arguments, expected_result, loc, true,
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
        is Some(arguments) else {
        return checked_expression_none_reported(instantiated.result)
      }
      let callee = type_applied_callee(
        checked_callee_expr,
        instantiated.type_arguments,
        Function(instantiated.parameters, instantiated.result),
        loc,
      )
      checked_expression(
        Call(callee~, arguments~, type_=instantiated.result, loc~),
        instantiated.result,
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
fn SemanticChecker::synthesize_checked_builtin_callee_call(
  self : SemanticChecker,
  scope : TypeScope,
  name : String,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type,
  callee_loc : SourceSpan,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  // Checked expression construction for unsafe builtin calls mirrors the
  // type-only rule in `check_builtin_callee_call`: argument types are local
  // synthesized facts, and the surrounding call result is the direct expected
  // result type.
  let parameters = []
  let checked_arguments = []
  let mut complete = true
  for argument in arguments {
    match argument {
      Positional(expression) => {
        let checked = self.synthesize_checked_expr(scope, expression)
        parameters.push(checked.type_)
        match
          self.require_checked_expression(
            checked,
            expression.loc(),
            "builtin call argument",
          ) {
          Some(expression) => checked_arguments.push(expression)
          None => complete = false
        }
      }
      Named(name~, value~, loc~) => {
        self.diagnostics.push({
          kind: CannotInferExpression("invalid named argument " + name),
          loc,
        })
        let checked = self.synthesize_checked_expr(scope, value)
        parameters.push(checked.type_)
        match
          self.require_checked_expression(
            checked,
            value.loc(),
            "builtin call argument",
          ) {
          Some(expression) => checked_arguments.push(expression)
          None => complete = false
        }
      }
    }
  }
  if !complete {
    return checked_expression_none_reported(expected_result)
  }
  let callee = @checked.CheckedExpr::UnsafeBuiltin(
    name~,
    type_=Function(parameters, expected_result),
    loc=callee_loc,
  )
  checked_expression(
    Call(callee~, arguments=checked_arguments, type_=expected_result, loc~),
    expected_result,
  )
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
fn type_applied_callee(
  callee : @checked.CheckedExpr,
  type_arguments : Array[@types.Type],
  type_ : @types.Type,
  loc : SourceSpan,
) -> @checked.CheckedExpr {
  // Non-generic calls keep the value callee directly. Generic calls insert the
  // explicit checked type application inferred by local call checking.
  if type_arguments.is_empty() {
    callee
  } else {
    TypeApplication(callee~, arguments=type_arguments, type_~, loc~)
  }
}

///|
fn SemanticChecker::check_checked_call_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  parameters : Array[@types.Type],
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> Array[@checked.CheckedExpr]? {
  if parameters.length() != arguments.length() {
    self.diagnostics.push({ kind: CannotInferExpression("call arity"), loc })
    return None
  }
  let checked_arguments = []
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
      Some(argument) => checked_arguments.push(argument)
      None => complete = false
    }
  }
  if complete {
    Some(checked_arguments)
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
    Positional(expression) =>
      self.check_checked_expr(scope, expression, parameter)
    Named(name~, value~, loc~) => {
      self.diagnostics.push({
        kind: CannotInferExpression("invalid named argument " + name),
        loc,
      })
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
  body : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let parameter_types = []
  let checked_parameters : Array[@checked.CheckedValueParameter] = []
  let body_scope = scope.copy()
  for parameter in parameters {
    if parameter.type_annotation is Some(type_annotation) {
      let type_ = self.check_type(type_annotation)
      body_scope.bind(parameter.symbol, type_)
      if parameter.is_offered {
        self.offer_symbol(
          body_scope.offers,
          parameter.symbol,
          type_,
          parameter.loc,
        )
      }
      parameter_types.push(type_)
      checked_parameters.push({
        symbol: parameter.symbol,
        is_auto: false,
        is_offered: parameter.is_offered,
        name: parameter.name,
        type_,
        loc: parameter.loc,
      })
    } else {
      let type_ : @types.Type = Error
      self.diagnostics.push({
        kind: CannotInferExpression("function literal parameter"),
        loc: parameter.loc,
      })
      body_scope.bind(parameter.symbol, type_)
      if parameter.is_offered {
        self.offer_symbol(
          body_scope.offers,
          parameter.symbol,
          type_,
          parameter.loc,
        )
      }
      parameter_types.push(type_)
      checked_parameters.push({
        symbol: parameter.symbol,
        is_auto: false,
        is_offered: parameter.is_offered,
        name: parameter.name,
        type_,
        loc: parameter.loc,
      })
    }
  }
  let result_type = if return_type is Some(type_annotation) {
    self.check_type(type_annotation)
  } else {
    self.synthesize_expr(body_scope, body)
  }
  let checked_body = self.check_checked_expr(body_scope, body, result_type)
  guard self.require_checked_expression(
      checked_body,
      body.loc(),
      "function body",
    )
    is Some(body) else {
    return checked_expression_none_reported(
      Function(parameter_types, result_type),
    )
  }
  let function_type = @types.Type::Function(parameter_types, result_type)
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
  body : @desugar.DesugaredExpr,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match expected {
    Forall(expected_parameters, expected_body) => {
      let checked_type_parameters = check_type_parameters(
        self.diagnostics,
        type_parameters,
      )
      if type_parameters.length() != expected_parameters.length() {
        self.diagnostics.push({
          kind: CannotInferExpression("generic function arity"),
          loc,
        })
        return checked_expression_none_reported(expected)
      }
      let substitution = @types.TypeSubstitution::TypeSubstitution()
      for index in 0..<expected_parameters.length() {
        substitution.insert(
          expected_parameters[index].id,
          Parameter(type_parameters[index].symbol),
        )
      }
      let checked = self.check_checked_function_literal(
        scope,
        [],
        parameters,
        return_type,
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
    Function(expected_parameters, expected_result) => {
      if !type_parameters.is_empty() {
        self.diagnostics.push({
          kind: CannotInferExpression("generic function arity"),
          loc,
        })
        return checked_expression_none_reported(expected)
      }
      if expected_parameters.length() != parameters.length() {
        self.diagnostics.push({
          kind: CannotInferExpression("function arity"),
          loc,
        })
        return checked_expression_none_reported(expected)
      }
      let body_scope = scope.copy()
      let checked_parameters : Array[@checked.CheckedValueParameter] = []
      for index in 0..<parameters.length() {
        let parameter = parameters[index]
        let type_ = expected_parameters[index]
        if parameter.type_annotation is Some(type_annotation) {
          self.expect_type(
            type_,
            self.check_type(type_annotation),
            parameter.loc,
          )
        }
        body_scope.bind(parameter.symbol, type_)
        if parameter.is_offered {
          self.offer_symbol(
            body_scope.offers,
            parameter.symbol,
            type_,
            parameter.loc,
          )
        }
        checked_parameters.push({
          symbol: parameter.symbol,
          is_auto: false,
          is_offered: parameter.is_offered,
          name: parameter.name,
          type_,
          loc: parameter.loc,
        })
      }
      if return_type is Some(type_annotation) {
        self.expect_type(expected_result, self.check_type(type_annotation), loc)
      }
      let checked_body = self.check_checked_expr(
        body_scope, body, expected_result,
      )
      guard self.require_checked_expression(
          checked_body,
          body.loc(),
          "function body",
        )
        is Some(body) else {
        return checked_expression_none_reported(expected)
      }
      let type_ = @types.Type::Function(expected_parameters, expected_result)
      checked_expression(
        FunctionLiteral(
          type_parameters=[],
          parameters=checked_parameters,
          return_type=expected_result,
          body~,
          type_~,
          loc~,
        ),
        type_,
      )
    }
    Error => checked_expression_none_reported(Error)
    _ => {
      let checked = self.synthesize_checked_function_literal(
        scope, type_parameters, parameters, return_type, body, loc,
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
      self.checked_field_from_symbol(base, checked_base.type_, field, name, loc)
    Deferred(_) =>
      if checked_base.type_.decompose_nominal() is Some((symbol, _)) {
        guard self.source.symbols.field_named(symbol, name) is Some(field) else {
          self.diagnostics.push({ kind: UnknownField(name~), loc })
          return checked_expression_none_reported(Error)
        }
        self.checked_field_from_symbol(
          base,
          checked_base.type_,
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
  checked_expression(Field(base~, field~, name~, type_~, loc~), type_)
}

///|
fn checked_expression(
  expression : @checked.CheckedExpr,
  type_ : @types.Type,
) -> CheckedExpressionSynthesis {
  { expression: Some(expression), type_, missing_reported: false }
}

///|
fn checked_expression_none(type_ : @types.Type) -> CheckedExpressionSynthesis {
  { expression: None, type_, missing_reported: false }
}

///|
fn checked_expression_none_reported(
  type_ : @types.Type,
) -> CheckedExpressionSynthesis {
  { expression: None, type_, missing_reported: true }
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
          kind: CannotInferExpression("checked " + label),
          loc,
        })
      }
      None
    }
  }
}
