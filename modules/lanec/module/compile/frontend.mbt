///|
priv struct CheckedModule {
  module_path_text : String
  checked : @checked.CheckedSourceFile
  interface : @module_interface.ModuleInterface
  interface_fingerprint : @artifact.CompilationFingerprint
  fingerprint : @artifact.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact.ImportedInterfaceFingerprint,
  ]
  exported_symbols : @symbol.SymbolMetadataArena
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct CheckedModuleSet {
  root_module_path_text : String
  modules : Array[CheckedModule]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn checked_module_interfaces(
  modules : Array[CheckedModule],
) -> @module_interface.ModuleInterfaceCatalog {
  { modules: modules.map(fn(module_) { module_.interface }), }
}

///|
fn compile_one_module(
  input : @module_frontend.ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  environments : @module_interface.ModuleImportEnvironments,
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[CheckedModule, Array[CompilerDiagnostic]] {
  let direct = environments.direct
  let elaborated = @source_elaboration.elaborate_source(
    input, registry, environments,
  )
  if elaborated is ResolutionFailed(_) {
    return Err(elaborated.diagnostics())
  }
  observe(input.header.module_path_text, Resolved(elaborated.resolved_source()))
  guard elaborated is Succeeded(success) else {
    return Err(elaborated.diagnostics())
  }
  // Source Elaboration and linting observe source order. Batch compilation
  // alone materializes initialization order before persistent lowering.
  let checked = match success.checked_source().in_initialization_order() {
    Ok(ordered) => ordered
    Err(members) =>
      return Err([
        initialization_cycle_diagnostic(members).with_source_id(input.source_id),
      ])
  }
  let interface = success.module_interface()
  let imported_fingerprints = @artifact.imported_environment_fingerprints(
    direct,
  )
  let interface_fingerprint = @artifact.interface_fingerprint(interface)
  let fingerprint = @artifact.module_fingerprint(
    interface, imported_fingerprints,
  )
  Ok({
    module_path_text: input.header.module_path_text,
    checked,
    interface,
    interface_fingerprint,
    fingerprint,
    imported_interface_fingerprints: imported_fingerprints,
    exported_symbols: success.exported_symbols(),
    diagnostics: success.warnings(),
  })
}

///|
fn find_checked_module(
  modules : Array[CheckedModule],
  path : String,
) -> CheckedModule? {
  for module_ in modules {
    if module_.module_path_text == path {
      return Some(module_)
    }
  }
  None
}
