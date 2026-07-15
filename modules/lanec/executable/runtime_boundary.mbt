///|
fn install_runtime_boundary(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  _operations : Array[@module_link.LinkedRuntimeEffectOperation],
) -> (
  @buslane.Program,
  @buslane_lowering.BuslaneExternalMap,
  @buslane_lowering.BuslaneEntry,
  Array[@module_link.LinkedRuntimeEffectOperation],
) raise ExecutableElaborationError {
  guard entry.type_ is Function(parameters, Primitive(Unit), effect) &&
    parameters.is_empty() &&
    entry_effect_is_executable(effect) else {
    raise InvalidEntryFunction(value=entry.value, type_=entry.type_)
  }
  (program, externals, entry, [])
}

///|
fn entry_effect_is_executable(effect : @buslane.Effect) -> Bool {
  match effect.canonicalize() {
    Empty | Io => true
    _ => false
  }
}
