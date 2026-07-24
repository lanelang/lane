///|
fn GenericArgumentInference::remember_effect_lower_bound(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  effect : @types.Effect,
) -> Bool {
  for index in 0..<self.bindings.length() {
    let previous = self.bindings[index]
    if previous.parameter != parameter {
      continue
    }
    guard previous.argument is EffectArgument(previous_effect) else {
      return self.fail(
        GenericArgumentConstraintMismatch(
          expected=previous.argument,
          actual=EffectArgument(effect),
        ),
      )
    }
    if previous.mode is EffectLowerBoundConstraint {
      let combined : @types.GenericArgument = EffectArgument(
        @types.Effect::Union([previous_effect, effect]).canonicalize(),
      )
      let evidence = self.classify_generic_argument_evidence(combined)
      self.bindings[index] = {
        parameter,
        argument: evidence.argument,
        is_provisional: evidence.is_provisional,
        mode: EffectLowerBoundConstraint,
      }
      return true
    }
    let allowed = effect.is_subeffect_of(previous_effect) catch {
      error => {
        self.record_computation_error(error)
        return false
      }
    }
    if allowed {
      return true
    }
    guard self.tracked_parameter(parameter) is Some(tracked) else {
      return true
    }
    return self.fail(
      ConflictingGenericArgument(
        parameter=tracked,
        previous=previous.argument,
        actual=EffectArgument(effect),
      ),
    )
  }
  if !self.remember(parameter, EffectArgument(effect)) {
    return false
  }
  for index in 0..<self.bindings.length() {
    if self.bindings[index].parameter == parameter {
      self.bindings[index] = {
        ..self.bindings[index],
        mode: EffectLowerBoundConstraint,
      }
      return true
    }
  }
  true
}

///|
fn GenericArgumentInference::collect_effect_upper_bound(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> Bool {
  // Function effects are upper bounds. Concrete terms in the template cover
  // matching actual terms, while a tracked row parameter accumulates the
  // unmatched lower bound required by all call arguments.
  let instantiated = template.substitute(self.exact_substitution())
  match self.match_effect_upper_bound_rows(instantiated, actual) {
    EffectRowsMatched(term_pairs~, residual_parameter~, residual_effect~) =>
      for pair in term_pairs {
        if !self.collect_effect_term(pair.template, pair.actual) {
          return false
        }
      } nobreak {
        match residual_parameter {
          Some(parameter) =>
            self.remember_effect_lower_bound(parameter, residual_effect)
          None => true
        }
      }
    EffectRowsMismatched =>
      self.fail(
        GenericArgumentConstraintMismatch(
          expected=EffectArgument(template),
          actual=EffectArgument(actual),
        ),
      )
    EffectRowsAmbiguous =>
      self.fail(AmbiguousEffectRowInference(expected=template, actual~))
  }
}

///|
fn GenericArgumentInference::match_effect_upper_bound_rows(
  self : GenericArgumentInference,
  template : @types.Effect,
  actual : @types.Effect,
) -> EffectRowMatch {
  guard self.effect_row_pattern(template) is Some(pattern) else {
    return EffectRowsAmbiguous
  }
  let actual_terms = effect_terms(actual)
  let used_templates = []
  for _ in pattern.concrete_terms {
    used_templates.push(false)
  }
  let term_pairs = []
  let residual_terms = []
  for actual_term in actual_terms {
    match
      self.unique_upper_effect_term_candidate(
        actual_term,
        pattern.concrete_terms,
        used_templates,
      ) {
      UniqueEffectTermCandidate(index) => {
        term_pairs.push({
          template: pattern.concrete_terms[index],
          actual: actual_term,
        })
        used_templates[index] = true
      }
      NoEffectTermCandidate =>
        if pattern.row_parameter is Some(_) {
          residual_terms.push(actual_term)
        } else {
          return EffectRowsMismatched
        }
      AmbiguousEffectTermCandidate => return EffectRowsAmbiguous
    }
  }
  EffectRowsMatched(
    term_pairs~,
    residual_parameter=pattern.row_parameter,
    residual_effect=effect_from_terms(residual_terms),
  )
}

///|
fn GenericArgumentInference::unique_upper_effect_term_candidate(
  self : GenericArgumentInference,
  actual : @types.Effect,
  templates : Array[@types.Effect],
  used : Array[Bool],
) -> EffectTermCandidateResult {
  let mut found_index : Int? = None
  for index in 0..<templates.length() {
    if !used[index] && self.effect_term_candidate(templates[index], actual) {
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
