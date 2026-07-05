///|
priv struct GenericArgumentBinding {
  parameter : TypeParameterId
  argument : @types.GenericArgument
}

///|
priv struct GenericArgumentInference {
  parameters : Array[@types.TypeParameter]
  bindings : Array[GenericArgumentBinding]
  mut failed : Bool
}

///|
priv struct InstantiatedCallableType {
  generic_arguments : Array[@types.GenericArgument]
  parameters : Array[@types.Type]
  result : @types.Type
  effect : @types.Effect
}

///|
priv struct InferredApplicationGenericArguments {
  generic_arguments : Array[@types.GenericArgument]
  substitution : @types.TypeSubstitution
}

///|
priv struct ExplicitGenericApplicationResult {
  arguments : Array[@types.GenericArgument]
  type_ : @types.Type
}

///|
fn GenericArgumentInference::GenericArgumentInference(
  parameters : Array[@types.TypeParameter],
) -> GenericArgumentInference {
  { parameters, bindings: [], failed: false }
}

///|
fn GenericArgumentInference::fail(self : GenericArgumentInference) -> Unit {
  self.failed = true
}

///|
fn GenericArgumentInference::tracked_parameter(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
) -> @types.TypeParameter? {
  for tracked in self.parameters {
    if tracked.id == parameter {
      return Some(tracked)
    }
  }
  None
}

///|
fn GenericArgumentInference::lookup(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
) -> @types.GenericArgument? {
  for binding in self.bindings {
    if binding.parameter == parameter {
      return Some(binding.argument)
    }
  }
  None
}

///|
fn GenericArgumentInference::remember(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  argument : @types.GenericArgument,
) -> Unit {
  if argument is TypeArgument(Error) {
    return
  }
  if argument is EffectArgument(effect) &&
    !effect_is_parameter(effect, parameter) &&
    effect_mentions_free_parameter(effect, parameter) {
    self.fail()
    return
  }
  match self.lookup(parameter) {
    Some(_) => ()
    None => self.bindings.push({ parameter, argument })
  }
}

///|
fn GenericArgumentInference::collect(
  self : GenericArgumentInference,
  template : @types.Type,
  actual : @types.Type,
) -> Unit {
  // Local generic-argument synthesis is first-order and boundary-local: only type
  // parameters bound by this one forall are remembered, and only from types
  // adjacent to this call.
  match (template, actual) {
    (Error, _) | (_, Error) => ()
    (Parameter(parameter), actual) =>
      if self.tracked_parameter(parameter) is Some(tracked) &&
        tracked.kind != Effect {
        self.remember(parameter, TypeArgument(actual))
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
            self.collect_generic_array(left_arguments, right_arguments)
          }
        _ => ()
      }
  }
}

