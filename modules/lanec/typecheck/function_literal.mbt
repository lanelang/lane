///|
fn SemanticChecker::synthesize_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  body : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> @types.Type {
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
        kind: CannotInferExpression("function literal parameter"),
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
  let result = if return_type is Some(type_annotation) {
    let type_ = self.check_type(type_annotation)
    self.check_expr(body_scope, body, type_)
    type_
  } else {
    self.synthesize_expr(body_scope, body)
  }
  let type_ = @types.Type::Function(parameter_types, result)
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
  body : @desugar.DesugaredExpr,
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  match expected {
    Forall(expected_parameters, expected_body) =>
      self.check_generic_function_literal(
        scope, type_parameters, expected_parameters, expected_body, parameters, return_type,
        body, loc,
      )
    Function(expected_parameters, expected_result) => {
      if !type_parameters.is_empty() {
        self.diagnostics.push({
          kind: CannotInferExpression("generic function arity"),
          loc,
        })
        return
      }
      // Gamma, x_1 : P_1, ..., x_n : P_n |- body <= R
      // ---
      // Gamma |- fn(x_1, ..., x_n) { body } <= (P_1, ..., P_n) -> R
      //
      // This is the core direct-context rule for anonymous functions: omitted
      // parameter annotations are recovered only from the adjacent expected
      // function type.
      if expected_parameters.length() != parameters.length() {
        self.diagnostics.push({
          kind: CannotInferExpression("function arity"),
          loc,
        })
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
      self.check_expr(body_scope, body, expected_result)
    }
    Error => ()
    _ => {
      let actual = self.synthesize_function_literal(
        scope, type_parameters, parameters, return_type, body, loc,
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
  body : @desugar.DesugaredExpr,
  loc : SourceSpan,
) -> Unit {
  // Forall introduction is local to the function literal. The literal must
  // declare the generic parameters it introduces; checking only aligns the
  // expected forall parameters with those local parameters.
  ignore(check_type_parameters(self.diagnostics, type_parameters))
  if type_parameters.length() != expected_parameters.length() {
    self.diagnostics.push({
      kind: CannotInferExpression("generic function arity"),
      loc,
    })
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
    body,
    expected_body.substitute(substitution),
    loc,
  )
}
