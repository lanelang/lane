///|
/// Persisted public interface plus the fingerprints needed to validate its own
/// contents and the interfaces it was compiled against. Values decoded from
/// storage remain untrusted until interface validation succeeds.
pub(all) struct ModuleInterfaceArtifact {
  schema_version : Int
  module_path_text : String
  interface : @module_interface.ModuleInterface
  interface_fingerprint : @artifact_model.CompilationFingerprint
  module_fingerprint : @artifact_model.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_model.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
pub let module_interface_artifact_schema_version = 15

///|
pub let module_object_artifact_schema_version = 28

///|
pub let compiled_module_artifact_schema_version = 2

///|
pub let compiled_module_set_artifact_schema_version = 3

///|
/// Persisted, independently linkable module implementation. Its schema and
/// object fingerprint must be validated before its metadata is trusted.
pub(all) struct ModuleObjectArtifact {
  schema_version : Int
  module_path_text : String
  interface_fingerprint : @artifact_model.CompilationFingerprint
  canonical_basic_abi : @canonical_basic_abi.CanonicalBasicAbiRuntimeContract
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact_model.ModuleImportedReference]
  module_fingerprint : @artifact_model.CompilationFingerprint
  object_fingerprint : @artifact_model.CompilationFingerprint
  imported_interface_fingerprints : Array[
    @artifact_model.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
/// Reports which compiler-owned phase prevented a Wasm executable from being
/// produced. The Wasm compiler consumes only verifier-accepted physical input.
pub(all) enum WasmExecutableError {
  Lowering(@physical_lowering.PhysicalLoweringError)
  WasmCompilation(@wasm_compiler.WasmCompileError)
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
} derive(Debug, Eq)

///|
/// Validates every untrusted object and then links all modules. Any validation
/// or link diagnostic produces no program; input order does not determine the
/// semantic link order.
pub fn link_module_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> @module_link.LinkResult {
  match link_modules_from_object_artifacts(objects) {
    Err(diagnostics) => { program: None, diagnostics, }
    Ok(modules) => @module_link.link_modules(modules)
  }
}

///|
/// Validates a compiled module-set artifact and links only the closure reachable
/// from its recorded root. A failure returns diagnostics and no partial program.
pub fn link_module_artifacts(
  artifact : CompiledModuleSetArtifact,
) -> @module_link.LinkResult {
  match artifact.validate_schema() {
    Some(diagnostic) => { program: None, diagnostics: [diagnostic], }
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
    if object.validate() is Some(diagnostic) {
      diagnostics.push(diagnostic)
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
      self.canonical_basic_abi,
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
  if self.schema_version != compiled_module_set_artifact_schema_version {
    return Some(
      artifact_diagnostic(UnsupportedModuleArtifactSchema(None), None),
    )
  }
  for module_ in self.modules {
    let module_path_text = module_.interface.module_path_text
    if module_.schema_version != compiled_module_artifact_schema_version {
      return Some(
        artifact_diagnostic(
          UnsupportedModuleArtifactSchema(Some(module_path_text)),
          None,
        ),
      )
    }
    if module_.interface.validation_diagnostic() is Some(diagnostic) {
      return Some(diagnostic)
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
    if module_.object.validate() is Some(diagnostic) {
      return Some(diagnostic)
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
    canonical_basic_abi: self.canonical_basic_abi,
    program: { metadata: self.metadata, terms: self.terms, },
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
  { ..self.object.to_link_object(), interface: Some(self.interface.interface), }
}
