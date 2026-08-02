///|
fn validate_executable_entry(
  metadata : @buslane.MetadataRegistry,
  entry : @buslane_lowering.BuslaneEntry,
) -> Unit raise ExecutableElaborationError {
  guard entry.type_ is Function(parameters, Primitive(Unit), effect) &&
    parameters.is_empty() &&
    entry_effect_is_executable(metadata, effect) else {
    raise InvalidEntryFunction(value=entry.value, type_=entry.type_)
  }
}

///|
pub fn entry_effect_is_executable(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> Bool {
  if !entry_effect_is_closed(effect) {
    return false
  }
  match metadata.canonicalize_effect(effect) {
    Empty | Io => true
    Singleton(effect_id, _) =>
      metadata
      .effect_info(effect_id)
      .map_or(false, info => info.flavor is External)
    Union(effects) =>
      effects.all(effect => entry_effect_is_executable(metadata, effect))
    Parameter(_) => false
  }
}

///|
fn entry_effect_is_closed(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty | Io => true
    Parameter(_) => false
    Singleton(_, arguments) => arguments.all(entry_argument_is_closed)
    Union(effects) => effects.all(entry_effect_is_closed)
  }
}

///|
fn entry_argument_is_closed(argument : @buslane.GenericArgument) -> Bool {
  match argument {
    TypeArgument(type_) => entry_type_is_closed(type_)
    EffectArgument(effect) => entry_effect_is_closed(effect)
  }
}

///|
fn entry_type_is_closed(type_ : @buslane.Type) -> Bool {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => true
    Apply(callee, arguments) =>
      entry_type_is_closed(callee) && arguments.all(entry_argument_is_closed)
    TypeLambda(_, body) | Forall(_, body) => entry_type_is_closed(body)
    Function(parameters, result, effect) =>
      parameters.all(entry_type_is_closed) &&
      entry_type_is_closed(result) &&
      entry_effect_is_closed(effect)
  }
}
