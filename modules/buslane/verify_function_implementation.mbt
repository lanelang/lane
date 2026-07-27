///|
fn VerifyContext::function_implementation_matches(
  self : VerifyContext,
  implementation : Type,
  declaration : Type,
) -> Bool {
  self.function_implementation_matches_with(
    {
      bindings: [],
      binders_compatible: fn(actual, expected) {
        self.function_implementation_binders_compatible(actual, expected)
      },
    },
    implementation.normalize(),
    declaration.normalize(),
  )
}

///|
fn VerifyContext::function_implementation_matches_with(
  self : VerifyContext,
  context : AlphaContext,
  implementation : Type,
  declaration : Type,
) -> Bool {
  match (implementation, declaration) {
    (
      Function(actual_parameters, actual_result, actual_effect),
      Function(expected_parameters, expected_result, expected_effect),
    ) =>
      same_length_alpha_equal(context, actual_parameters, expected_parameters) &&
      alpha_equal_with(context, actual_result, expected_result) &&
      effect_is_subeffect_with(context, actual_effect, expected_effect)
    (
      Forall(actual_parameters, actual_body),
      Forall(expected_parameters, expected_body),
    ) =>
      match context.with_binders(actual_parameters, expected_parameters) {
        Some(next) =>
          self.function_implementation_matches_with(
            next, actual_body, expected_body,
          )
        None => false
      }
    _ => false
  }
}

///|
fn VerifyContext::function_implementation_binders_compatible(
  self : VerifyContext,
  actual : TypeParameterId,
  expected : TypeParameterId,
) -> Bool {
  guard self.program.metadata.type_parameter_info(actual) is Some(actual_info) else {
    return false
  }
  guard self.program.metadata.type_parameter_info(expected)
    is Some(expected_info) else {
    return false
  }
  actual_info.kind == expected_info.kind
}
