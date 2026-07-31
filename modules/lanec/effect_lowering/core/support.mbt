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
    metadata.effect_term_is_algebraic(term)
  })
}

///|
pub fn mon_effect_part(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  metadata.canonicalize_effect(
    Union(
      effect_terms(metadata, effect).filter(fn(term) {
        metadata.effect_term_is_algebraic(term)
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
        !metadata.effect_term_is_algebraic(term)
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
