///|
priv struct GenericArgumentBinding {
  parameter : TypeParameterId
  argument : @types.GenericArgument
}

///|
priv struct GenericArgumentInference {
  declarations : CheckedDeclarationEnvironment
  scope : TypeScope
  parameters : Array[@types.TypeParameter]
  bindings : Array[GenericArgumentBinding]
  mut failure : GenericArgumentInferenceFailure?
  mut failure_loc : SourceSpan?
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
priv struct GenericApplicationEvidence {
  parameter_templates : Array[@types.Type]
  argument_expressions : Array[@desugar.DesugaredExpr]
  result_template : @types.Type?
  expected_result : @types.Type?
  effect_template : @types.Effect?
  expected_effect : @types.Effect?
  collect_result_first : Bool
  failure_label : String
  loc : SourceSpan
  report_failure : Bool
}

///|
priv struct ExplicitGenericApplicationResult {
  arguments : Array[@types.GenericArgument]
  type_ : @types.Type
}

///|
fn GenericArgumentInference::GenericArgumentInference(
  declarations : CheckedDeclarationEnvironment,
  scope : TypeScope,
  parameters : Array[@types.TypeParameter],
) -> GenericArgumentInference {
  {
    declarations,
    scope,
    parameters,
    bindings: [],
    failure: None,
    failure_loc: None,
  }
}

///|
fn GenericArgumentInference::fail(
  self : GenericArgumentInference,
  failure : GenericArgumentInferenceFailure,
) -> Bool {
  if self.failure is None {
    self.failure = Some(failure)
  }
  false
}

///|
fn GenericArgumentInference::set_failure_loc_if_missing(
  self : GenericArgumentInference,
  loc : SourceSpan,
) -> Unit {
  if self.failure_loc is None {
    self.failure_loc = Some(loc)
  }
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
/// A callback shape is ground for this inference when it contains neither
/// errors nor parameters quantified by this call. Rigid outer parameters are
/// already known to the caller and therefore remain admissible.
fn GenericArgumentInference::function_literal_shape_is_ground(
  self : GenericArgumentInference,
  parameters : Array[@types.Type],
  result : @types.Type,
) -> Bool {
  let inference_parameters = self.parameters.map(fn(parameter) { parameter.id })
  !parameters.any(fn(parameter) {
    parameter.contains_error() ||
    parameter.mentions_any_type_parameter(inference_parameters)
  }) &&
  !result.contains_error() &&
  !result.mentions_any_type_parameter(inference_parameters)
}

///|
fn GenericArgumentInference::remember(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  argument : @types.GenericArgument,
) -> Bool {
  // Generic inference is a finite map from this call's forall parameters to
  // concrete type/effect arguments:
  //
  //   Sub(parameter) = argument
  //
  // A repeated binding must be equal immediately. There is no later constraint
  // solver that can reconcile two incompatible candidates.
  if argument is TypeArgument(Error) {
    return true
  }
  guard self.tracked_parameter(parameter) is Some(tracked) else { return true }
  if !self.generic_argument_has_kind(argument, tracked.kind) {
    return self.fail(
      GenericArgumentConstraintMismatch(
        expected=tracked.generic_argument(),
        actual=argument,
      ),
    )
  }
  if argument is TypeArgument(type_) &&
    !type_is_parameter(type_, parameter) &&
    type_.mentions_any_type_parameter([parameter]) {
    return self.fail(
      RecursiveGenericArgument(parameter=tracked, actual=argument),
    )
  }
  if argument is EffectArgument(effect) &&
    !effect_is_parameter(effect, parameter) &&
    effect_mentions_free_parameter(effect, parameter) {
    return self.fail(
      RecursiveGenericArgument(parameter=tracked, actual=argument),
    )
  }
  match self.lookup(parameter) {
    Some(previous) =>
      if !generic_argument_equals(previous, argument) {
        return self.fail(
          ConflictingGenericArgument(
            parameter=tracked,
            previous~,
            actual=argument,
          ),
        )
      }
    None => self.bindings.push({ parameter, argument })
  }
  true
}

///|
fn GenericArgumentInference::generic_argument_has_kind(
  self : GenericArgumentInference,
  argument : @types.GenericArgument,
  expected : @types.Kind,
) -> Bool {
  match argument {
    TypeArgument(type_) =>
      match self.type_kind(type_, []) {
        Some(actual) => actual == expected
        None => true
      }
    EffectArgument(_) => expected == Effect
  }
}

///|
fn GenericArgumentInference::type_kind(
  self : GenericArgumentInference,
  type_ : @types.Type,
  bound : Array[@types.TypeParameter],
) -> @types.Kind? {
  match type_ {
    Error | Primitive(_) | Function(_, _, _) | Forall(_, _) => Some(Type)
    Constructor(symbol) => Some(self.nominal_type_kind(symbol))
    Apply(callee, _) =>
      match self.type_kind(callee, bound) {
        Some(Function(_, result)) => Some(result)
        Some(_) => Some(Type)
        None => None
      }
    TypeLambda(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter)
      }
      match self.type_kind(body, next_bound) {
        Some(result) =>
          Some(
            Function(
              type_parameters.map(fn(parameter) { parameter.kind }),
              result,
            ),
          )
        None => None
      }
    }
    Parameter(id) => self.type_parameter_kind(id, bound)
  }
}

