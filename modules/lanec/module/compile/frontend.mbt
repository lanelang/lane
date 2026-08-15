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
  reachable_module_path_texts : Array[String]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn checked_module_interfaces(
  modules : Array[CheckedModule],
) -> @module_interface.ModuleInterfaceCatalog {
  { modules: modules.map(fn(module_) { module_.interface }) }
}

///|
fn compile_one_module(
  input : @module_frontend.ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  environments : @module_interface.ModuleImportEnvironments,
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[CheckedModule, Array[CompilerDiagnostic]] {
  let direct = environments.direct
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    environments.available,
  )
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    resolve_diagnostic(diagnostic, display).with_source_id(input.source_id)
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  observe(input.header.module_path_text, Resolved(resolved.source))
  let checked = match
    @typecheck.typecheck_checked_source_file_with_imported_environment(
      resolved.source,
      environments.typecheck_environment(),
    ) {
    Ok(checked) => checked
    Err(error) =>
      return Err([
        compile_boundary_diagnostic(TypecheckInvalidInputMetadata(error), None).with_source_id(
          input.source_id,
        ),
      ])
  }
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
      // Lint reads the module as written; everything downstream reads it in
      // initialization order. Ordering here, after the source-order readers
      // and before the module is stored, keeps the order a property of the
      // declaration list rather than a table each later stage must consult.
      let checked = match checked.in_initialization_order() {
        Ok(ordered) => ordered
        Err(members) =>
          return Err([
            initialization_cycle_diagnostic(members).with_source_id(
              input.source_id,
            ),
          ])
      }
      let interface = { ..interface, source_id: Some(input.source_id) }
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