///|
fn GenericArgumentInference::collect_effect(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Unit {
  self.collect_effect_terms(effect_terms(template), effect_terms(actual))
}

///|
fn GenericArgumentInference::collect_effect_terms(
  self : GenericArgumentInference,
  templates : Array[@types.Effect],
  actuals : Array[@types.Effect],
) -> Unit {
  if self.failed {
    return
  }
  let row_parameters = []
  let concrete_templates = []
  for template in templates {
    match self.tracked_effect_row_parameter(template) {
      Some(parameter) => row_parameters.push(parameter)
      None => concrete_templates.push(template)
    }
  }
  if row_parameters.length() > 1 {
    self.fail()
    return
  }
  let used = []
  for _ in actuals {
    used.push(false)
  }
  for template in concrete_templates {
    match self.unique_effect_term_candidate(template, actuals, used) {
      Some(index) => {
        self.collect_effect_term(template, actuals[index])
        if self.failed {
          return
        }
        used[index] = true
      }
      None => {
        self.fail()
        return
      }
    }
  }
  let remaining = []
  for index in 0..<actuals.length() {
    if !used[index] {
      remaining.push(actuals[index])
    }
  }
  match row_parameters {
    [parameter] =>
      self.remember(parameter, EffectArgument(effect_from_terms(remaining)))
    [] => if !remaining.is_empty() { self.fail() }
    _ => self.fail()
  }
}

///|
fn GenericArgumentInference::unique_effect_term_candidate(
  self : GenericArgumentInference,
  template : @types.Effect,
  actuals : Array[@types.Effect],
  used : Array[Bool],
) -> Int? {
  let mut found_index : Int? = None
  for index in 0..<actuals.length() {
    if !used[index] && self.effect_term_candidate(template, actuals[index]) {
      if found_index is Some(_) {
        self.fail()
        return None
      }
      found_index = Some(index)
    }
  }
  found_index
}

///|
fn GenericArgumentInference::effect_term_candidate(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Bool {
  match (template, actual) {
    (Empty, Empty) => true
    (Parameter(_), _) =>
      self.tracked_effect_row_parameter(template) is Some(_) ||
      template.equals(actual)
    (Singleton(left_symbol, _), Singleton(right_symbol, _)) =>
      left_symbol == right_symbol
    _ => template.equals(actual)
  }
}

///|
fn GenericArgumentInference::collect_effect_term(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Unit {
  match (template, actual) {
    (Empty, Empty) => ()
    (Parameter(parameter), _) =>
      match self.tracked_parameter(parameter) {
        Some(tracked) =>
          if tracked.kind == Effect {
            self.remember(parameter, EffectArgument(actual))
          } else if !template.equals(actual) {
            self.fail()
          }
        None => if !template.equals(actual) { self.fail() }
      }
    (
      Singleton(left_symbol, left_arguments),
      Singleton(right_symbol, right_arguments),
    ) =>
      if left_symbol == right_symbol {
        self.collect_generic_array(left_arguments, right_arguments)
      } else {
        self.fail()
      }
    _ => if !template.equals(actual) { self.fail() }
  }
}

///|
fn GenericArgumentInference::tracked_effect_row_parameter(
  self : GenericArgumentInference,
  effect : @types.Effect,
) -> TypeParameterId? {
  match effect {
    Parameter(parameter) =>
      match self.tracked_parameter(parameter) {
        Some(tracked) =>
          if tracked.kind == Effect {
            Some(parameter)
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn GenericArgumentInference::collect_array(
  self : GenericArgumentInference,
  templates : Array[@types.Type],
  actuals : Array[@types.Type],
) -> Unit {
  if self.failed {
    return
  }
  if templates.length() != actuals.length() {
    return
  }
  for index in 0..<templates.length() {
    self.collect(templates[index], actuals[index])
  }
}

///|
fn GenericArgumentInference::collect_generic_array(
  self : GenericArgumentInference,
  templates : Array[@types.GenericArgument],
  actuals : Array[@types.GenericArgument],
) -> Unit {
  if self.failed {
    return
  }
  if templates.length() != actuals.length() {
    return
  }
  for index in 0..<templates.length() {
    match (templates[index], actuals[index]) {
      (TypeArgument(template), TypeArgument(actual)) =>
        self.collect(template, actual)
      (EffectArgument(template), EffectArgument(actual)) =>
        self.collect_effect(template, actual)
      _ => ()
    }
  }
}

///|
fn GenericArgumentInference::substitution(
  self : GenericArgumentInference,
) -> @types.TypeSubstitution? {
  if self.failed {
    return None
  }
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for parameter in self.parameters {
    guard self.lookup(parameter.id) is Some(argument) else { return None }
    substitution.insert_argument(parameter.id, argument)
  }
  Some(substitution)
}

///|
fn GenericArgumentInference::generic_arguments(
  self : GenericArgumentInference,
) -> Array[@types.GenericArgument]? {
  if self.failed {
    return None
  }
  let arguments = []
  for parameter in self.parameters {
    guard self.lookup(parameter.id) is Some(argument) else { return None }
    arguments.push(argument)
  }
  Some(arguments)
}

///|
fn effect_mentions_free_parameter(
  effect : @types.Effect,
  parameter : TypeParameterId,
) -> Bool {
  match effect {
    Empty => false
    Parameter(id) => id == parameter
    Singleton(_, arguments) =>
      arguments.any(fn(argument) {
        match argument {
          EffectArgument(effect) =>
            effect_mentions_free_parameter(effect, parameter)
          TypeArgument(_) => false
        }
      })
    Union(effects) =>
      effects.any(fn(effect) {
        effect_mentions_free_parameter(effect, parameter)
      })
  }
}

///|
fn effect_is_parameter(
  effect : @types.Effect,
  parameter : TypeParameterId,
) -> Bool {
  match effect {
    Parameter(id) => id == parameter
    _ => false
  }
}

///|
fn effect_terms(effect : @types.Effect) -> Array[@types.Effect] {
  match effect.normalize() {
    Empty => []
    Union(items) => items
    item => [item]
  }
}

///|
fn effect_from_terms(terms : Array[@types.Effect]) -> @types.Effect {
  match terms {
    [] => Empty
    [term] => term
    _ => @types.Effect::Union(terms).normalize()
  }
}

///|
fn SemanticChecker::synthesize_argument_for_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  argument : @desugar.DesugaredExpr,
) -> @types.Type? {
  self.try_synthesize_checked_expr_type_silently(scope, argument)
}

///|
fn SemanticChecker::try_synthesize_checked_expr_type_silently(
  self : SemanticChecker,
  scope : TypeScope,
  expression : @desugar.DesugaredExpr,
) -> @types.Type? {
  let checker = self.copy_for_silent_analysis()
  let checked = checker.synthesize_checked_expr(scope.copy(), expression)
  if checker.diagnostics.is_empty() {
    Some(checked.type_)
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
fn SemanticChecker::infer_application_generic_arguments(
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
) -> InferredApplicationGenericArguments? {
  let inference = GenericArgumentInference::GenericArgumentInference(
    type_parameters,
  )
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
    if self.synthesize_argument_for_generic_arguments(
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
        GenericArguments,
        loc,
      )
    }
    return None
  }
  guard inference.generic_arguments() is Some(generic_arguments) else {
    if report_failure {
      self.report_application_inference_failure(
        failure_label,
        GenericArguments,
        loc,
      )
    }
    return None
  }
  Some({ generic_arguments, substitution })
}

///|
fn call_argument_expressions(
  arguments : Array[@desugar.DesugaredCallArgument],
) -> Array[@desugar.DesugaredExpr] {
  arguments.map(fn(argument) { argument.value_expr() })
}

///|
fn SemanticChecker::check_explicit_generic_application(
  self : SemanticChecker,
  scope : TypeScope,
  callee : @desugar.DesugaredExpr,
  callee_type : @types.Type,
  arguments : Array[@resolve.ResolvedGenericArgument],
  loc : SourceSpan,
) -> ExplicitGenericApplicationResult? {
  let subject = explicit_generic_application_subject(callee)
  match callee_type {
    Forall(type_parameters, body) => {
      if type_parameters.length() != arguments.length() {
        self.diagnostics.push({
          kind: GenericArgumentArityMismatch(
            subject~,
            expected=type_parameters.length(),
            actual=arguments.length(),
          ),
          loc,
        })
        return None
      }
      let diagnostic_count = self.diagnostics.length()
      let checked_arguments = check_resolved_generic_arguments(
        self.resolved_source,
        self.diagnostics,
        scope,
        type_parameters,
        arguments,
      )
      if self.diagnostics.length() != diagnostic_count {
        return None
      }
      let substitution = @types.TypeSubstitution::TypeSubstitution()
      for index in 0..<type_parameters.length() {
        substitution.insert_argument(
          type_parameters[index].id,
          checked_arguments[index],
        )
      }
      Some({
        arguments: checked_arguments,
        type_: body.substitute(substitution).normalize(),
      })
    }
    Error => None
    type_ => {
      self.diagnostics.push({
        kind: GenericArgumentsOnNonGeneric(subject~, type_~),
        loc,
      })
      None
    }
  }
}

///|
fn explicit_generic_application_subject(
  callee : @desugar.DesugaredExpr,
) -> GenericArgumentSubject {
  ExplicitExpression(
    callee=explicit_generic_callee_name(callee),
    callee_loc=Some(callee.loc()),
  )
}

///|
fn explicit_generic_callee_name(callee : @desugar.DesugaredExpr) -> String? {
  match callee {
    Var(name~, ..) => Some(name)
    Field(name~, ..) => Some(name)
    GenericApplication(callee~, ..) => explicit_generic_callee_name(callee)
    _ => None
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
  guard self.infer_application_generic_arguments(
      scope,
      type_parameters,
      parameters,
      call_argument_expressions(arguments),
      Some(result),
      expected_result,
      false,
      "generic arguments",
      loc,
      report_failure,
    )
    is Some(inferred) else {
    return None
  }
  Some({
    generic_arguments: inferred.generic_arguments,
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
