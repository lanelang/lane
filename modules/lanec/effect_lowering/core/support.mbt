///|
pub fn effect_has_parameter(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty | Io | Singleton(_, _) => false
    Parameter(_) => true
    Union(effects) => effects.any(effect_has_parameter)
  }
}

///|
pub fn is_mon_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> Bool {
  effect_terms(metadata, effect).any(term => {
    algebraic_effect_term(metadata, term)
  })
}

///|
/// Whether a canonical effect term still needs lowering.
///
/// A term is algebraic when its declaration says so, and an effect parameter
/// when the rows it ranges over may hold algebraic terms. The residual
/// parameter selective CPS introduces ranges only over residual rows, so it is
/// not itself something to lower.
fn algebraic_effect_term(
  metadata : @buslane.MetadataRegistry,
  term : @buslane.Effect,
) -> Bool {
  match term {
    Io => false
    Singleton(effect_id, _) =>
      metadata
      .effect_info(effect_id)
      .map_or(true, fn(info) { info.flavor is Algebraic })
    Parameter(parameter) =>
      metadata
      .type_parameter_info(parameter)
      .map_or(true, fn(info) { info.flavor is Algebraic })
    Empty | Union(_) => false
  }
}

///|
pub fn mon_effect_part(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  metadata.canonicalize_effect(
    Union(
      effect_terms(metadata, effect).filter(fn(term) {
        algebraic_effect_term(metadata, term)
      }),
    ),
  )
}

///|
pub fn residual_effect_part(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  metadata.canonicalize_effect(
    Union(
      effect_terms(metadata, effect).filter(fn(term) {
        !algebraic_effect_term(metadata, term)
      }),
    ),
  )
}

///|
pub fn set_source_resume_effect(
  metadata : @buslane.MetadataRegistry,
  resume_binder : @buslane.ValueId,
  effect : @buslane.Effect,
) -> Unit raise SynthesisError {
  guard metadata.value_info(resume_binder) is Some(info) else {
    raise UnknownValue(resume_binder)
  }
  guard info.type_ is Function([parameter], result, _) else {
    raise ExpectedFunction(info.type_)
  }
  metadata.values[resume_binder.index] = {
    name: info.name,
    kind: info.kind,
    type_: Function([parameter], result, effect),
  }
}
