///|
pub(all) struct ModuleObject {
  module_path_text : String
  checked : @checked.CheckedSourceFile
  interface_fingerprint : @artifact_core.CompilationFingerprint
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact_core.ModuleImportedReference]
  fingerprint : @artifact_core.CompilationFingerprint
  object_fingerprint : @artifact_core.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModule {
  module_path_text : String
  interface : @module_interface.ModuleInterface
  object : ModuleObject
  fingerprint : @artifact_core.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
fn CompiledModule::to_link_object(
  self : CompiledModule,
) -> @module_link.LinkModuleObject {
  let object = self.object
  {
    module_path_text: object.module_path_text,
    interface: Some(self.interface),
    interface_fingerprint: object.interface_fingerprint,
    metadata: object.metadata,
    terms: object.terms,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    fingerprint: self.fingerprint,
    object_fingerprint_valid: object.object_fingerprint ==
    module_object_fingerprint(
      object.fingerprint,
      object.interface_fingerprint,
      object.metadata,
      object.terms,
      object.externals,
      object.entries,
      object.exports,
      object.imports,
      object.imported_interface_fingerprints,
    ),
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
}

///|
pub(all) struct CompiledModuleSet {
  root_module_path_text : String
  modules : Array[CompiledModule]
  reachable_module_path_texts : Array[String]
  diagnostics : Array[CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub fn compile_module_graph(
  graph : @module_frontend.ModuleGraph,
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let modules : Array[CompiledModule] = []
  let diagnostics : Array[CompilerDiagnostic] = []
  for input in graph.modules {
    let imported = imported_interfaces(input.header, modules)
    match compile_one_module(input, registry, imported) {
      Ok(compiled) => {
        modules.push(compiled.module_)
        diagnostics.append(compiled.diagnostics)
      }
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  if find_compiled_module(modules, graph.root_module_path_text) is None {
    return Err([compile_boundary_diagnostic(NoRootSourceModule, None)])
  }
  Ok({
    root_module_path_text: graph.root_module_path_text,
    modules: lower_compiled_module_objects(modules),
    reachable_module_path_texts: graph.reachable_module_path_texts,
    diagnostics,
  })
}

///|
pub fn compile_module_from_interface_artifacts(
  root_source : @module_frontend.SourceInput,
  interfaces : Array[ModuleInterfaceArtifact],
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  let parsed = @module_frontend.parse_module_inputs(root_source, [])
  if !parsed.diagnostics.is_empty() {
    return Err(parsed.diagnostics)
  }
  guard parsed.modules.get(0) is Some(input) else {
    return Err([compile_boundary_diagnostic(NoRootSourceModule, None)])
  }
  let ordered_interfaces = reachable_interface_artifacts(
    input.header,
    interfaces,
  )
  let import_diagnostics = ordered_interfaces.diagnostics
  if !import_diagnostics.is_empty() {
    return Err(
      import_diagnostics.map(fn(diagnostic) {
        diagnostic.with_source_id(root_source.source_id)
      }),
    )
  }
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let imported = freshen_module_interface_artifacts(
    registry,
    ordered_interfaces.interfaces,
  )
  match compile_one_module(input, registry, imported) {
    Err(diagnostics) => Err(diagnostics)
    Ok(success) => {
      let module_ = success.module_
      let imported_fingerprints = imported_interface_fingerprints_from_artifacts(
        input.header,
        ordered_interfaces.interfaces,
      )
      let module_ = module_.with_imported_interface_fingerprints(
        imported_fingerprints,
      )
      let lowered = @buslane_lowering.lower_checked_source_file_to_buslane_object_with_imports(
        module_.object.checked,
        imported,
      )
      let compiled = attach_lowered_object_from_interfaces(
        module_,
        lowered,
        ordered_interfaces.interfaces,
      )
      Ok({
        root_module_path_text: compiled.module_path_text,
        modules: [compiled],
        reachable_module_path_texts: [compiled.module_path_text],
        diagnostics: success.diagnostics,
      })
    }
  }
}
