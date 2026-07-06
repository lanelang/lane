///|
fn SemanticChecker::synthesize_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  effect : @resolve.ResolvedEffectTerm?,
  body : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> @types.Type {
  // Function-literal synthesis has no adjacent function type:
  //
  //   Gamma, x_i : P_i |- body => R ! BodyEff
  //   AnnotatedEff = written effect or {}
  //   BodyEff <= AnnotatedEff
  //   ---------------------------------------
  //   Gamma |- fn(x_i : P_i...) { body } => (P_i...) -> R ! AnnotatedEff
  //
  // Therefore every parameter must be annotated. If a caller wants omitted
  // parameter annotations, the expression must be checked against an expected
  // function type instead.
  ignore(loc)
  let parameter_types = []
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
    } else {
      self.diagnostics.push({
        kind: FunctionLiteralParameterNeedsAnnotation(name=Some(parameter.name)),
        loc: parameter.loc,
      })
      body_scope.bind(parameter.symbol, Error)
      if parameter.is_offered {
        self.offer_symbol(
          body_scope.offers,
          parameter.symbol,
          Error,
          parameter.loc,
        )
      }
      parameter_types.push(Error)
    }
  }
  let (result, actual_effect) = if return_type is Some(type_annotation) {
    let type_ = self.check_type(type_annotation)
    let checked_body = self.check_checked_expr(body_scope, body, type_)
    (type_, checked_body.effect)
  } else {
    let checked_body = self.synthesize_checked_expr(body_scope, body)
    (checked_body.type_, checked_body.effect)
  }
  let checked_effect = match effect {
    Some(effect) => self.check_effect(effect)
    None => Empty
  }
  self.expect_effect(checked_effect, actual_effect, body.loc())
  let type_ = @types.Type::Function(parameter_types, result, checked_effect)
  if type_parameters.is_empty() {
    type_
  } else {
    Forall(check_type_parameters(self.diagnostics, type_parameters), type_)
  }
}

///|
fn SemanticChecker::check_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  effect : @resolve.ResolvedEffectTerm?,
  body : @desugar.DesugaredExpr,
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  match expected {
    Forall(expected_parameters, expected_body) =>
      self.check_generic_function_literal(
        scope, type_parameters, expected_parameters, expected_body, parameters, return_type,
        effect, body, loc,
      )
    Function(expected_parameters, expected_result, expected_effect) => {
      if !type_parameters.is_empty() {
        self.report_application_arity("generic function arity", loc)
        return
      }
      // Function-literal checking:
      //
      //   Gamma, x_1 : P_1, ..., x_n : P_n |- body <= R
      //   BodyEff <= ExpectedEff
      //   ------------------------------------------------
      //   Gamma |- fn(x_1, ..., x_n) { body } <= (P_i...) -> R ! ExpectedEff
      //
      // This is the core direct-context rule for anonymous functions: omitted
      // parameter annotations are recovered only from the adjacent expected
      // function type.
      if expected_parameters.length() != parameters.length() {
        self.report_application_arity("function arity", loc)
        return
      }
      let body_scope = scope.copy()
      for index in 0..<parameters.length() {
        let parameter = parameters[index]
        if parameter.type_annotation is Some(type_annotation) {
          self.expect_type(
            expected_parameters[index],
            self.check_type(type_annotation),
            parameter.loc,
          )
        }
        body_scope.bind(parameter.symbol, expected_parameters[index])
        if parameter.is_offered {
          self.offer_symbol(
            body_scope.offers,
            parameter.symbol,
            expected_parameters[index],
            parameter.loc,
          )
        }
      }
      if return_type is Some(type_annotation) {
        self.expect_type(expected_result, self.check_type(type_annotation), loc)
      }
      if effect is Some(effect) {
        self.expect_effect(expected_effect, self.check_effect(effect), loc)
      }
      let checked_body = self.check_checked_expr(
        body_scope, body, expected_result,
      )
      self.expect_effect(expected_effect, checked_body.effect, body.loc())
    }
    Error => ()
    _ => {
      let actual = self.synthesize_function_literal(
        scope, type_parameters, parameters, return_type, effect, body, loc,
      )
      self.expect_type(expected, actual, loc)
    }
  }
}

///|
fn SemanticChecker::check_generic_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  expected_parameters : Array[@types.TypeParameter],
  expected_body : @types.Type,
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  effect : @resolve.ResolvedEffectTerm?,
  body : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> Unit {
  // Forall introduction is local to the function literal:
  //
  //   Gamma, A_i, x_j : P_j[A] |- body <= R[A]
  //   ------------------------------------------
  //   Gamma |- fn[A_i](x_j...) { body } <= forall A_i. (P_j...) -> R
  //
  // The literal must declare the generic parameters it introduces; checking
  // only aligns the expected forall parameters with those local parameters.
  ignore(check_type_parameters(self.diagnostics, type_parameters))
  if type_parameters.length() != expected_parameters.length() {
    self.report_application_arity("generic function arity", loc)
    return
  }
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for index in 0..<expected_parameters.length() {
    substitution.insert(
      expected_parameters[index].id,
      Parameter(type_parameters[index].symbol),
    )
  }
  self.check_function_literal(
    scope,
    [],
    parameters,
    return_type,
    effect,
    body,
    expected_body.substitute(substitution),
    loc,
  )
}
