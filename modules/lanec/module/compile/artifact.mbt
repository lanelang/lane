///|
pub(all) struct ModuleInterfaceArtifact {
  schema_version : Int
  module_path_text : String
  interface : @module_interface.ModuleInterface
  interface_fingerprint : @artifact_core.CompilationFingerprint
  module_fingerprint : @artifact_core.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
pub let module_interface_artifact_schema_version = 3

///|
pub let module_object_artifact_schema_version = 10

///|
pub let linked_program_artifact_schema_version = 5

///|
pub(all) struct ModuleObjectArtifact {
  schema_version : Int
  module_path_text : String
  interface_fingerprint : @artifact_core.CompilationFingerprint
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact_core.ModuleImportedReference]
  module_fingerprint : @artifact_core.CompilationFingerprint
  object_fingerprint : @artifact_core.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
pub(all) struct LinkedProgramArtifact {
  schema_version : Int
  bytecode : @loisvm_bytecode.BytecodeImage
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleArtifact {
  schema_version : Int
  interface : ModuleInterfaceArtifact
  object : ModuleObjectArtifact
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleSetArtifact {
  schema_version : Int
  root_module_path_text : String
  modules : Array[CompiledModuleArtifact]
  reachable_module_path_texts : Array[String]
} derive(Debug, Eq)

///|
pub fn CompiledModuleSet::to_artifact(
  self : CompiledModuleSet,
) -> CompiledModuleSetArtifact {
  {
    schema_version: 2,
    root_module_path_text: self.root_module_path_text,
    modules: self.modules.map(CompiledModule::to_artifact),
    reachable_module_path_texts: self.reachable_module_path_texts,
  }
}

///|
pub fn CompiledModule::to_artifact(
  self : CompiledModule,
) -> CompiledModuleArtifact {
  {
    schema_version: 2,
    interface: self.to_interface_artifact(),
    object: self.to_object_artifact(),
  }
}

///|
pub fn CompiledModule::to_interface_artifact(
  self : CompiledModule,
) -> ModuleInterfaceArtifact {
  let object = self.object
  let interface = self.artifact_interface()
  {
    schema_version: module_interface_artifact_schema_version,
    module_path_text: object.module_path_text,
    interface,
    interface_fingerprint: interface_fingerprint(interface),
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
) -> ModuleObjectArtifact {
  let object = self.object
  {
    schema_version: module_object_artifact_schema_version,
    module_path_text: object.module_path_text,
    interface_fingerprint: object.interface_fingerprint,
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

///|
pub fn link_module_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> @module_link.LinkResult {
  match link_modules_from_object_artifacts(objects) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(modules) => @module_link.link_modules(modules)
  }
}

///|
pub fn link_module_artifacts(
  artifact : CompiledModuleSetArtifact,
) -> @module_link.LinkResult {
  match artifact.validate_schema() {
    Some(diagnostic) => { program: None, diagnostics: [diagnostic] }
    None =>
      @module_link.link_reachable_modules(
        artifact.modules.map(CompiledModuleArtifact::to_link_object),
        artifact.root_module_path_text,
      )
  }
}

///|
fn link_modules_from_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> Result[Array[@module_link.LinkModuleObject], Array[CompilerDiagnostic]] {
  let diagnostics = ModuleObjectArtifact::validate_all(objects)
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  Ok(objects.map(ModuleObjectArtifact::to_link_object))
}

///|
fn ModuleObjectArtifact::validate_all(
  objects : Array[ModuleObjectArtifact],
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for object in objects {
    match object.validate() {
      Some(diagnostic) => diagnostics.push(diagnostic)
      None => ()
    }
  }
  for index in 0..<objects.length() {
    for other_index in (index + 1)..<objects.length() {
      if objects[index].module_path_text ==
        objects[other_index].module_path_text {
        diagnostics.push(
          artifact_diagnostic(
            DuplicateModuleObjectArtifact(objects[index].module_path_text),
            None,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn ModuleObjectArtifact::validate(
  self : ModuleObjectArtifact,
) -> CompilerDiagnostic? {
  if self.schema_version != module_object_artifact_schema_version {
    return Some(
      artifact_diagnostic(
        UnsupportedModuleObjectArtifactSchema(
          schema=self.schema_version,
          module_path_text=self.module_path_text,
        ),
        None,
      ),
    )
  }
  if self.object_fingerprint !=
    module_object_fingerprint(
      self.module_fingerprint,
      self.interface_fingerprint,
      self.metadata,
      self.terms,
      self.externals,
      self.entries,
      self.exports,
      self.imports,
      self.imported_interface_fingerprints,
    ) {
    return Some(
      artifact_diagnostic(
        InvalidModuleObjectArtifact(
          module_path_text=self.module_path_text,
          reason="object fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  None
}

///|
fn CompiledModuleSetArtifact::validate_schema(
  self : CompiledModuleSetArtifact,
) -> CompilerDiagnostic? {
  if self.schema_version != 2 {
    return Some(
      artifact_diagnostic(UnsupportedModuleArtifactSchema(None), None),
    )
  }
  for module_ in self.modules {
    let module_path_text = module_.interface.module_path_text
    if module_.schema_version != 2 {
      return Some(
        artifact_diagnostic(
          UnsupportedModuleArtifactSchema(Some(module_path_text)),
          None,
        ),
      )
    }
    match module_.interface.validate() {
      Some(diagnostic) => return Some(diagnostic)
      None => ()
    }
    if module_.object.module_path_text != module_path_text {
      return Some(
        artifact_diagnostic(
          InvalidModuleArtifact(module_path_text~, reason="name mismatch"),
          None,
        ),
      )
    }
    if module_.object.imported_interface_fingerprints !=
      module_.interface.imported_interface_fingerprints {
      return Some(
        artifact_diagnostic(
          InvalidModuleArtifact(
            module_path_text~,
            reason="imported interface mismatch",
          ),
          None,
        ),
      )
    }
    if module_.object.module_fingerprint != module_.interface.module_fingerprint {
      return Some(
        artifact_diagnostic(
          InvalidModuleArtifact(
            module_path_text~,
            reason="fingerprint mismatch",
          ),
          None,
        ),
      )
    }
    if module_.interface.interface_fingerprint !=
      module_.object.interface_fingerprint {
      return Some(
        artifact_diagnostic(
          InvalidModuleArtifact(
            module_path_text~,
            reason="interface fingerprint mismatch",
          ),
          None,
        ),
      )
    }
    match module_.object.validate() {
      Some(diagnostic) => return Some(diagnostic)
      None => ()
    }
  }
  None
}

///|
fn ModuleObjectArtifact::to_link_object(
  self : ModuleObjectArtifact,
) -> @module_link.LinkModuleObject {
  {
    module_path_text: self.module_path_text,
    interface: None,
    interface_fingerprint: self.interface_fingerprint,
    metadata: self.metadata,
    terms: self.terms,
    externals: self.externals,
    entries: self.entries,
    exports: self.exports,
    imports: self.imports,
    fingerprint: self.module_fingerprint,
    object_fingerprint_valid: true,
    imported_interface_fingerprints: self.imported_interface_fingerprints,
  }
}

///|
fn CompiledModuleArtifact::to_link_object(
  self : CompiledModuleArtifact,
) -> @module_link.LinkModuleObject {
  { ..self.object.to_link_object(), interface: Some(self.interface.interface) }
}
