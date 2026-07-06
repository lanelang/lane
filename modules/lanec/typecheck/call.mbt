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
  let diagnostic_count = self.diagnostics.length()
  let arguments = self.prepare_direct_call_arguments(
    scope,
    callee,
    callee_type,
    arguments,
    None,
    loc,
  )
  if self.diagnostics.length() != diagnostic_count {
    return Error
  }
  self.synthesize_callable_call(
    scope,
    callee_type,
    arguments,
    None,
    generic_callable_inference_label(callee),
    loc,
  )
}

///|
fn SemanticChecker::synthesize_callable_call(
  self : SemanticChecker,
  scope : TypeScope,
  callee_type : @types.Type,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  inference_label : String,
  loc : SourceSpan,
) -> @types.Type {
  match callee_type {
    Function(parameters, result, _) => {
      self.check_call_arguments(scope, parameters, arguments, loc)
      result
    }
    Forall(type_parameters, body) => {
      guard self.instantiate_generic_callable(
          scope, type_parameters, body, arguments, expected_result, inference_label,
          loc, true,
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
  let diagnostic_count = self.diagnostics.length()
  let arguments = self.prepare_direct_call_arguments(
    scope,
    callee,
    callee_type,
    arguments,
    Some(expected),
    loc,
  )
  if self.diagnostics.length() != diagnostic_count {
    return
  }
  let actual = self.synthesize_callable_call(
    scope,
    callee_type,
    arguments,
    Some(expected),
    generic_callable_inference_label(callee),
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
      Positional(value~, ..) =>
        parameters.push(self.synthesize_expr(scope, value))
      Named(name~, value~, loc~) => {
        self.diagnostics.push({ kind: InvalidNamedBuiltinArgument(name~), loc })
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
  if !self.check_application_arity(
      parameters.length(),
      arguments.length(),
      loc,
      true,
    ) {
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
    Positional(value~, ..) => self.check_expr(scope, value, parameter)
    Named(name~, value~, loc~) => {
      self.diagnostics.push({ kind: InvalidNamedArgument(name~), loc })
      self.check_expr(scope, value, parameter)
    }
  }
}
