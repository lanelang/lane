///|
pub fn validate_module_interface_artifacts(
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for interface in interfaces {
    match interface.validation_diagnostic() {
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
fn ModuleInterfaceArtifact::validation_diagnostic(
  self : ModuleInterfaceArtifact,
) -> CompilerDiagnostic? {
  if self.schema_version != module_interface_artifact_schema_version {
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
  let actual_interface_fingerprint = match
    interface_fingerprint_result(self.interface) {
    Ok(fingerprint) => fingerprint
    Err(reason) =>
      return Some(
        artifact_diagnostic(
          InvalidModuleInterfaceArtifact(
            module_path_text=self.module_path_text,
            reason~,
          ),
          None,
        ),
      )
  }
  if self.interface_fingerprint != actual_interface_fingerprint {
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
  let fingerprint = module_fingerprint_from_interface_fingerprint(
    actual_interface_fingerprint,
    self.imported_interface_fingerprints,
  )
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
pub fn ModuleInterfaceArtifact::imported_fingerprint_diagnostic(
  self : ModuleInterfaceArtifact,
  importer : String,
  expected : CompilationFingerprint,
) -> CompilerDiagnostic? {
  if expected == interface_fingerprint(self.interface) {
    None
  } else {
    Some(
      artifact_diagnostic(
        ArtifactImportedInterfaceFingerprintMismatch(
          importer~,
          imported=self.module_path_text,
        ),
        None,
      ),
    )
  }
}
