///|
pub fn effect_has_parameter(effect : @buslane.Effect) -> Bool {
  effect_terms(effect).any(term => term is Parameter(_))
}

///|
pub fn is_mon_effect(effect : @buslane.Effect) -> Bool {
  effect_terms(effect).any(term => {
    term is Parameter(_) || term is Singleton(_, _)
  })
}

///|
pub fn mon_effect_part(effect : @buslane.Effect) -> @buslane.Effect {
  @buslane.Effect::Union(
    effect_terms(effect).filter(fn(term) {
      match term {
        Io => false
        _ => true
      }
    }),
  ).canonicalize()
}

///|
pub fn residual_effect_part(effect : @buslane.Effect) -> @buslane.Effect {
  if effect_terms(effect).any(term => term is Io) {
    Io
  } else {
    Empty
  }
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
