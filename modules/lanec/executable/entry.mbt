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
  if effect_contains_parameter(effect) {
    return false
  }
  match effect.canonicalize() {
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
