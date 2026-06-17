///|
priv struct TypeArgumentBinding {
  parameter : TypeParameterId
  type_ : @types.Type
}

///|
priv struct TypeArgumentInference {
  parameters : Array[@types.TypeParameter]
  bindings : Array[TypeArgumentBinding]
}

///|
priv struct InstantiatedCallableType {
  type_arguments : Array[@types.Type]
  parameters : Array[@types.Type]
  result : @types.Type
}

///|
fn TypeArgumentInference::TypeArgumentInference(
  parameters : Array[@types.TypeParameter],
) -> TypeArgumentInference {
  { parameters, bindings: [] }
}

///|
fn TypeArgumentInference::tracks(
  self : TypeArgumentInference,
  parameter : TypeParameterId,
) -> Bool {
  self.parameters.any(fn(tracked) { tracked.id == parameter })
}

///|
fn TypeArgumentInference::lookup(
  self : TypeArgumentInference,
  parameter : TypeParameterId,
) -> @types.Type? {
  for binding in self.bindings {
    if binding.parameter == parameter {
      return Some(binding.type_)
    }
  }
  None
}

///|
fn TypeArgumentInference::remember(
  self : TypeArgumentInference,
  parameter : TypeParameterId,
  type_ : @types.Type,
) -> Unit {
  if type_ is Error {
    return
  }
  // A later conflict does not rewrite the chosen type argument. The final
  // argument/result checking step will surface the concrete mismatch.
  if self.lookup(parameter) is None {
    self.bindings.push({ parameter, type_ })
  }
}

///|
fn TypeArgumentInference::collect(
  self : TypeArgumentInference,
  template : @types.Type,
  actual : @types.Type,
) -> Unit {
  // Local type-argument synthesis is first-order and boundary-local: only type
  // parameters bound by this one forall are remembered, and only from types
  // adjacent to this call.
  match (template, actual) {
    (Error, _) | (_, Error) => ()
    (Parameter(parameter), actual) =>
      if self.tracks(parameter) {
        self.remember(parameter, actual)
      }
    (
      Nominal(left_symbol, left_arguments),
      Nominal(right_symbol, right_arguments),
    ) =>
      if left_symbol == right_symbol {
        self.collect_array(left_arguments, right_arguments)
      }
    (
      Function(left_parameters, left_result),
      Function(right_parameters, right_result),
    ) => {
      self.collect_array(left_parameters, right_parameters)
      self.collect(left_result, right_result)
    }
    _ => ()
  }
}

///|
fn TypeArgumentInference::collect_array(
  self : TypeArgumentInference,
  templates : Array[@types.Type],
  actuals : Array[@types.Type],
) -> Unit {
  if templates.length() != actuals.length() {
    return
  }
  for index in 0..<templates.length() {
    self.collect(templates[index], actuals[index])
  }
}

///|
fn TypeArgumentInference::substitution(
  self : TypeArgumentInference,
) -> @types.TypeSubstitution? {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for parameter in self.parameters {
    guard self.lookup(parameter.id) is Some(type_) else { return None }
    substitution.insert(parameter.id, type_)
  }
  Some(substitution)
}

///|
fn TypeArgumentInference::type_arguments(
  self : TypeArgumentInference,
) -> Array[@types.Type]? {
  let arguments = []
  for parameter in self.parameters {
    guard self.lookup(parameter.id) is Some(type_) else { return None }
    arguments.push(type_)
  }
  Some(arguments)
}

///|
fn SemanticChecker::synthesize_argument_for_type_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  argument : @desugar.DesugaredExpr,
) -> @types.Type? {
  // During inference, an argument is allowed to fail synthesis without making
  // the whole call fail immediately. Once type arguments are known, the same
  // argument is checked again through the ordinary user-visible judgment.
  let checkpoint = self.diagnostic_checkpoint()
  let type_ = self.synthesize_expr(scope, argument)
  let success = self.diagnostics.length() == checkpoint.length
  self.rollback_diagnostics(checkpoint)
  if success {
    Some(type_)
  } else {
    None
  }
}

///|
fn SemanticChecker::instantiate_generic_callable(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  body : @types.Type,
  arguments : Array[@desugar.DesugaredCallArgument],
  expected_result : @types.Type?,
  loc : SourceSpan,
  report_failure : Bool,
) -> InstantiatedCallableType? {
  // forall A_1 ... A_n. (P_1, ..., P_m) -> R
  //
  //   1. collect A_i constraints from synthesize-able arguments;
  //   2. collect result constraints from a checking context, if present;
  //   3. substitute only when every A_i is known;
  //   4. let normal argument/result checking report concrete mismatches.
  guard body is Function(parameters, result) else {
    if report_failure {
      self.diagnostics.push({
        kind: NotCallable(Forall(type_parameters, body)),
        loc,
      })
    }
    return None
  }
  if parameters.length() != arguments.length() {
    if report_failure {
      self.diagnostics.push({ kind: CannotInferExpression("call arity"), loc })
    }
    return None
  }
  let inference = TypeArgumentInference::TypeArgumentInference(type_parameters)
  for index in 0..<parameters.length() {
    if self.synthesize_argument_for_type_arguments(
        scope,
        arguments[index].value_expr(),
      )
      is Some(actual) {
      inference.collect(parameters[index], actual)
    }
  }
  if expected_result is Some(expected) {
    inference.collect(result, expected)
  }
  guard inference.substitution() is Some(substitution) else {
    if report_failure {
      self.diagnostics.push({
        kind: CannotInferExpression("type arguments"),
        loc,
      })
    }
    return None
  }
  guard inference.type_arguments() is Some(type_arguments) else {
    if report_failure {
      self.diagnostics.push({
        kind: CannotInferExpression("type arguments"),
        loc,
      })
    }
    return None
  }
  Some({
    type_arguments,
    parameters: parameters.map(fn(parameter) {
      parameter.substitute(substitution)
    }),
    result: result.substitute(substitution),
  })
}

///|
fn @desugar.DesugaredCallArgument::value_expr(
  self : @desugar.DesugaredCallArgument,
) -> @desugar.DesugaredExpr {
  match self {
    Positional(expression) | Named(value=expression, ..) => expression
  }
}
