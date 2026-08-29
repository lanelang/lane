///|
pub fn link_compiled_module_set(
  modules : CompiledModuleSet,
) -> @module_link.LinkResult {
  let linked = @module_link.link_reachable_modules(
    modules.modules.map(CompiledModule::to_link_object),
    modules.root_module_path_text,
  )
  { ..linked, diagnostics: modules.diagnostics + linked.diagnostics, }
}

///|
pub fn link_compiled_module_set_observed(
  modules : CompiledModuleSet,
  observe : (@module_link.LinkRetentionObservation) -> Unit,
) -> @module_link.LinkResult {
  let linked = @module_link.link_reachable_modules_observed(
    modules.modules.map(CompiledModule::to_link_object),
    modules.root_module_path_text,
    observe,
  )
  { ..linked, diagnostics: modules.diagnostics + linked.diagnostics, }
}

///|
pub fn link_compiled_modules(
  modules : Array[CompiledModule],
) -> @module_link.LinkResult {
  @module_link.link_modules(modules.map(CompiledModule::to_link_object))
}