///|
fn GenericArgumentInference::nominal_type_kind(
  self : GenericArgumentInference,
  symbol : TypeSymbolId,
) -> @types.Kind {
  if self.declarations.checked_struct(symbol) is Some(declaration) {
    return type_parameters_to_constructor_kind(declaration.type_parameters)
  }
  if self.declarations.checked_enum(symbol) is Some(declaration) {
    return type_parameters_to_constructor_kind(declaration.type_parameters)
  }
  Type
}

///|
fn GenericArgumentInference::type_parameter_kind(
  self : GenericArgumentInference,
  symbol : TypeParameterId,
  bound : Array[@types.TypeParameter],
) -> @types.Kind? {
  for parameter in bound {
    if parameter.id == symbol {
      return Some(parameter.kind)
    }
  }
  match self.tracked_parameter(symbol) {
    Some(parameter) => return Some(parameter.kind)
    None => ()
  }
  match self.scope.type_parameter_kind(symbol) {
    Some(kind) => return Some(kind)
    None => ()
  }
  Some(Type)
}

///|
fn GenericArgumentInference::collect(
  self : GenericArgumentInference,
  template : @types.Type,
  actual : @types.Type,
) -> Bool {
  // Type-argument collection implements the local rule:
  //
  //   collect(T, Actual) = Sub
  //
  // Only parameters bound by this one forall are remembered. Nominal and
  // function types recurse structurally; unrelated nominal constructors produce
  // no constraint instead of inventing a coercion or delayed equality problem.
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
      Apply(template_callee, template_arguments),
      Apply(actual_callee, actual_arguments),
    ) => {
      if !self.collect(template_callee, actual_callee) {
        return false
      }
      self.collect_generic_array(template_arguments, actual_arguments)
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
  // Effect-argument collection is exact row matching, not subtyping:
  //
  //   collect({C_1, ..., C_n, E?}, Actual)
  //
  // Every concrete template singleton must match one unique actual singleton.
  // The optional tracked row parameter receives only the unmatched residual.
  match self.match_effect_rows(template, actual) {
    EffectRowsMatched(term_pairs~, residual_parameter~, residual_effect~) =>
      self.collect_effect_row_match(
        term_pairs, residual_parameter, residual_effect,
      )
    EffectRowsMismatched | EffectRowsAmbiguous =>
      self.fail(
        GenericArgumentConstraintMismatch(
          expected=EffectArgument(template),
          actual=EffectArgument(actual),
        ),
      )
  }
}

