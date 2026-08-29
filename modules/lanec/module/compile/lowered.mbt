///|
fn lower_checked_modules(
  modules : Array[CheckedModule],
  observe : (String, ModuleCompileStage) -> Unit,
) -> Result[Array[CompiledModule], CompilerDiagnostic] {
  let lowered_modules : Array[CompiledModule] = []
  for module_ in modules {
    let environments = @module_interface.ModuleImportEnvironments::from_pool(
      module_.imported_interface_fingerprints.map(fn(imported) {
        imported.module_path_text
      }),
      checked_module_interfaces(modules),
    )
    let lowered = match
      @buslane_lowering.lower_checked_source_file_to_buslane_object_with_imports(
        module_.checked,
        environments,
      ) {
      Ok(lowered) => lowered
      Err(error) =>
        return Err(buslane_lowering_diagnostic(module_.module_path_text, error))
    }
    let imports = module_imported_references_from_lowered(
      lowered.imports,
      modules,
      module_.module_path_text,
    )
    let compiled = compiled_module_from_lowered(module_, lowered, imports)
    observe(
      compiled.object.module_path_text,
      BuslaneModule(compiled.object.program),
    )
    lowered_modules.push(compiled)
  }
  Ok(lowered_modules)
}

///|
fn compiled_module_from_lowered(
  module_ : CheckedModule,
  lowered : @buslane_lowering.BuslaneModuleObject,
  imports : Array[@artifact.ModuleImportedReference],
) -> CompiledModule {
  let object : ModuleObject = {
    module_path_text: module_.module_path_text,
    interface_fingerprint: module_.interface_fingerprint,
    canonical_basic_abi: lowered.canonical_basic_abi,
    program: lowered.program,
    externals: lowered.externals,
    entries: lowered.entries,
    exports: lowered.exports,
    imports,
    fingerprint: module_.fingerprint,
    object_fingerprint: @artifact.module_object_fingerprint(
      module_.fingerprint,
      module_.interface_fingerprint,
      lowered.canonical_basic_abi,
      lowered.program.metadata,
      lowered.program.terms,
      lowered.externals,
      lowered.entries,
      lowered.exports,
      imports,
      module_.imported_interface_fingerprints,
    ),
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
  { checked: module_.checked, interface: module_.interface, object, }
}

///|
fn compiled_module_from_lowered_interfaces(
  module_ : CheckedModule,
  lowered : @buslane_lowering.BuslaneModuleObject,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> CompiledModule {
  let imports = module_imported_references_from_interface_artifacts(
    lowered.imports,
    interfaces,
    module_.module_path_text,
  )
  compiled_module_from_lowered(module_, lowered, imports)
}

///|
fn module_imported_references_from_lowered(
  imports : Array[@buslane_lowering.BuslaneModuleImport],
  imported_modules : Array[CheckedModule],
  module_path_text : String,
) -> Array[@artifact.ModuleImportedReference] {
  imports.map(fn(item) {
    let fingerprint = match
      find_checked_module(imported_modules, item.module_path_text) {
      Some(module_) => module_.fingerprint
      None =>
        abort(
          "missing imported module fingerprint \{module_path_text} -> \{item.module_path_text}",
        )
    }
    {
      module_path_text: item.module_path_text,
      name: item.name,
      fingerprint,
      reference: item.reference,
    }
  })
}

///|
fn module_imported_references_from_interface_artifacts(
  imports : Array[@buslane_lowering.BuslaneModuleImport],
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
  module_path_text : String,
) -> Array[@artifact.ModuleImportedReference] {
  imports.map(fn(item) {
    let fingerprint = match
      find_module_interface_artifact(interfaces, item.module_path_text) {
      Some(interface) => interface.module_fingerprint
      None =>
        abort(
          "missing imported module fingerprint \{module_path_text} -> \{item.module_path_text}",
        )
    }
    {
      module_path_text: item.module_path_text,
      name: item.name,
      fingerprint,
      reference: item.reference,
    }
  })
}

///|
pub fn find_compiled_module(
  modules : Array[CompiledModule],
  path : String,
) -> CompiledModule? {
  for module_ in modules {
    if module_.object.module_path_text == path {
      return Some(module_)
    }
  }
  None
}
