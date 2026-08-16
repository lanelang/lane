///|
pub fn CompiledModuleSet::to_artifact(
  self : CompiledModuleSet,
) -> @artifact.CompiledModuleSetArtifact {
  {
    schema_version: @artifact.compiled_module_set_artifact_schema_version,
    root_module_path_text: self.root_module_path_text,
    modules: self.modules.map(CompiledModule::to_artifact),
    reachable_module_path_texts: self.reachable_module_path_texts,
  }
}

///|
pub fn CompiledModule::to_artifact(
  self : CompiledModule,
) -> @artifact.CompiledModuleArtifact {
  {
    schema_version: @artifact.compiled_module_artifact_schema_version,
    interface: self.to_interface_artifact(),
    object: self.to_object_artifact(),
  }
}

///|
pub fn CompiledModule::to_interface_artifact(
  self : CompiledModule,
) -> @artifact.ModuleInterfaceArtifact {
  let object = self.object
  let interface = self.artifact_interface()
  {
    schema_version: @artifact.module_interface_artifact_schema_version,
    module_path_text: object.module_path_text,
    interface,
    interface_fingerprint: @artifact.interface_fingerprint(interface),
    module_fingerprint: object.fingerprint,
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
}

///|
fn CompiledModule::artifact_interface(
  self : CompiledModule,
) -> @module_interface.ModuleInterface {
  { ..self.interface, source_id: None }
}

///|
pub fn CompiledModule::to_object_artifact(
  self : CompiledModule,
) -> @artifact.ModuleObjectArtifact {
  let object = self.object
  {
    schema_version: @artifact.module_object_artifact_schema_version,
    module_path_text: object.module_path_text,
    interface_fingerprint: object.interface_fingerprint,
    canonical_basic_abi: object.canonical_basic_abi,
    metadata: object.metadata,
    terms: object.terms,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    module_fingerprint: object.fingerprint,
    object_fingerprint: object.object_fingerprint,
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
}
