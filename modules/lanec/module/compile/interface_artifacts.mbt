///|
priv struct OrderedInterfaceArtifactsResult {
  interfaces : Array[@artifact.ModuleInterfaceArtifact]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn reachable_interface_artifacts(
  header : @module_frontend.ModuleHeader,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> OrderedInterfaceArtifactsResult {
  let diagnostics = @artifact.validate_module_interface_artifacts(interfaces)
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
fn visit_interface_artifact(
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
  module_path_text : String,
  span : @basic.SourceSpan?,
  expected_fingerprint : @artifact.CompilationFingerprint?,
  importer_path_text : String,
  visiting : Array[String],
  visited : Array[String],
  ordered : Array[@artifact.ModuleInterfaceArtifact],
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
    Some(fingerprint) =>
      if interface.imported_fingerprint_diagnostic(
          importer_path_text, fingerprint,
        )
        is Some(diagnostic) {
        diagnostics.push(diagnostic)
      }
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
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
  module_path_text : String,
) -> @artifact.ModuleInterfaceArtifact? {
  for interface in interfaces {
    if interface.module_path_text == module_path_text {
      return Some(interface)
    }
  }
  None
}

///|
fn interface_candidates(
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> Array[String] {
  interfaces.map(fn(interface) { interface.module_path_text })
}

///|
fn imported_interface_fingerprints_from_artifacts(
  header : @module_frontend.ModuleHeader,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> Array[@artifact.ImportedInterfaceFingerprint] {
  let fingerprints = []
  for import_ in header.imports {
    if find_module_interface_artifact(interfaces, import_.module_path_text)
      is Some(interface) {
      fingerprints.push(@artifact.ImportedInterfaceFingerprint::{
        module_path_text: interface.module_path_text,
        fingerprint: @artifact.interface_fingerprint(interface.interface),
      })
    }
  }
  fingerprints
}

///|
fn CheckedModule::with_imported_interface_fingerprints(
  self : CheckedModule,
  imported : Array[@artifact.ImportedInterfaceFingerprint],
) -> CheckedModule {
  let fingerprint = @artifact.module_fingerprint(self.interface, imported)
  { ..self, fingerprint, imported_interface_fingerprints: imported }
}
