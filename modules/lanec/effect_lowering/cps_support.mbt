///|
fn synthesize_cps_callee_or_raise(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
) -> ExprFacts raise SynthesisError {
  let argument_groups = []
  let base = collect_cps_type_applications(callee, argument_groups)
  if !argument_groups.is_empty() {
    let base_facts = synthesize_expr_or_raise(metadata, base)
    if base_facts.type_ is Function(_, _, _) {
      return base_facts
    }
  }
  synthesize_expr_or_raise(metadata, callee)
}

///|
fn[T] cps_normalization_or_synthesis_defect(
  compute : () -> T raise @buslane.TypeNormalizationError,
) -> T raise SynthesisError {
  compute() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
}

///|
fn cps_types_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Type,
  right : @buslane.Type,
) -> Bool raise SynthesisError {
  cps_normalization_or_synthesis_defect(() => {
    metadata.types_definitionally_equal(left, right)
  })
}

///|
fn cps_type_is_consumable_as(
  metadata : @buslane.MetadataRegistry,
  actual : @buslane.Type,
  expected : @buslane.Type,
) -> Bool raise SynthesisError {
  cps_normalization_or_synthesis_defect(() => {
    metadata.type_is_consumable_as(actual, expected)
  })
}

///|
fn cps_effects_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Effect,
  right : @buslane.Effect,
) -> Bool raise SynthesisError {
  cps_normalization_or_synthesis_defect(() => {
    metadata.effects_definitionally_equal(left, right)
  })
}

///|
fn cps_effect_is_subeffect_of(
  metadata : @buslane.MetadataRegistry,
  lower : @buslane.Effect,
  upper : @buslane.Effect,
) -> Bool raise SynthesisError {
  cps_normalization_or_synthesis_defect(() => {
    metadata.effect_is_subeffect_of(lower, upper)
  })
}

///|
fn cps_canonicalize_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect raise SynthesisError {
  cps_normalization_or_synthesis_defect(() => {
    metadata.canonicalize_effect(effect)
  })
}
