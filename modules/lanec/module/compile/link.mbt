///|
pub fn link_compiled_module_set(
  modules : CompiledModuleSet,
) -> @module_link.LinkResult {
  let linked = @module_link.link_reachable_modules(
    modules.modules.map(CompiledModule::to_link_object),
    modules.root_module_path_text,
  )
  { ..linked, diagnostics: modules.diagnostics + linked.diagnostics }
}

///|
pub fn link_compiled_modules(
  modules : Array[CompiledModule],
) -> @module_link.LinkResult {
  @module_link.link_modules(modules.map(CompiledModule::to_link_object))
}
