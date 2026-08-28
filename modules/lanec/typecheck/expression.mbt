///|
priv enum TypeCompatibility {
  ExactType
  FunctionEffectWidening
  IncompatibleType
}

///|
fn same_types(left : Array[@types.Type], right : Array[@types.Type]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !left[index].alpha_equal(right[index]) {
      return false
    }
  }
  true
}

///|
fn SemanticChecker::synthesize_expr(
  self : SemanticChecker,
  scope : TypeScope,
  expr : @desugar.DesugaredExpr,
) -> @types.Type {
  self.synthesize_checked_expr(scope, expr).type_
}

///|
fn SemanticChecker::expect_type(
  self : SemanticChecker,
  expected : @types.Type,
  actual : @types.Type,
  loc : SourceSpan,
) -> Unit {
  if self.type_matches(expected, actual, loc) is Some(false) {
    self.diagnostics.push({ kind: TypeMismatch(expected~, actual~), loc, })
  }
}

///|
fn SemanticChecker::expect_numeric_literal_type(
  self : SemanticChecker,
  expected : @types.Type,
  actual : @types.Type,
  replacement : String?,
  loc : SourceSpan,
) -> Unit {
  if self.type_matches(expected, actual, loc) is Some(false) {
    let kind = match replacement {
      Some(replacement) =>
        NumericLiteralTypeMismatch(expected~, actual~, replacement~)
      None => TypeMismatch(expected~, actual~)
    }
    self.diagnostics.push({ kind, loc, })
  }
}

///|
fn SemanticChecker::type_matches(
  self : SemanticChecker,
  expected : @types.Type,
  actual : @types.Type,
  loc : SourceSpan,
) -> Bool? {
  if expected.contains_error() || actual.contains_error() {
    return Some(true)
  }
  guard normalize_type_or_report(
      self.diagnostics,
      expected,
      loc,
      context="expected type",
    )
    is Some(expected) else {
    return None
  }
  guard normalize_type_or_report(
      self.diagnostics,
      actual,
      loc,
      context="actual type",
    )
    is Some(actual) else {
    return None
  }
  Some(expected.alpha_equal(actual))
}

///|
fn SemanticChecker::type_compatibility(
  self : SemanticChecker,
  expected : @types.Type,
  actual : @types.Type,
  loc : SourceSpan,
) -> TypeCompatibility? {
  if expected.contains_error() || actual.contains_error() {
    return Some(ExactType)
  }
  guard normalize_type_or_report(
      self.diagnostics,
      expected,
      loc,
      context="expected type",
    )
    is Some(expected) else {
    return None
  }
  guard normalize_type_or_report(
      self.diagnostics,
      actual,
      loc,
      context="actual type",
    )
    is Some(actual) else {
    return None
  }
  if expected.alpha_equal(actual) {
    return Some(ExactType)
  }
  match (expected, actual) {
    (
      Forall(expected_parameters, expected_body),
      Forall(actual_parameters, actual_body),
    ) => {
      if expected_parameters.length() != actual_parameters.length() {
        return Some(IncompatibleType)
      }
      let substitution = @types.TypeSubstitution::TypeSubstitution()
      for index in 0..<expected_parameters.length() {
        let expected_parameter = expected_parameters[index]
        let actual_parameter = actual_parameters[index]
        if expected_parameter.kind != actual_parameter.kind {
          return Some(IncompatibleType)
        }
        match actual_parameter.kind {
          Effect =>
            substitution.insert_effect(
              actual_parameter.id,
              @types.Effect::Parameter(expected_parameter.id),
            )
          Type | Function(_, _) =>
            substitution.insert(
              actual_parameter.id,
              @types.Type::Parameter(expected_parameter.id),
            )
        }
      }
      self.type_compatibility(
        expected_body,
        actual_body.substitute(substitution),
        loc,
      )
    }
    (
      Function(expected_parameters, expected_result, expected_effect),
      Function(actual_parameters, actual_result, actual_effect),
    ) =>
      if same_types(expected_parameters, actual_parameters) &&
        expected_result.alpha_equal(actual_result) &&
        actual_effect.alpha_subeffect_of(expected_effect) {
        Some(FunctionEffectWidening)
      } else {
        Some(IncompatibleType)
      }
    _ => Some(IncompatibleType)
  }
}

///|
fn @types.Type::contains_error(self : @types.Type) -> Bool {
  match self {
    Error => true
    Primitive(_) | BuiltinConstructor(_) | Constructor(_) | Parameter(_) =>
      false
    Apply(callee, arguments) =>
      callee.contains_error() ||
      arguments.any(fn(argument) { argument.contains_error() })
    TypeLambda(_, body) | Forall(_, body) => body.contains_error()
    Function(parameters, result, effect) =>
      parameters.any(fn(parameter) { parameter.contains_error() }) ||
      result.contains_error() ||
      effect.contains_error()
  }
}

///|
fn @types.GenericArgument::contains_error(
  self : @types.GenericArgument,
) -> Bool {
  match self {
    TypeArgument(type_) => type_.contains_error()
    EffectArgument(effect) => effect.contains_error()
  }
}

///|
fn @types.Effect::contains_error(self : @types.Effect) -> Bool {
  match self {
    Empty | Builtin(_) | Parameter(_) => false
    Singleton(_, arguments) =>
      arguments.any(fn(argument) { argument.contains_error() })
    Union(effects) => effects.any(fn(effect) { effect.contains_error() })
  }
}
