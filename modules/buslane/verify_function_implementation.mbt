///|
priv enum BindingImplementationKind {
  OrdinaryBinding
  FunctionBinding
}

///|
fn Expr::is_direct_function_implementation(self : Expr) -> Bool {
  match self {
    Function(_) => true
    TypeLambda(_, body) => body.is_direct_function_implementation()
    _ => false
  }
}

///|
fn VerifyContext::check_binding_initializer(
  self : VerifyContext,
  implementation_kind : BindingImplementationKind,
  initializer : Expr,
  expected : Type,
  value_scope : ValueScope,
  type_scope : TypeScope,
) -> Effect {
  if implementation_kind is FunctionBinding &&
    initializer.is_direct_function_implementation() {
    self.check_function_implementation(
      initializer, expected, value_scope, type_scope,
    )
  } else {
    self.check_expr(initializer, expected, value_scope, type_scope)
  }
}

///|
/// Returns whether a direct function implementation conforms to its declaration.
///
/// Parameter and result types remain invariant, while the implementation's
/// latent effect may be any subeffect of the declaration, including across
/// algebraic terms. This is deliberately broader than value consumability: the
/// declaration owns the callable ABI and the direct body is lowered under that
/// declaration, whereas an already-existing function value has a fixed ABI.
fn VerifyContext::function_implementation_matches(
  self : VerifyContext,
  implementation : Type,
  declaration : Type,
) -> Bool {
  self.function_implementation_matches_with(
    self.program.metadata.definitional_equality_context(),
    self.normalize_type(implementation),
    self.normalize_type(declaration),
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
