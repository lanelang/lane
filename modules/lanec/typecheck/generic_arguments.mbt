///|
priv struct GenericArgumentBinding {
  parameter : TypeParameterId
  argument : @types.GenericArgument
}

///|
priv struct GenericArgumentInference {
  parameters : Array[@types.TypeParameter]
  bindings : Array[GenericArgumentBinding]
}

///|
priv struct EffectTermPair {
  template : @types.Effect
  actual : @types.Effect
}

///|
priv struct EffectRowPattern {
  concrete_terms : Array[@types.Effect]
  row_parameter : TypeParameterId?
}

///|
priv enum EffectRowMatch {
  EffectRowsMatched(
    term_pairs~ : Array[EffectTermPair],
    residual_parameter~ : TypeParameterId?,
    residual_effect~ : @types.Effect
  )
  EffectRowsMismatched
  EffectRowsAmbiguous
}

///|
priv enum EffectTermCandidateResult {
  NoEffectTermCandidate
  UniqueEffectTermCandidate(Int)
  AmbiguousEffectTermCandidate
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
  { parameters, bindings: [] }
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
) -> Bool {
  if argument is TypeArgument(Error) {
    return true
  }
  if argument is EffectArgument(effect) &&
    !effect_is_parameter(effect, parameter) &&
    effect_mentions_free_parameter(effect, parameter) {
    return false
  }
  match self.lookup(parameter) {
    Some(_) => ()
    None => self.bindings.push({ parameter, argument })
  }
  true
}

///|
fn GenericArgumentInference::collect(
  self : GenericArgumentInference,
  template : @types.Type,
  actual : @types.Type,
) -> Bool {
  // Local generic-argument synthesis is first-order and boundary-local: only type
  // parameters bound by this one forall are remembered, and only from types
  // adjacent to this call.
  match (template, actual) {
    (Error, _) | (_, Error) => true
    (Parameter(parameter), actual) =>
      if self.tracked_parameter(parameter) is Some(tracked) &&
        tracked.kind != Effect {
        self.remember(parameter, TypeArgument(actual))
      } else {
        true
      }
    (
      Function(left_parameters, left_result, left_effect),
      Function(right_parameters, right_result, right_effect),
    ) =>
      self.collect_array(left_parameters, right_parameters) &&
      self.collect(left_result, right_result) &&
      self.collect_effect(left_effect, right_effect)
    _ =>
      match (template.decompose_nominal(), actual.decompose_nominal()) {
        (
          Some((left_symbol, left_arguments)),
          Some((right_symbol, right_arguments)),
        ) =>
          if left_symbol == right_symbol {
            self.collect_generic_array(left_arguments, right_arguments)
          } else {
            true
          }
        _ => true
      }
  }
}

