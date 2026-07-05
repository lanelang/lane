///|
priv struct CompileOneModuleSuccess {
  module_ : CompiledModule
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn imported_interfaces(
  header : ModuleHeader,
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
  input : ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  imported : @module_interface.ImportedEnvironment,
) -> Result[CompileOneModuleSuccess, Array[CompilerDiagnostic]] {
  let display = TypeDisplayContext::from_registry(registry)
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
      let warning_diagnostics = checked_unused_local_value_binding_diagnostics(
        checked,
        input.text,
      ).map(fn(diagnostic) { diagnostic.with_source_id(input.source_id) })
      let interface = { ..interface, source_id: Some(input.source_id) }
      let imported_fingerprints = imported_environment_fingerprints(imported)
      let fingerprint = module_fingerprint(interface, imported_fingerprints)
      let object_fingerprint = module_object_fingerprint(
        fingerprint,
        MetadataRegistry(),
        [],
        { builtins: [] },
        [],
        [],
        [],
        imported_fingerprints,
      )
      let object : ModuleObject = {
        module_path_text: input.header.module_path_text,
        checked,
        metadata: MetadataRegistry(),
        terms: [],
        externals: { builtins: [] },
        entries: [],
        exports: [],
        imports: [],
        fingerprint,
        object_fingerprint,
        imported_interface_fingerprints: imported_fingerprints,
      }
      Ok({
        module_: {
          module_path_text: input.header.module_path_text,
          interface,
          object,
          fingerprint,
          imported_interface_fingerprints: imported_fingerprints,
        },
        diagnostics: warning_diagnostics,
      })
    }
    _ =>
      Err([
        CompileErrorKind::to_diagnostic(CheckedSourceConstructionFailed, None).with_source_id(
          input.source_id,
        ),
      ])
  }
}
