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
  // In synthesis mode the result type must come from the callee. Candidate
  // callees are selected by checking the adjacent arguments only.
  if callee is Var(name~, reference~, loc=callee_loc) &&
    reference is Candidates(candidates~, ..) {
    return self.synthesize_candidate_call(
      scope, name, candidates, arguments, callee_loc,
    )
  }
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
    Function(parameters, result) => {
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
fn SemanticChecker::synthesize_candidate_call(
  self : SemanticChecker,
  scope : TypeScope,
  name : String,
  candidates : Array[@resolve.ResolvedValueReference],
  arguments : Array[@desugar.DesugaredCallArgument],
  loc : SourceSpan,
) -> @types.Type {
  let typed_candidates = self.typed_candidates(scope, candidates, name, loc)
  match
    self.select_callable_by_local_typing(
      scope,
      name,
      typed_candidates,
      arguments,
      None,
      loc,
    ) {
    Selected(candidate) => candidate.result
    Ambiguous(name~, ..) => {
      self.report_ambiguous_value_reference(name, loc)
      Error
    }
    NoMatch(name~) => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          "no matching callable value reference " + name,
        ),
        loc,
      })
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
  // For open candidate callees, Expected also filters the candidate result type
  // before arguments are checked under the candidate's parameter types.
  if callee is Var(name~, reference~, loc=callee_loc) &&
    reference is Candidates(candidates~, ..) {
    self.check_candidate_call(
      scope, name, candidates, arguments, expected, callee_loc,
    )
    return
  }
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
          kind: CannotInferExpression("invalid named argument " + name),
          loc,
        })
        parameters.push(self.synthesize_expr(scope, value))
      }
    }
  }
  self.check_call_arguments(scope, parameters, arguments, loc)
}

///|
fn SemanticChecker::check_candidate_call(
  self : SemanticChecker,
  scope : TypeScope,
  name : String,
  candidates : Array[@resolve.ResolvedValueReference],
  arguments : Array[@desugar.DesugaredCallArgument],
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  let typed_candidates = self.typed_candidates(scope, candidates, name, loc)
  match
    self.select_callable_by_local_typing(
      scope,
      name,
      typed_candidates,
      arguments,
      Some(expected),
      loc,
    ) {
    Selected(candidate) =>
      self.check_call_arguments(scope, candidate.parameters, arguments, loc)
    Ambiguous(name~, ..) => self.report_ambiguous_value_reference(name, loc)
    NoMatch(name~) =>
      self.diagnostics.push({
        kind: CannotInferExpression(
          "no matching callable value reference " + name,
        ),
        loc,
      })
  }
}

///|
fn SemanticChecker::select_callable_by_local_typing(
  self : SemanticChecker,
  scope : TypeScope,
  name : String,
  candidates : Array[@candidates.TypedCandidate],
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> @candidates.CallableSelection {
  // For each open candidate c_i:
  //
  //   Gamma |- c_i => (P_1, ..., P_n) -> R
  //   Gamma |- a_1 <= P_1
  //   ...
  //   Gamma |- a_n <= P_n
  //   R matches ExpectedResult, when a result context exists
  //
  // A candidate is viable only if this local derivation succeeds. This is the
  // Lane2 overload layer over LTI: it tries complete local derivations and then
  // exposes 0/1/many viable candidates instead of choosing implicitly.
  let viable = []
  for candidate in candidates {
    if self.viable_callable_candidate(
        scope, candidate, arguments, expected_result, loc,
      )
      is Some(callable) {
      viable.push(callable)
    }
  }
  match viable.length() {
    0 => NoMatch(name~)
    1 => Selected(viable[0])
    _ => Ambiguous(name~, candidates=viable)
  }
}

///|
fn SemanticChecker::viable_callable_candidate(
  self : SemanticChecker,
  scope : TypeScope,
  candidate : @candidates.TypedCandidate,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> @candidates.CallableCandidate? {
  match candidate.type_ {
    Function(parameters, result) => {
      if !self.result_matches_expected(result, expected_result) {
        return None
      }
      if parameters.length() != arguments.length() {
        return None
      }
      // Candidate probing must not leak diagnostics. The selected candidate is
      // checked again on the real path, so only final derivations produce user
      // visible errors.
      let checkpoint = self.diagnostic_checkpoint()
      self.check_call_arguments(scope, parameters, arguments, loc)
      let viable = self.diagnostics.length() == checkpoint.length
      self.rollback_diagnostics(checkpoint)
      if viable {
        Some({
          reference: candidate.reference,
          type_arguments: [],
          parameters,
          result,
        })
      } else {
        None
      }
    }
    Forall(type_parameters, body) => {
      guard self.instantiate_generic_callable(
          scope, type_parameters, body, arguments, expected_result, loc, false,
        )
        is Some(instantiated) else {
        return None
      }
      if !self.result_matches_expected(instantiated.result, expected_result) {
        return None
      }
      let checkpoint = self.diagnostic_checkpoint()
      self.check_call_arguments(scope, instantiated.parameters, arguments, loc)
      let viable = self.diagnostics.length() == checkpoint.length
      self.rollback_diagnostics(checkpoint)
      if viable {
        Some({
          reference: candidate.reference,
          type_arguments: instantiated.type_arguments,
          parameters: instantiated.parameters,
          result: instantiated.result,
        })
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn SemanticChecker::result_matches_expected(
  self : SemanticChecker,
  result : @types.Type,
  expected : @types.Type?,
) -> Bool {
  ignore(self)
  if expected is Some(expected) {
    type_matches(expected, result)
  } else {
    true
  }
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
    self.diagnostics.push({ kind: CannotInferExpression("call arity"), loc })
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
        kind: CannotInferExpression("invalid named argument " + name),
        loc,
      })
      self.check_expr(scope, value, parameter)
    }
  }
}