///|
fn GenericArgumentInference::collect_effect(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Bool {
  match self.match_effect_rows(template, actual) {
    EffectRowsMatched(term_pairs~, residual_parameter~, residual_effect~) =>
      self.collect_effect_row_match(
        term_pairs, residual_parameter, residual_effect,
      )
    EffectRowsMismatched | EffectRowsAmbiguous => false
  }
}

///|
fn GenericArgumentInference::match_effect_rows(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> EffectRowMatch {
  guard self.effect_row_pattern(template) is Some(pattern) else {
    return EffectRowsAmbiguous
  }
  let actual_terms = effect_terms(actual)
  let used_actuals = []
  for _ in actual_terms {
    used_actuals.push(false)
  }
  let term_pairs = []
  for concrete in pattern.concrete_terms {
    match
      self.unique_effect_term_candidate(concrete, actual_terms, used_actuals) {
      UniqueEffectTermCandidate(index) => {
        term_pairs.push({ template: concrete, actual: actual_terms[index] })
        used_actuals[index] = true
      }
      NoEffectTermCandidate => return EffectRowsMismatched
      AmbiguousEffectTermCandidate => return EffectRowsAmbiguous
    }
  }
  let remaining = []
  for index in 0..<actual_terms.length() {
    if !used_actuals[index] {
      remaining.push(actual_terms[index])
    }
  }
  match pattern.row_parameter {
    Some(parameter) =>
      EffectRowsMatched(
        term_pairs~,
        residual_parameter=Some(parameter),
        residual_effect=effect_from_terms(remaining),
      )
    None =>
      if remaining.is_empty() {
        EffectRowsMatched(
          term_pairs~,
          residual_parameter=None,
          residual_effect=Empty,
        )
      } else {
        EffectRowsMismatched
      }
  }
}

///|
fn GenericArgumentInference::effect_row_pattern(
  self : GenericArgumentInference,
  effect : @types.Effect,
) -> EffectRowPattern? {
  let concrete_terms = []
  let mut row_parameter : TypeParameterId? = None
  for term in effect_terms(effect) {
    match self.tracked_effect_row_parameter(term) {
      Some(parameter) =>
        if row_parameter is Some(_) {
          return None
        } else {
          row_parameter = Some(parameter)
        }
      None => concrete_terms.push(term)
    }
  }
  Some({ concrete_terms, row_parameter })
}

///|
fn GenericArgumentInference::collect_effect_row_match(
  self : GenericArgumentInference,
  term_pairs : Array[EffectTermPair],
  residual_parameter : TypeParameterId?,
  residual_effect : @types.Effect,
) -> Bool {
  for pair in term_pairs {
    if !self.collect_effect_term(pair.template, pair.actual) {
      return false
    }
  }
  if residual_parameter is Some(parameter) {
    self.remember(parameter, EffectArgument(residual_effect))
  } else {
    true
  }
}

///|
fn GenericArgumentInference::unique_effect_term_candidate(
  self : GenericArgumentInference,
  template : @types.Effect,
  actuals : Array[@types.Effect],
  used : Array[Bool],
) -> EffectTermCandidateResult {
  let mut found_index : Int? = None
  for index in 0..<actuals.length() {
    if !used[index] && self.effect_term_candidate(template, actuals[index]) {
      if found_index is Some(_) {
        return AmbiguousEffectTermCandidate
      }
      found_index = Some(index)
    }
  }
  match found_index {
    Some(index) => UniqueEffectTermCandidate(index)
    None => NoEffectTermCandidate
  }
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
) -> Bool {
  match (template, actual) {
    (Empty, Empty) => true
    (Parameter(parameter), _) =>
      match self.tracked_parameter(parameter) {
        Some(tracked) =>
          if tracked.kind == Effect {
            self.remember(parameter, EffectArgument(actual))
          } else {
            template.equals(actual)
          }
        None => template.equals(actual)
      }
    (
      Singleton(left_symbol, left_arguments),
      Singleton(right_symbol, right_arguments),
    ) =>
      if left_symbol == right_symbol {
        self.collect_generic_array(left_arguments, right_arguments)
      } else {
        false
      }
    _ => template.equals(actual)
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
) -> Bool {
  if templates.length() != actuals.length() {
    return true
  }
  for index in 0..<templates.length() {
    if !self.collect(templates[index], actuals[index]) {
      return false
    }
  }
  true
}

///|
fn GenericArgumentInference::collect_generic_array(
  self : GenericArgumentInference,
  templates : Array[@types.GenericArgument],
  actuals : Array[@types.GenericArgument],
) -> Bool {
  if templates.length() != actuals.length() {
    return true
  }
  for index in 0..<templates.length() {
    match (templates[index], actuals[index]) {
      (TypeArgument(template), TypeArgument(actual)) =>
        if !self.collect(template, actual) {
          return false
        }
      (EffectArgument(template), EffectArgument(actual)) =>
        if !self.collect_effect(template, actual) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn GenericArgumentInference::finish(
  self : GenericArgumentInference,
) -> InferredApplicationGenericArguments? {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  let generic_arguments = []
  for parameter in self.parameters {
    guard self.lookup(parameter.id) is Some(argument) else { return None }
    substitution.insert_argument(parameter.id, argument)
    generic_arguments.push(argument)
  }
  Some({ generic_arguments, substitution })
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
  let mut inference_failed = false
  if collect_result_first &&
    result_template is Some(template) &&
    expected_result is Some(expected) {
    if !inference.collect(template, expected) {
      inference_failed = true
    }
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
      if !inference.collect(parameter_templates[index], actual) {
        inference_failed = true
      }
    }
  }
  if !collect_result_first &&
    result_template is Some(template) &&
    expected_result is Some(expected) {
    if !inference.collect(template, expected) {
      inference_failed = true
    }
  }
  guard !inference_failed else {
    if report_failure {
      self.report_application_inference_failure(
        failure_label,
        GenericArguments,
        loc,
      )
    }
    return None
  }
  guard inference.finish() is Some(inferred) else {
    if report_failure {
      self.report_application_inference_failure(
        failure_label,
        GenericArguments,
        loc,
      )
    }
    return None
  }
  Some(inferred)
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
