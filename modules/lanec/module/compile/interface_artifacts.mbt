///|
priv struct OrderedInterfaceArtifactsResult {
  interfaces : Array[@artifact.ModuleInterfaceArtifact]
  diagnostics : Array[CompilerDiagnostic]
}

///|
fn reachable_interface_artifacts(
  header : @module_frontend.ModuleHeader,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
  source_id : String,
) -> OrderedInterfaceArtifactsResult {
  let diagnostics = @artifact.validate_module_interface_artifacts(interfaces)
  if !diagnostics.is_empty() {
    return { interfaces: [], diagnostics, }
  }
  let ordered = []
  let visiting : Array[String] = []
  let visited : Array[String] = []
  for import_ in header.imports {
    visit_interface_artifact(
      interfaces,
      import_.module_path_text,
      None,
      header.module_path_text,
      SourceInput(source_id~, span=Some(import_.import_span)),
      visiting,
      visited,
      ordered,
      diagnostics,
    )
  }
  { interfaces: ordered, diagnostics, }
}

///|
fn visit_interface_artifact(
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
  module_path_text : String,
  expected_fingerprint : @artifact.CompilationFingerprint?,
  importer_path_text : String,
  provenance : @module_frontend.ModuleDependencyProvenance,
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
      @module_frontend.ModuleDependencyFailure::import_cycle(
        module_path_text, provenance,
      ).diagnostic(),
    )
    return
  }
  guard find_module_interface_artifact(interfaces, module_path_text)
    is Some(interface) else {
    diagnostics.push(
      @module_frontend.ModuleDependencyFailure::missing_import(
        module_path_text,
        source_modules=[],
        interface_modules=interface_candidates(interfaces),
        provenance~,
      ).diagnostic(),
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
  // Recursion follows the **Reachable Interface Closure**, not every module the
  // importer happened to compile against. A module used only inside another
  // module's implementation never reaches a consumer's declarations, so
  // demanding its interface would push an implementation detail onto callers.
  // The wider set is still required by `link`, which validates the same
  // fingerprints over the **Implementation Closure**.
  for dependency in interface.interface.dependency_module_paths() {
    visit_interface_artifact(
      interfaces,
      dependency,
      interface.imported_interface_fingerprint(dependency),
      module_path_text,
      InterfaceArtifact(
        source_id=match provenance {
          SourceInput(source_id~, ..) | InterfaceArtifact(source_id~, ..) =>
            source_id
        },
        importer_module_path_text=module_path_text,
        span=None,
      ),
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
  { ..self, fingerprint, imported_interface_fingerprints: imported, }
}
