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
