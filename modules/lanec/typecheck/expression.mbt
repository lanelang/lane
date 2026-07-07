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
  if !type_matches(expected, actual) {
    self.diagnostics.push({ kind: TypeMismatch(expected~, actual~), loc })
  }
}

///|
fn type_matches(expected : @types.Type, actual : @types.Type) -> Bool {
  expected.contains_error() ||
  actual.contains_error() ||
  expected.equals(actual)
}

///|
fn @types.Type::contains_error(self : @types.Type) -> Bool {
  match self {
    Error => true
    Primitive(_) | Constructor(_) | Parameter(_) => false
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
    Empty | Parameter(_) => false
    Singleton(_, arguments) =>
      arguments.any(fn(argument) { argument.contains_error() })
    Union(effects) => effects.any(fn(effect) { effect.contains_error() })
  }
}