///|
fn GenericArgumentInference::match_effect_rows(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> EffectRowMatch {
  // Row matching is intentionally one-shot and terminating. If the template has
  // more than one tracked row variable, or if a concrete singleton can match
  // multiple actual terms, the result is ambiguous and inference fails.
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
fn GenericArgumentInference::collect_effect_term_from_row(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Bool {
  let actual_terms = effect_terms(actual)
  let used_actuals = []
  for _ in actual_terms {
    used_actuals.push(false)
  }
  match
    self.unique_effect_term_candidate(template, actual_terms, used_actuals) {
    UniqueEffectTermCandidate(index) =>
      self.collect_effect_term(template, actual_terms[index])
    NoEffectTermCandidate | AmbiguousEffectTermCandidate =>
      self.fail(
        GenericArgumentConstraintMismatch(
          expected=EffectArgument(template),
          actual=EffectArgument(actual),
        ),
      )
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
          } else if template.equals(actual) {
            true
          } else {
            self.fail(
              GenericArgumentConstraintMismatch(
                expected=EffectArgument(template),
                actual=EffectArgument(actual),
              ),
            )
          }
        None =>
          if template.equals(actual) {
            true
          } else {
            self.fail(
              GenericArgumentConstraintMismatch(
                expected=EffectArgument(template),
                actual=EffectArgument(actual),
              ),
            )
          }
      }
    (
      Singleton(left_symbol, left_arguments),
      Singleton(right_symbol, right_arguments),
    ) =>
      if left_symbol == right_symbol {
        self.collect_generic_array(left_arguments, right_arguments)
      } else {
        self.fail(
          GenericArgumentConstraintMismatch(
            expected=EffectArgument(template),
            actual=EffectArgument(actual),
          ),
        )
      }
    _ =>
      if template.equals(actual) {
        true
      } else {
        self.fail(
          GenericArgumentConstraintMismatch(
            expected=EffectArgument(template),
            actual=EffectArgument(actual),
          ),
        )
      }
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
  let substitution = self.partial_substitution()
  let generic_arguments = []
  let missing = []
  for parameter in self.parameters {
    guard self.lookup(parameter.id) is Some(argument) else {
      missing.push(parameter)
      continue
    }
    generic_arguments.push(argument)
  }
  if !missing.is_empty() {
    ignore(self.fail(MissingGenericArguments(parameters=missing)))
    return None
  }
  Some({ generic_arguments, substitution })
}

///|
fn GenericArgumentInference::partial_substitution(
  self : GenericArgumentInference,
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for binding in self.bindings {
    substitution.insert_argument(binding.parameter, binding.argument)
  }
  substitution
}

///|
fn generic_argument_equals(
  left : @types.GenericArgument,
  right : @types.GenericArgument,
) -> Bool {
  match (left, right) {
    (TypeArgument(left), TypeArgument(right)) => left.equals(right)
    (EffectArgument(left), EffectArgument(right)) => left.equals(right)
    _ => false
  }
}

///|
fn type_parameters_to_constructor_kind(
  parameters : Array[@types.TypeParameter],
) -> @types.Kind {
  if parameters.is_empty() {
    Type
  } else {
    Function(parameters.map(fn(parameter) { parameter.kind }), Type)
  }
}

///|
fn type_is_parameter(type_ : @types.Type, parameter : TypeParameterId) -> Bool {
  match type_ {
    Parameter(id) => id == parameter
    _ => false
  }
}

///|
fn effect_mentions_free_parameter(
  effect : @types.Effect,
  parameter : TypeParameterId,
) -> Bool {
  match effect {
    Empty | Io => false
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
/// Function literals do not contribute parameter or result type evidence.
/// Their latent effect is measured separately only after the expected callback
/// shape is ground for this generic application.
fn SemanticChecker::synthesize_argument_for_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  argument : @desugar.DesugaredExpr,
) -> @types.Type? {
  match argument {
    FunctionLiteral(..) => None
    _ => self.try_synthesize_checked_expr_type_silently(scope, argument)
  }
}

///|
/// Measures only the latent effect of a monomorphic function literal whose
/// parameter and result types are ground for the current generic application.
fn SemanticChecker::measure_ground_function_literal_effect_for_generic_arguments(
  self : SemanticChecker,
  inference : GenericArgumentInference,
  scope : TypeScope,
  argument : @desugar.DesugaredExpr,
  expected_parameters : Array[@types.Type],
  expected_result : @types.Type,
) -> @types.Effect? {
  guard inference.function_literal_shape_is_ground(
    expected_parameters, expected_result,
  ) else {
    return None
  }
  guard argument
    is FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) &&
    type_parameters.is_empty() else {
    return None
  }
  let checker = self.copy_for_silent_analysis()
  let checked = checker.check_monomorphic_function_literal(
    scope,
    parameters,
    return_type,
    effect,
    body,
    expected_parameters,
    expected_result,
    None,
    loc,
  )
  guard checker.diagnostics.is_empty() &&
    checked.type_ is Function(_, _, inferred_effect) else {
    return None
  }
  Some(inferred_effect)
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
fn SemanticChecker::report_internal_typecheck_failure(
  self : SemanticChecker,
  label : String,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({ kind: InternalTypecheckFailure(label~), loc })
}

///|
fn SemanticChecker::report_application_arity(
  self : SemanticChecker,
  label : String,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({ kind: ApplicationArityMismatch(label~), loc })
}

///|
fn SemanticChecker::check_application_arity(
  self : SemanticChecker,
  expected : Int,
  actual : Int,
  loc : SourceSpan,
  report_failure : Bool,
) -> Bool {
  if expected == actual {
    true
  } else {
    if report_failure {
      self.diagnostics.push({ kind: CallArityMismatch(expected~, actual~), loc })
    }
    false
  }
}

///|
fn SemanticChecker::infer_application_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  evidence : GenericApplicationEvidence,
) -> InferredApplicationGenericArguments? {
  // Local generic application inference:
  //
  //   Gamma |- arg_i => Actual_i
  //   collect(P_i, Actual_i)
  //   collect(R, Expected)      when checking mode supplies Expected
  //   collect_term(Eff, ExpectedEff)
  //                            when checking mode supplies ExpectedEff
  //   all forall parameters are bound consistently
  //   ------------------------------------------------
  //   inferred generic arguments and substitution
  //
  // The order knob exists because operation calls may need result information
  // before payload checking, while ordinary function calls prefer argument
  // evidence first. Either way, every constraint is accepted or rejected now.
  let inference = GenericArgumentInference::GenericArgumentInference(
    self.declarations,
    scope,
    type_parameters,
  )
  let mut inference_failed = false
  if evidence.collect_result_first &&
    evidence.result_template is Some(template) &&
    evidence.expected_result is Some(expected) {
    if !inference.collect(template, expected) {
      inference_failed = true
      inference.set_failure_loc_if_missing(evidence.loc)
    }
  }
  let count = if evidence.parameter_templates.length() <
    evidence.argument_expressions.length() {
    evidence.parameter_templates.length()
  } else {
    evidence.argument_expressions.length()
  }
  for index in 0..<count {
    let template = evidence.parameter_templates[index]
    let argument = evidence.argument_expressions[index]
    if self.synthesize_argument_for_generic_arguments(scope, argument)
      is Some(actual) {
      if !inference.collect(template, actual) {
        inference_failed = true
        inference.set_failure_loc_if_missing(argument.loc())
      }
    }
  }
  if !evidence.collect_result_first &&
    evidence.result_template is Some(template) &&
    evidence.expected_result is Some(expected) {
    if !inference.collect(template, expected) {
      inference_failed = true
      inference.set_failure_loc_if_missing(evidence.loc)
    }
  }
  if evidence.effect_template is Some(template) &&
    evidence.expected_effect is Some(expected) {
    if !inference.collect_effect_term_from_row(template, expected) {
      inference_failed = true
      inference.set_failure_loc_if_missing(evidence.loc)
    }
  }
  for index in 0..<count {
    let template = evidence.parameter_templates[index]
    guard template is Function(_, _, template_effect) else { continue }
    let instantiated = template.substitute(inference.partial_substitution())
    guard instantiated is Function(parameters, result, _) else { continue }
    let argument = evidence.argument_expressions[index]
    if self.measure_ground_function_literal_effect_for_generic_arguments(
        inference, scope, argument, parameters, result,
      )
      is Some(actual_effect) &&
      !inference.collect_effect(template_effect, actual_effect) {
      inference_failed = true
      inference.set_failure_loc_if_missing(argument.loc())
    }
  }
  guard !inference_failed else {
    if evidence.report_failure {
      self.report_generic_argument_inference_failure(
        evidence.failure_label,
        inference,
        evidence.loc,
      )
    }
    return None
  }
  guard inference.finish() is Some(inferred) else {
    if evidence.report_failure {
      self.report_generic_argument_inference_failure(
        evidence.failure_label,
        inference,
        evidence.loc,
      )
    }
    return None
  }
  Some(inferred)
}

///|
fn SemanticChecker::infer_contextual_callable_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  parameter_templates : Array[@types.Type],
  argument_expressions : Array[@desugar.DesugaredExpr],
  result_template : @types.Type,
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> InferredApplicationGenericArguments? {
  self.infer_application_generic_arguments(scope, type_parameters, {
    parameter_templates,
    argument_expressions,
    result_template: Some(result_template),
    expected_result,
    effect_template: None,
    expected_effect: None,
    collect_result_first: false,
    failure_label: "generic arguments",
    loc,
    report_failure: true,
  })
}

///|
fn SemanticChecker::infer_variant_owner_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  payload_templates : Array[@types.Type],
  arguments : Array[@desugar.DesugaredExpr],
  result_template : @types.Type?,
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> InferredApplicationGenericArguments? {
  self.infer_application_generic_arguments(scope, type_parameters, {
    parameter_templates: payload_templates,
    argument_expressions: arguments,
    result_template,
    expected_result,
    effect_template: None,
    expected_effect: None,
    collect_result_first: true,
    failure_label: "generic arguments",
    loc,
    report_failure: true,
  })
}

///|
fn SemanticChecker::infer_variant_hidden_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  payload_templates : Array[@types.Type],
  arguments : Array[@desugar.DesugaredExpr],
  loc : SourceSpan,
) -> InferredApplicationGenericArguments? {
  self.infer_application_generic_arguments(scope, type_parameters, {
    parameter_templates: payload_templates,
    argument_expressions: arguments,
    result_template: None,
    expected_result: None,
    effect_template: None,
    expected_effect: None,
    collect_result_first: false,
    failure_label: "hidden generic arguments",
    loc,
    report_failure: true,
  })
}

///|
fn SemanticChecker::infer_operation_hidden_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  payload_templates : Array[@types.Type],
  arguments : Array[@desugar.DesugaredExpr],
  result_template : @types.Type,
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> InferredApplicationGenericArguments? {
  self.infer_application_generic_arguments(scope, type_parameters, {
    parameter_templates: payload_templates,
    argument_expressions: arguments,
    result_template: Some(result_template),
    expected_result,
    effect_template: None,
    expected_effect: None,
    collect_result_first: false,
    failure_label: "effect operation generic arguments",
    loc,
    report_failure: true,
  })
}

///|
fn SemanticChecker::infer_operation_owner_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  payload_templates : Array[@types.Type],
  arguments : Array[@desugar.DesugaredExpr],
  result_template : @types.Type,
  expected_result : @types.Type?,
  effect_template : @types.Effect,
  expected_effect : @types.Effect?,
  loc : SourceSpan,
) -> InferredApplicationGenericArguments? {
  self.infer_application_generic_arguments(scope, type_parameters, {
    parameter_templates: payload_templates,
    argument_expressions: arguments,
    result_template: Some(result_template),
    expected_result,
    effect_template: Some(effect_template),
    expected_effect,
    collect_result_first: false,
    failure_label: "effect operation owner arguments",
    loc,
    report_failure: true,
  })
}

