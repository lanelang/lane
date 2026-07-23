///|
fn checked_function_literal_parameter(
  parameter : @resolve.ResolvedFunctionLiteralParameter,
  type_ : @types.Type,
) -> @checked.CheckedValueParameter {
  {
    symbol: parameter.symbol,
    is_auto: false,
    is_offered: parameter.is_offered,
    name: parameter.name,
    name_loc: parameter.name_loc,
    type_,
    loc: parameter.loc,
  }
}

///|
fn SemanticChecker::synthesize_function_literal_parameters(
  self : SemanticChecker,
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
) -> (Array[@types.Type], Array[@checked.CheckedValueParameter]) {
  let parameter_types = []
  let checked_parameters = []
  for parameter in parameters {
    let type_ = match parameter.type_annotation {
      Some(type_annotation) => self.check_type(type_annotation)
      None => {
        self.diagnostics.push({
          kind: FunctionLiteralParameterNeedsAnnotation(
            name=Some(parameter.name),
          ),
          loc: parameter.loc,
        })
        Error
      }
    }
    parameter_types.push(type_)
    checked_parameters.push(
      checked_function_literal_parameter(parameter, type_),
    )
  }
  (parameter_types, checked_parameters)
}

///|
fn SemanticChecker::checked_function_literal_parameters_from_expected(
  self : SemanticChecker,
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  expected_parameters : Array[@types.Type],
) -> Array[@checked.CheckedValueParameter] {
  let checked_parameters = []
  for index in 0..<parameters.length() {
    let parameter = parameters[index]
    let type_ = expected_parameters[index]
    if parameter.type_annotation is Some(type_annotation) {
      self.expect_type(type_, self.check_type(type_annotation), parameter.loc)
    }
    checked_parameters.push(
      checked_function_literal_parameter(parameter, type_),
    )
  }
  checked_parameters
}

///|
fn SemanticChecker::check_monomorphic_function_literal(
  self : SemanticChecker,
  scope : TypeScope,
  parameters : Array[@resolve.ResolvedFunctionLiteralParameter],
  return_type : @resolve.ResolvedType?,
  effect : @resolve.ResolvedEffectTerm?,
  body : @desugar.DesugaredExpr,
  expected_parameters : Array[@types.Type],
  expected_result : @types.Type,
  expected_effect : @types.Effect?,
  hidden_type_parameters : Array[TypeParameterId],
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let fallback_type = match expected_effect {
    Some(effect) =>
      @types.Type::Function(expected_parameters, expected_result, effect)
    None => Error
  }
  if expected_parameters.length() != parameters.length() {
    self.report_application_arity("function arity", loc)
    return checked_expression_none_reported(fallback_type)
  }
  let checked_parameters = self.checked_function_literal_parameters_from_expected(
    parameters, expected_parameters,
  )
  if return_type is Some(type_annotation) {
    self.expect_type(expected_result, self.check_type(type_annotation), loc)
  }
  let checked_effect = match (expected_effect, effect) {
    (Some(expected), Some(effect_annotation)) => {
      self.expect_effect(expected, self.check_effect(effect_annotation), loc)
      Some(expected)
    }
    (Some(expected), None) => Some(expected)
    (None, Some(effect_annotation)) =>
      Some(self.check_effect(effect_annotation))
    (None, None) => None
  }
  let body_scope = function_body_scope(
    scope.without_expected_effect(),
    [],
    checked_parameters,
  )
  let checked_body = self.check_checked_expr_with_expectation(
    match checked_effect {
      Some(effect) => body_scope.with_expected_effect(effect)
      None => body_scope
    },
    body,
    checked_expectation(expected_result).with_hidden_type_parameters(
      hidden_type_parameters,
    ),
  )
  let inferred_effect = match checked_effect {
    Some(effect) => {
      self.expect_effect(effect, checked_body.effect, body.loc())
      effect
    }
    None => checked_body.effect
  }
  let function_type = @types.Type::Function(
    expected_parameters, expected_result, inferred_effect,
  )
  guard self.require_checked_expression(
      checked_body,
      body.loc(),
      "function body",
    )
    is Some(body) else {
    return checked_expression_none_reported(function_type)
  }
  checked_expression(
    FunctionLiteral(
      type_parameters=[],
      parameters=checked_parameters,
      return_type=expected_result,
      body~,
      type_=function_type,
      loc~,
    ),
    function_type,
  )
}
