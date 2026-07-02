///|
fn lower_compiled_module_objects(
  modules : Array[CompiledModule],
) -> Array[CompiledModule] {
  let lowered_modules : Array[CompiledModule] = []
  for module_ in modules {
    let imported = imported_interfaces_from_modules(
      module_.imported_interface_fingerprints,
      lowered_modules,
    )
    let lowered = @elaborate.lower_checked_source_file_to_buslane_object_with_imports(
      module_.object.checked,
      imported,
    )
    lowered_modules.push(
      attach_lowered_object(module_, lowered, lowered_modules),
    )
  }
  lowered_modules
}

///|
fn imported_interfaces_from_modules(
  imported : Array[ImportedInterfaceFingerprint],
  modules : Array[CompiledModule],
) -> @module_interface.ImportedEnvironment {
  let interfaces = []
  for item in imported {
    if find_compiled_module(modules, item.module_path_text) is Some(module_) {
      interfaces.push(module_.interface)
    }
  }
  { modules: interfaces }
}

///|
fn attach_lowered_object(
  module_ : CompiledModule,
  lowered : @elaborate.BuslaneModuleObject,
  imported_modules : Array[CompiledModule],
) -> CompiledModule {
  let object : ModuleObject = {
    module_path_text: module_.object.module_path_text,
    checked: module_.object.checked,
    metadata: lowered.metadata,
    terms: lowered.terms,
    externals: lowered.externals,
    entries: lowered.entries,
    exports: lowered.exports,
    imports: module_imported_references_from_lowered(
      lowered.imports,
      imported_modules,
      module_.module_path_text,
    ),
    fingerprint: module_.object.fingerprint,
    imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
  }
  {
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    object,
    fingerprint: module_.fingerprint,
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
}

///|
fn attach_lowered_object_from_interfaces(
  module_ : CompiledModule,
  lowered : @elaborate.BuslaneModuleObject,
  interfaces : Array[ModuleInterfaceArtifact],
) -> CompiledModule {
  let object : ModuleObject = {
    module_path_text: module_.object.module_path_text,
    checked: module_.object.checked,
    metadata: lowered.metadata,
    terms: lowered.terms,
    externals: lowered.externals,
    entries: lowered.entries,
    exports: lowered.exports,
    imports: module_imported_references_from_interface_artifacts(
      lowered.imports,
      interfaces,
      module_.module_path_text,
    ),
    fingerprint: module_.object.fingerprint,
    imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
  }
  {
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    object,
    fingerprint: module_.fingerprint,
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
}

///|
fn module_imported_references_from_lowered(
  imports : Array[@elaborate.BuslaneModuleImport],
  imported_modules : Array[CompiledModule],
  module_path_text : String,
) -> Array[ModuleImportedReference] {
  imports.map(fn(item) {
    let fingerprint = match
      find_compiled_module(imported_modules, item.module_path_text) {
      Some(module_) => module_.fingerprint
      None =>
        abort(
          "missing imported module fingerprint \{module_path_text} -> \{item.module_path_text}",
        )
    }
    {
      module_path_text: item.module_path_text,
      kind: item.kind,
      name: item.name,
      fingerprint,
      type_id: item.type_id,
      data_constructor: item.data_constructor,
      effect_id: item.effect_id,
      operation: item.operation,
      value: item.value,
    }
  })
}

///|
fn module_imported_references_from_interface_artifacts(
  imports : Array[@elaborate.BuslaneModuleImport],
  interfaces : Array[ModuleInterfaceArtifact],
  module_path_text : String,
) -> Array[ModuleImportedReference] {
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
      kind: item.kind,
      name: item.name,
      fingerprint,
      type_id: item.type_id,
      data_constructor: item.data_constructor,
      effect_id: item.effect_id,
      operation: item.operation,
      value: item.value,
    }
  })
}

///|
fn find_module_export(
  exports : Array[@elaborate.BuslaneModuleExport],
  kind : @elaborate.BuslaneModuleExportKind,
  name : String,
) -> @elaborate.BuslaneModuleExport? {
  for item in exports {
    if item.kind == kind && item.name == name {
      return Some(item)
    }
  }
  None
}

///|
fn find_compiled_module(
  modules : Array[CompiledModule],
  path : String,
) -> CompiledModule? {
  for module_ in modules {
    if module_.module_path_text == path {
      return Some(module_)
    }
  }
  None
}
