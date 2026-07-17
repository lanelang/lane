///|
priv struct CompileOneModuleSuccess {
  module_ : CompiledModule
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn imported_interfaces(
  header : @module_frontend.ModuleHeader,
  modules : Array[CompiledModule],
) -> @module_interface.ImportedEnvironment {
  let imported = []
  for import_ in header.imports {
    if find_compiled_module(modules, import_.module_path_text) is Some(module_) {
      imported.push(module_.interface)
    }
  }
  { modules: imported }
}

///|
fn compile_one_module(
  input : @module_frontend.ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  imported : @module_interface.ImportedEnvironment,
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[CompileOneModuleSuccess, Array[CompilerDiagnostic]] {
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imported,
  )
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    resolve_diagnostic(diagnostic, display).with_source_id(input.source_id)
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  observe(input.header.module_path_text, Resolved(resolved.source))
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
      let warning_diagnostics = @analysis.checked_unused_local_value_binding_diagnostics(
        checked,
        input.text,
      )
      warning_diagnostics.append(
        @analysis.checked_semantic_warning_diagnostics(
          resolved.source,
          checked,
          input.text,
        ),
      )
      let warning_diagnostics = warning_diagnostics.map(fn(diagnostic) {
        diagnostic.with_source_id(input.source_id)
      })
      let interface = { ..interface, source_id: Some(input.source_id) }
      let imported_fingerprints = imported_environment_fingerprints(imported)
      let interface_fingerprint = interface_fingerprint(interface)
      let fingerprint = module_fingerprint(interface, imported_fingerprints)
      let object_fingerprint = module_object_fingerprint(
        fingerprint,
        interface_fingerprint,
        MetadataRegistry(),
        [],
        { builtins: [], runtime_imports: [] },
        [],
        [],
        [],
        imported_fingerprints,
      )
      let object : ModuleObject = {
        module_path_text: input.header.module_path_text,
        checked,
        interface_fingerprint,
        metadata: MetadataRegistry(),
        terms: [],
        externals: { builtins: [], runtime_imports: [] },
        entries: [],
        exports: [],
        imports: [],
        fingerprint,
        object_fingerprint,
        imported_interface_fingerprints: imported_fingerprints,
      }
      Ok({ module_: { interface, object }, diagnostics: warning_diagnostics })
    }
    _ =>
      Err([
        compile_boundary_diagnostic(CheckedSourceConstructionFailed, None).with_source_id(
          input.source_id,
        ),
      ])
  }
}
