///|
fn GenericArgumentInference::remember_effect_lower_bound(
  self : GenericArgumentInference,
  tracked : @types.TypeParameter,
  effect : @types.Effect,
) -> Bool {
  let evidence = self.classify_generic_argument_evidence(EffectArgument(effect))
  if !evidence.is_provisional {
    for binding in self.bindings {
      if binding.parameter.id != tracked.id {
        continue
      }
      if binding.constraint
        is ExactConstraint(argument=exact_argument, is_provisional=false) {
        match exact_argument {
          EffectArgument(exact) =>
            if !self.effect_lower_bound_is_allowed(tracked, effect, exact) {
              return false
            }
          TypeArgument(_) =>
            return self.fail(
              GenericArgumentConstraintMismatch(
                expected=exact_argument,
                actual=EffectArgument(effect),
              ),
            )
        }
      }
    }
  }
  self.bindings.push({
    parameter: tracked,
    constraint: EffectLowerBoundConstraint(
      effect~,
      is_provisional=evidence.is_provisional,
    ),
  })
  true
}

///|
fn GenericArgumentInference::exact_effect_binding_accepts_lower_bounds(
  self : GenericArgumentInference,
  tracked : @types.TypeParameter,
  exact : @types.Effect,
) -> Bool {
  for binding in self.bindings {
    if binding.parameter.id != tracked.id {
      continue
    }
    if binding.constraint
      is EffectLowerBoundConstraint(effect=lower, is_provisional=false) {
      if !self.effect_lower_bound_is_allowed(tracked, lower, exact) {
        return false
      }
    }
  }
  true
}

///|
fn GenericArgumentInference::effect_lower_bound_is_allowed(
  self : GenericArgumentInference,
  tracked : @types.TypeParameter,
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
  tracked : @types.TypeParameter,
  include_provisional? : Bool = false,
) -> @types.Effect? {
  let effects = []
  for binding in self.bindings {
    if binding.parameter.id == tracked.id &&
      binding.constraint is EffectLowerBoundConstraint(effect~, is_provisional~) &&
      (include_provisional || !is_provisional) {
      effects.push(effect)
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
      unique_effect_term_candidate(pattern.concrete_terms, used_templates, fn(
        template,
      ) {
        self.effect_term_candidate(template, actual_term)
      }) {
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
