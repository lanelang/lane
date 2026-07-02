///|
fn SemanticChecker::synthesize_call(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> @types.Type {
  // Gamma |- callee => (P_1, ..., P_n) -> R
  // Gamma |- a_i <= P_i
  // ---
  // Gamma |- callee(a_1, ..., a_n) => R
  //
  // In synthesis mode the result type must come from the callee.
  let callee_type = self.synthesize_expr(scope, callee)
  let arguments = self.prepare_direct_call_arguments(
    scope,
    callee,
    callee_type,
    arguments,
    None,
    loc,
  )
  self.synthesize_callable_call(scope, callee_type, arguments, None, loc)
}

///|
fn SemanticChecker::synthesize_callable_call(
  self : SemanticChecker,
  scope : TypeScope,
  callee_type : @types.Type,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> @types.Type {
  match callee_type {
    Function(parameters, result, _) => {
      self.check_call_arguments(scope, parameters, arguments, loc)
      result
    }
    Forall(type_parameters, body) => {
      guard self.instantiate_generic_callable(
          scope, type_parameters, body, arguments, expected_result, loc, true,
        )
        is Some(instantiated) else {
        return Error
      }
      self.check_call_arguments(scope, instantiated.parameters, arguments, loc)
      instantiated.result
    }
    Error => Error
    type_ => {
      self.diagnostics.push({ kind: NotCallable(type_), loc })
      Error
    }
  }
}

///|
fn SemanticChecker::check_call(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  // Gamma |- callee(a_1, ..., a_n) => Actual
  // Actual = Expected
  // ---
  // Gamma |- callee(a_1, ..., a_n) <= Expected
  //
  if callee is Builtin(_, ..) {
    self.check_builtin_callee_call(scope, arguments, loc)
    return
  }
  let callee_type = self.synthesize_expr(scope, callee)
  let arguments = self.prepare_direct_call_arguments(
    scope,
    callee,
    callee_type,
    arguments,
    Some(expected),
    loc,
  )
  let actual = self.synthesize_callable_call(
    scope,
    callee_type,
    arguments,
    Some(expected),
    loc,
  )
  self.expect_type(expected, actual, loc)
}

///|
fn SemanticChecker::check_builtin_callee_call(
  self : SemanticChecker,
  scope : TypeScope,
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> Unit {
  // `builtin` remains opaque. In callee position, the surrounding checked call
  // supplies the result type while each argument supplies its own local type.
  // This derives the adjacent function type expected by the unsafe builtin:
  //
  //   Gamma |- a_i => P_i
  //   Gamma |- builtin(s) <= (P_1, ..., P_n) -> Expected
  //   Gamma |- a_i <= P_i
  //   ---------------------------------------------------
  //   Gamma |- builtin(s)(a_1, ..., a_n) <= Expected
  let parameters = []
  for argument in arguments {
    match argument {
      Positional(expression) =>
        parameters.push(self.synthesize_expr(scope, expression))
      Named(name~, value~, loc~) => {
        self.diagnostics.push({
          kind: CannotInferExpression(
            label="invalid named argument " + name,
            reason=Generic,
          ),
          loc,
        })
        parameters.push(self.synthesize_expr(scope, value))
      }
    }
  }
  self.check_call_arguments(scope, parameters, arguments, loc)
}

///|
fn SemanticChecker::check_call_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  parameters : Array[@types.Type],
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> Unit {
  // Gamma |- f => (P_1, ..., P_n) -> R
  // Gamma |- a_i <= P_i
  // ---
  // Gamma |- f(a_1, ..., a_n) => R
  //
  // Argument checking is the direct-context step for calls: parameter types flow
  // down to each adjacent argument expression.
  if parameters.length() != arguments.length() {
    self.diagnostics.push({
      kind: CannotInferExpression(label="call arity", reason=CallArity),
      loc,
    })
    return
  }
  for index in 0..<parameters.length() {
    self.check_call_argument(scope, arguments[index], parameters[index])
  }
}

///|
fn SemanticChecker::check_call_argument(
  self : SemanticChecker,
  scope : TypeScope,
  argument : @desugar.DesugaredCallArgument,
  parameter : @types.Type,
) -> Unit {
  match argument {
    Positional(expression) => self.check_expr(scope, expression, parameter)
    Named(name~, value~, loc~) => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          label="invalid named argument " + name,
          reason=Generic,
        ),
        loc,
      })
      self.check_expr(scope, value, parameter)
    }
  }
}
