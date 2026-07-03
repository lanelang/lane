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
  effect : @types.Effect
}

///|
priv struct InferredApplicationTypeArguments {
  type_arguments : Array[@types.Type]
  substitution : @types.TypeSubstitution
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
      Function(left_parameters, left_result, left_effect),
      Function(right_parameters, right_result, right_effect),
    ) => {
      self.collect_array(left_parameters, right_parameters)
      self.collect(left_result, right_result)
      self.collect_effect(left_effect, right_effect)
    }
    _ =>
      match (template.decompose_nominal(), actual.decompose_nominal()) {
        (
          Some((left_symbol, left_arguments)),
          Some((right_symbol, right_arguments)),
        ) =>
          if left_symbol == right_symbol {
            self.collect_array(left_arguments, right_arguments)
          }
        _ => ()
      }
  }
}

///|
fn TypeArgumentInference::collect_effect(
  self : TypeArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Unit {
  match (template, actual) {
    (Empty, Empty) => ()
    (Parameter(parameter), _) =>
      if self.tracks(parameter) {
        self.remember(parameter, effect_as_type(actual))
      }
    (
      Singleton(left_symbol, left_arguments),
      Singleton(right_symbol, right_arguments),
    ) =>
      if left_symbol == right_symbol {
        self.collect_array(left_arguments, right_arguments)
      }
    (Union(left), Union(right)) =>
      if left.length() == right.length() {
        for index in 0..<left.length() {
          self.collect_effect(left[index], right[index])
        }
      }
    _ => ()
  }
}

///|
fn effect_as_type(effect : @types.Effect) -> @types.Type {
  match effect {
    Parameter(id) => Parameter(id)
    _ => Error
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
fn SemanticChecker::report_application_inference_failure(
  self : SemanticChecker,
  label : String,
  reason : CannotInferReason,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({ kind: CannotInferExpression(label~, reason~), loc })
}

///|
fn SemanticChecker::report_application_arity(
  self : SemanticChecker,
  label : String,
  loc : SourceSpan,
) -> Unit {
  self.report_application_inference_failure(label, CallArity, loc)
}

///|
fn SemanticChecker::check_application_arity(
  self : SemanticChecker,
  expected : Int,
  actual : Int,
  label : String,
  loc : SourceSpan,
  report_failure : Bool,
) -> Bool {
  if expected == actual {
    true
  } else {
    if report_failure {
      self.report_application_arity(label, loc)
    }
    false
  }
}

///|
fn SemanticChecker::infer_application_type_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  parameter_templates : Array[@types.Type],
  argument_expressions : Array[@desugar.DesugaredExpr],
  result_template : @types.Type?,
  expected_result : @types.Type?,
  collect_result_first : Bool,
  failure_label : String,
  loc : SourceSpan,
  report_failure : Bool,
) -> InferredApplicationTypeArguments? {
  let inference = TypeArgumentInference::TypeArgumentInference(type_parameters)
  if collect_result_first &&
    result_template is Some(template) &&
    expected_result is Some(expected) {
    inference.collect(template, expected)
  }
  let count = if parameter_templates.length() < argument_expressions.length() {
    parameter_templates.length()
  } else {
    argument_expressions.length()
  }
  for index in 0..<count {
    if self.synthesize_argument_for_type_arguments(
        scope,
        argument_expressions[index],
      )
      is Some(actual) {
      inference.collect(parameter_templates[index], actual)
    }
  }
  if !collect_result_first &&
    result_template is Some(template) &&
    expected_result is Some(expected) {
    inference.collect(template, expected)
  }
  guard inference.substitution() is Some(substitution) else {
    if report_failure {
      self.report_application_inference_failure(
        failure_label,
        TypeArguments,
        loc,
      )
    }
    return None
  }
  guard inference.type_arguments() is Some(type_arguments) else {
    if report_failure {
      self.report_application_inference_failure(
        failure_label,
        TypeArguments,
        loc,
      )
    }
    return None
  }
  Some({ type_arguments, substitution })
}

///|
fn call_argument_expressions(
  arguments : Array[@desugar.DesugaredCallArgument],
) -> Array[@desugar.DesugaredExpr] {
  arguments.map(fn(argument) { argument.value_expr() })
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
  guard body is Function(parameters, result, effect) else {
    if report_failure {
      self.diagnostics.push({
        kind: NotCallable(Forall(type_parameters, body)),
        loc,
      })
    }
    return None
  }
  if !self.check_application_arity(
      parameters.length(),
      arguments.length(),
      "call arity",
      loc,
      report_failure,
    ) {
    return None
  }
  guard self.infer_application_type_arguments(
      scope,
      type_parameters,
      parameters,
      call_argument_expressions(arguments),
      Some(result),
      expected_result,
      false,
      "type arguments",
      loc,
      report_failure,
    )
    is Some(inferred) else {
    return None
  }
  Some({
    type_arguments: inferred.type_arguments,
    parameters: parameters.map(fn(parameter) {
      parameter.substitute(inferred.substitution)
    }),
    result: result.substitute(inferred.substitution),
    effect: effect.substitute(inferred.substitution),
  })
}

///|
fn @desugar.DesugaredCallArgument::value_expr(
  self : @desugar.DesugaredCallArgument,
) -> @desugar.DesugaredExpr {
  match self {
    Positional(value~, ..) | Named(value~, ..) => value
  }
}

///|
fn @desugar.DesugaredCallArgument::loc(
  self : @desugar.DesugaredCallArgument,
) -> SourceSpan {
  match self {
    Positional(loc~, ..) | Named(loc~, ..) => loc
  }
}
