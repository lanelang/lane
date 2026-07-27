///|
priv struct GenericEffectLowerBound {
  parameter : TypeParameterId
  effect : @types.Effect
  is_provisional : Bool
}

///|
fn GenericArgumentInference::remember_effect_lower_bound(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  effect : @types.Effect,
) -> Bool {
  let evidence = self.classify_generic_argument_evidence(EffectArgument(effect))
  guard evidence.argument is EffectArgument(bound) else { return false }
  if !evidence.is_provisional {
    for binding in self.bindings {
      if binding.parameter != parameter || binding.is_provisional {
        continue
      }
      guard binding.argument is EffectArgument(exact) else {
        return self.fail(
          GenericArgumentConstraintMismatch(
            expected=binding.argument,
            actual=EffectArgument(bound),
          ),
        )
      }
      if !self.effect_lower_bound_is_allowed(parameter, bound, exact) {
        return false
      }
    }
  }
  self.effect_lower_bounds.push({
    parameter,
    effect: bound,
    is_provisional: evidence.is_provisional,
  })
  true
}

///|
fn GenericArgumentInference::exact_effect_binding_accepts_lower_bounds(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  candidate : @types.GenericArgument,
) -> Bool {
  guard candidate is EffectArgument(exact) else { return true }
  for lower_bound in self.effect_lower_bounds {
    if lower_bound.parameter != parameter || lower_bound.is_provisional {
      continue
    }
    if !self.effect_lower_bound_is_allowed(parameter, lower_bound.effect, exact) {
      return false
    }
  }
  true
}

///|
fn GenericArgumentInference::effect_lower_bound_is_allowed(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  lower : @types.Effect,
  exact : @types.Effect,
) -> Bool {
  let allowed = lower.is_subeffect_of(exact) catch {
    error => {
      self.record_computation_error(error)
      return false
    }
  }
  if allowed {
    return true
  }
  guard self.tracked_parameter(parameter) is Some(tracked) else { return true }
  self.fail(
    ConflictingGenericArgument(
      parameter=tracked,
      previous=EffectArgument(lower),
      actual=EffectArgument(exact),
    ),
  )
}

///|
fn GenericArgumentInference::combined_effect_lower_bound(
  self : GenericArgumentInference,
  parameter : TypeParameterId,
  include_provisional? : Bool = false,
) -> @types.Effect? {
  let effects = []
  for lower_bound in self.effect_lower_bounds {
    if lower_bound.parameter == parameter &&
      (include_provisional || !lower_bound.is_provisional) {
      effects.push(lower_bound.effect)
    }
  }
  match effects {
    [] => None
    [effect] => Some(effect)
    effects => Some(@types.Effect::Union(effects).canonicalize())
  }
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