///|
fn SemanticChecker::infer_struct_literal_generic_arguments(
  self : SemanticChecker,
  scope : TypeScope,
  type_parameters : Array[@types.TypeParameter],
  field_templates : Array[@types.Type],
  field_expressions : Array[@desugar.DesugaredExpr],
  result_template : @types.Type,
  expected_result : @types.Type?,
  loc : SourceSpan,
) -> InferredApplicationGenericArguments? {
  self.infer_application_generic_arguments(scope, type_parameters, {
    parameter_templates: field_templates,
    argument_expressions: field_expressions,
    result_template: Some(result_template),
    expected_result,
    effect_template: None,
    expected_effect: None,
    collect_result_first: true,
    failure_label: "struct literal generic arguments",
    loc,
    report_failure: true,
  })
}

///|
fn SemanticChecker::report_generic_argument_inference_failure(
  self : SemanticChecker,
  label : String,
  inference : GenericArgumentInference,
  loc : SourceSpan,
) -> Unit {
  let failure = match inference.failure {
    Some(failure) => failure
    None => MissingGenericArguments(parameters=[])
  }
  self.diagnostics.push({
    kind: GenericArgumentInferenceFailed(label~, failure~),
    loc: match inference.failure_loc {
      Some(failure_loc) => failure_loc
      None => loc
    },
  })
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
        type_: normalize_type_or_error(
          self.diagnostics,
          body.substitute(substitution),
          loc,
          context="explicit generic application result",
        ),
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
    callee=generic_callee_name(callee),
    callee_loc=Some(callee.loc()),
  )
}

///|
fn generic_callable_inference_label(callee : @desugar.DesugaredExpr) -> String {
  match generic_callee_name(callee) {
    Some(name) => name
    None => "generic arguments"
  }
}

///|
fn generic_callee_name(callee : @desugar.DesugaredExpr) -> String? {
  match callee {
    Var(name~, ..) => Some(name)
    Field(name~, ..) => Some(name)
    GenericApplication(callee~, ..) => generic_callee_name(callee)
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
  inference_label : String,
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
      loc,
      report_failure,
    ) {
    return None
  }
  guard self.infer_application_generic_arguments(scope, type_parameters, {
      parameter_templates: parameters,
      argument_expressions: call_argument_expressions(arguments),
      result_template: Some(result),
      expected_result,
      effect_template: None,
      expected_effect: None,
      collect_result_first: false,
      failure_label: inference_label,
      loc,
      report_failure,
    })
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
