///|
priv struct OrderedInterfaceArtifactsResult {
  interfaces : Array[ModuleInterfaceArtifact]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn reachable_interface_artifacts(
  header : @module_frontend.ModuleHeader,
  interfaces : Array[ModuleInterfaceArtifact],
) -> OrderedInterfaceArtifactsResult {
  let diagnostics = validate_interface_artifacts(interfaces)
  if !diagnostics.is_empty() {
    return { interfaces: [], diagnostics }
  }
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  for import_ in header.imports {
    visit_interface_artifact(
      interfaces,
      import_.module_path_text,
      Some(import_.import_span),
      None,
      header.module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  { interfaces: ordered, diagnostics }
}

///|
fn validate_interface_artifacts(
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for interface in interfaces {
    match interface.validate() {
      Some(diagnostic) => diagnostics.push(diagnostic)
      None => ()
    }
  }
  for index in 0..<interfaces.length() {
    for other_index in (index + 1)..<interfaces.length() {
      if interfaces[index].module_path_text ==
        interfaces[other_index].module_path_text {
        diagnostics.push(
          artifact_diagnostic(
            DuplicateModuleInterfaceArtifact(interfaces[index].module_path_text),
            None,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn ModuleInterfaceArtifact::validate(
  self : ModuleInterfaceArtifact,
) -> CompilerDiagnostic? {
  if self.schema_version != 1 {
    return Some(
      artifact_diagnostic(
        UnsupportedModuleInterfaceArtifactSchema(self.module_path_text),
        None,
      ),
    )
  }
  if self.interface.module_path != self.module_path_text {
    return Some(
      artifact_diagnostic(
        InvalidModuleInterfaceArtifact(
          module_path_text=self.module_path_text,
          reason="name mismatch",
        ),
        None,
      ),
    )
  }
  let fingerprint = module_fingerprint(
    self.interface,
    self.imported_interface_fingerprints,
  )
  if self.interface_fingerprint != interface_fingerprint(self.interface) {
    return Some(
      artifact_diagnostic(
        InvalidModuleInterfaceArtifact(
          module_path_text=self.module_path_text,
          reason="fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  if self.module_fingerprint != fingerprint {
    return Some(
      artifact_diagnostic(
        InvalidModuleInterfaceArtifact(
          module_path_text=self.module_path_text,
          reason="module fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  None
}

///|
fn visit_interface_artifact(
  interfaces : Array[ModuleInterfaceArtifact],
  module_path_text : String,
  span : @basic.SourceSpan?,
  expected_fingerprint : @artifact_core.CompilationFingerprint?,
  importer_path_text : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[ModuleInterfaceArtifact],
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  if visited.contains(module_path_text) {
    return
  }
  if visiting.contains(module_path_text) {
    diagnostics.push(
      compile_boundary_diagnostic(ImportCycle(module_path_text), None),
    )
    return
  }
  guard find_module_interface_artifact(interfaces, module_path_text)
    is Some(interface) else {
    diagnostics.push(
      compile_boundary_diagnostic(
        MissingImportWithCandidates(
          module_=module_path_text,
          source_modules=[],
          interface_modules=interface_candidates(interfaces),
        ),
        span,
      ),
    )
    return
  }
  match expected_fingerprint {
    Some(fingerprint) if interface_fingerprint(interface.interface) !=
      fingerprint =>
      diagnostics.push(
        artifact_diagnostic(
          ArtifactImportedInterfaceFingerprintMismatch(
            importer=importer_path_text,
            imported=module_path_text,
          ),
          None,
        ),
      )
    _ => ()
  }
  visiting.push(module_path_text)
  for imported in interface.imported_interface_fingerprints {
    visit_interface_artifact(
      interfaces,
      imported.module_path_text,
      None,
      Some(imported.fingerprint),
      module_path_text,
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  ignore(visiting.pop())
  visited.push(module_path_text)
  ordered.push(interface)
}

///|
fn find_module_interface_artifact(
  interfaces : Array[ModuleInterfaceArtifact],
  module_path_text : String,
) -> ModuleInterfaceArtifact? {
  for interface in interfaces {
    if interface.module_path_text == module_path_text {
      return Some(interface)
    }
  }
  None
}

///|
fn interface_candidates(
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[String] {
  interfaces.map(fn(interface) { interface.module_path_text })
}

///|
fn imported_interface_fingerprints_from_artifacts(
  header : @module_frontend.ModuleHeader,
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[@artifact_core.ImportedInterfaceFingerprint] {
  let fingerprints = []
  for import_ in header.imports {
    if find_module_interface_artifact(interfaces, import_.module_path_text)
      is Some(interface) {
      fingerprints.push(@artifact_core.ImportedInterfaceFingerprint::{
        module_path_text: interface.module_path_text,
        fingerprint: interface_fingerprint(interface.interface),
      })
    }
  }
  fingerprints
}

///|
fn CompiledModule::with_imported_interface_fingerprints(
  self : CompiledModule,
  imported : Array[@artifact_core.ImportedInterfaceFingerprint],
) -> CompiledModule {
  let fingerprint = module_fingerprint(self.interface, imported)
  let object : ModuleObject = {
    module_path_text: self.object.module_path_text,
    checked: self.object.checked,
    interface_fingerprint: self.object.interface_fingerprint,
    metadata: self.object.metadata,
    terms: self.object.terms,
    externals: self.object.externals,
    entries: self.object.entries,
    exports: self.object.exports,
    imports: self.object.imports,
    fingerprint,
    object_fingerprint: module_object_fingerprint(
      fingerprint,
      self.object.interface_fingerprint,
      self.object.metadata,
      self.object.terms,
      self.object.externals,
      self.object.entries,
      self.object.exports,
      self.object.imports,
      imported,
    ),
    imported_interface_fingerprints: imported,
  }
  {
    module_path_text: self.module_path_text,
    interface: self.interface,
    object,
    fingerprint,
    imported_interface_fingerprints: imported,
  }
}
