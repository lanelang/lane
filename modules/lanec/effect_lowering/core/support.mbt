///|
pub fn effect_has_parameter(effect : @buslane.Effect) -> Bool {
  effect_terms(effect).any(term => term is Parameter(_))
}

///|
pub fn is_mon_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> Bool {
  effect_terms(effect).any(term => {
    match term {
      Parameter(_) => true
      Singleton(effect_id, _) =>
        metadata
        .effect_info(effect_id)
        .map_or(true, fn(info) {
          info.flavor is @buslane.EffectFlavor::Algebraic
        })
      _ => false
    }
  })
}

///|
pub fn mon_effect_part(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  @buslane.Effect::Union(
    effect_terms(effect).filter(fn(term) {
      match term {
        Io => false
        Singleton(effect_id, _) =>
          metadata
          .effect_info(effect_id)
          .map_or(true, fn(info) {
            info.flavor is @buslane.EffectFlavor::Algebraic
          })
        _ => true
      }
    }),
  ).canonicalize()
}

///|
pub fn residual_effect_part(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect {
  @buslane.Effect::Union(
    effect_terms(effect).filter(fn(term) {
      match term {
        Io => true
        Singleton(effect_id, _) =>
          match metadata.effect_info(effect_id) {
            Some(info) => info.flavor is @buslane.EffectFlavor::External
            None => false
          }
        _ => false
      }
    }),
  ).canonicalize()
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
