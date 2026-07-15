///|
fn validate_executable_entry(
  entry : @buslane_lowering.BuslaneEntry,
) -> Unit raise ExecutableElaborationError {
  guard entry.type_ is Function(parameters, Primitive(Unit), effect) &&
    parameters.is_empty() &&
    entry_effect_is_executable(effect) else {
    raise InvalidEntryFunction(value=entry.value, type_=entry.type_)
  }
}

///|
fn entry_effect_is_executable(effect : @buslane.Effect) -> Bool {
  match effect.canonicalize() {
    Empty | Io => true
    _ => false
  }
}
