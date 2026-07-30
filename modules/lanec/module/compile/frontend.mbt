///|
priv struct CheckedModule {
  module_path_text : String
  checked : @checked.CheckedSourceFile
  interface : @module_interface.ModuleInterface
  interface_fingerprint : @artifact_core.CompilationFingerprint
  fingerprint : @artifact_core.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
  exported_symbols : @symbol.SymbolMetadataArena
  diagnostics : Array[CompilerDiagnostic]
}

///|
priv struct CheckedModuleSet {
  root_module_path_text : String
  modules : Array[CheckedModule]
  reachable_module_path_texts : Array[String]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn imported_interfaces(
  header : @module_frontend.ModuleHeader,
  modules : Array[CheckedModule],
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if find_checked_module(modules, import_.module_path_text) is Some(module_) {
      imported.push(module_.interface)
    }
  }
  { modules: imported }
}

///|
fn imported_interface_closure(
  roots : Array[String],
  modules : Array[CheckedModule],
) -> @module_interface.ImportedEnvironment {
  let included : Array[String] = []
  for root in roots {
    collect_imported_interface_paths(root, modules, included)
  }
  {
    modules: modules
    .filter(fn(module_) { included.contains(module_.module_path_text) })
    .map(fn(module_) { module_.interface }),
  }
}

///|
fn collect_imported_interface_paths(
  module_path : String,
  modules : Array[CheckedModule],
  included : Array[String],
) -> Unit {
  if included.contains(module_path) {
    return
  }
  guard find_checked_module(modules, module_path) is Some(module_) else {
    return
  }
  for imported in module_.imported_interface_fingerprints {
    collect_imported_interface_paths(
      imported.module_path_text,
      modules,
      included,
    )
  }
  included.push(module_path)
}

///|
fn direct_imported_interfaces(
  header : @module_frontend.ModuleHeader,
  available : @module_interface.ImportedEnvironment,
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if available.find(import_.module_path_text) is Some(interface) {
      imported.push(interface)
    }
  }
  { modules: imported }
}

///|
fn typecheck_imported_interfaces(
  direct : @module_interface.ImportedEnvironment,
  available : @module_interface.ImportedEnvironment,
) -> @module_interface.ImportedEnvironment {
  {
    modules: available.modules.map(fn(interface) {
      if direct.find(interface.module_path) is Some(_) {
        interface
      } else {
        { ..interface, values: [], optimization_hints: [] }
      }
    }),
  }
}

///|
fn compile_one_module(
  input : @module_frontend.ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  direct : @module_interface.ImportedEnvironment,
  available : @module_interface.ImportedEnvironment,
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[CheckedModule, Array[CompilerDiagnostic]] {
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    direct,
  )
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    resolve_diagnostic(diagnostic, display).with_source_id(input.source_id)
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  observe(input.header.module_path_text, Resolved(resolved.source))
  let imported = typecheck_imported_interfaces(direct, available)
  let checked = @typecheck.typecheck_checked_source_file_with_imported_environment(
    resolved.source,
    imported,
  )
  let typecheck_diagnostics = checked.diagnostics.map(fn(diagnostic) {
    typecheck_diagnostic(diagnostic, display).with_source_id(input.source_id)
  })
  if !typecheck_diagnostics.is_empty() {
    return Err(typecheck_diagnostics)
  }
  match (checked.source, checked.module_interface) {
    (Some(checked), Some(interface)) => {
      let warning_diagnostics = @lint.checked_unused_local_value_binding_diagnostics(
        checked,
        registry,
        input.text,
      )
      warning_diagnostics.append(
        @lint.checked_semantic_warning_diagnostics(
          resolved.source,
          checked,
          input.text,
        ),
      )
      let warning_diagnostics = warning_diagnostics.map(fn(diagnostic) {
        diagnostic.with_source_id(input.source_id)
      })
      let interface = { ..interface, source_id: Some(input.source_id) }
      let imported_fingerprints = imported_environment_fingerprints(direct)
      let interface_fingerprint = interface_fingerprint(interface)
      let fingerprint = module_fingerprint(interface, imported_fingerprints)
      Ok({
        module_path_text: input.header.module_path_text,
        checked,
        interface,
        interface_fingerprint,
        fingerprint,
        imported_interface_fingerprints: imported_fingerprints,
        exported_symbols: interface.exported_symbol_metadata(registry),
        diagnostics: warning_diagnostics,
      })
    }
    _ =>
      Err([
        compile_boundary_diagnostic(CheckedSourceConstructionFailed, None).with_source_id(
          input.source_id,
        ),
      ])
  }
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
