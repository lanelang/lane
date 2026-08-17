///|
pub(all) struct ModuleObject {
  module_path_text : String
  interface_fingerprint : @artifact.CompilationFingerprint
  canonical_basic_abi : @canonical_basic_abi.CanonicalBasicAbiRuntimeContract
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact.ModuleImportedReference]
  fingerprint : @artifact.CompilationFingerprint
  object_fingerprint : @artifact.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
/// Trusted output of compiling one source module inside this package. The
/// interface and object share the same fresh symbol registry and fingerprints.
pub struct CompiledModule {
  checked : @checked.CheckedSourceFile
  interface : @module_interface.ModuleInterface
  object : ModuleObject
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
    canonical_basic_abi: object.canonical_basic_abi,
    program: object.program,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    fingerprint: object.fingerprint,
    object_fingerprint_valid: object.object_fingerprint ==
    @artifact.module_object_fingerprint(
      object.fingerprint,
      object.interface_fingerprint,
      object.canonical_basic_abi,
      object.program.metadata,
      object.program.terms,
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
/// Ordered compiler-owned module products for one import-reachable graph.
/// `diagnostics` contains warnings only; blocking errors prevent construction.
pub(all) struct CompiledModuleSet {
  root_module_path_text : String
  modules : Array[CompiledModule]
  diagnostics : Array[CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub(all) enum ModuleCompileStage {
  Resolved(@resolve.ResolvedSourceFile)
  Checked(@checked.CheckedSourceFile)
  BuslaneModule(@buslane.Program)
}

///|
/// Compiles graph modules in dependency order. A blocking module failure stops
/// the pipeline and returns diagnostics without a partial `CompiledModuleSet`.
pub fn compile_module_graph(
  graph : @module_frontend.ModuleGraph,
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  compile_module_graph_observed(graph, (_, _) => ())
}

///|
/// Compiles a graph while synchronously observing each completed module stage.
/// Calls follow dependency order and stop after the first blocking failure.
pub fn compile_module_graph_observed(
  graph : @module_frontend.ModuleGraph,
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  let checked = match check_module_graph(graph, observe) {
    Ok(checked) => checked
    Err(diagnostics) => return Err(diagnostics)
  }
  let modules = match lower_checked_modules(checked.modules, observe) {
    Ok(modules) => modules
    Err(diagnostic) => return Err([diagnostic])
  }
  Ok({
    root_module_path_text: checked.root_module_path_text,
    modules,
    diagnostics: checked.diagnostics,
  })
}

///|
fn check_module_graph(
  graph : @module_frontend.ModuleGraph,
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[CheckedModuleSet, Array[CompilerDiagnostic]] {
  let allocator = @symbol.SymbolIdentityAllocator::SymbolIdentityAllocator()
  let visible_symbols : Array[@symbol.SymbolMetadataArena] = []
  let checked_modules : Array[CheckedModule] = []
  let diagnostics : Array[CompilerDiagnostic] = []
  for input in graph.modules() {
    let environments = @module_interface.ModuleImportEnvironments::from_pool(
      input.header.imports.map(fn(import_) { import_.module_path_text }),
      checked_module_interfaces(checked_modules),
    )
    let registry = allocator.registry(imports=visible_symbols)
    match compile_one_module(input, registry, environments, observe) {
      Ok(compiled) => {
        observe(input.header.module_path_text, Checked(compiled.checked))
        checked_modules.push(compiled)
        visible_symbols.push(compiled.exported_symbols)
        diagnostics.append(compiled.diagnostics)
      }
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  Ok({
    root_module_path_text: graph.root_module_path_text(),
    modules: checked_modules,
    diagnostics,
  })
}

///|
/// Compiles one root source against untrusted persisted interfaces. Reachable
/// interface schemas, identities, dependency fingerprints, and symbol metadata
/// are validated and freshened before they enter source checking.
pub fn compile_module_from_interface_artifacts(
  root_source : @module_frontend.SourceInput,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> Result[CompiledModuleSet, Array[CompilerDiagnostic]] {
  let parsed = @module_frontend.parse_source(root_source)
  let input = match parsed {
    Unavailable(source) => return Err(source.diagnostics)
    Available(input) => input
  }
  let ordered_interfaces = reachable_interface_artifacts(
    input.header,
    interfaces,
    root_source.source_id,
  )
  let import_diagnostics = ordered_interfaces.diagnostics
  if !import_diagnostics.is_empty() {
    return Err(
      import_diagnostics.map(fn(diagnostic) {
        diagnostic.with_source_id(root_source.source_id)
      }),
    )
  }
  let allocator = @symbol.SymbolIdentityAllocator::SymbolIdentityAllocator()
  let registry = allocator.registry()
  let imported = freshen_module_interface_artifacts(
    registry,
    ordered_interfaces.interfaces,
  )
  let environments = @module_interface.ModuleImportEnvironments::from_pool(
    input.header.imports.map(fn(import_) { import_.module_path_text }),
    imported,
  )
  match compile_one_module(input, registry, environments, (_, _) => ()) {
    Err(diagnostics) => Err(diagnostics)
    Ok(success) => {
      let imported_fingerprints = imported_interface_fingerprints_from_artifacts(
        input.header,
        ordered_interfaces.interfaces,
      )
      let module_ = success.with_imported_interface_fingerprints(
        imported_fingerprints,
      )
      let lowered = match
        @buslane_lowering.lower_checked_source_file_to_buslane_object_with_imports(
          module_.checked,
          environments,
        ) {
        Ok(lowered) => lowered
        Err(error) =>
          return Err([
            buslane_lowering_diagnostic(module_.module_path_text, error),
          ])
      }
      let compiled = compiled_module_from_lowered_interfaces(
        module_,
        lowered,
        ordered_interfaces.interfaces,
      )
      Ok({
        root_module_path_text: compiled.object.module_path_text,
        modules: [compiled],
        diagnostics: success.diagnostics,
      })
    }
  }
}
