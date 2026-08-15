///|
/// Validates untrusted interface schemas, module identities, fingerprints, and
/// duplicate module paths. Diagnostics are returned in input order and no
/// artifact is mutated or freshened by this check.
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
  if !diagnostics.is_empty() {
    return diagnostics
  }
  for artifact in interfaces {
    diagnostics.append(validate_interface_exports(artifact, interfaces))
  }
  diagnostics
}

///|
fn validate_interface_exports(
  artifact : ModuleInterfaceArtifact,
  interfaces : Array[ModuleInterfaceArtifact],
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  let exports = artifact.interface.exports
  for index, export_ in exports {
    for other_index in (index + 1)..<exports.length() {
      let other = exports[other_index]
      if export_.export_space == other.export_space &&
        export_.exposed_name == other.exposed_name {
        diagnostics.push(
          artifact_diagnostic(
            DuplicateModuleInterfaceExport(
              module_path_text=artifact.module_path_text,
              exposed_name=export_.exposed_name,
            ),
            None,
          ),
        )
      }
    }
    if export_.export_space != export_.target.export_space {
      diagnostics.push(
        invalid_interface_export_diagnostic(
          artifact, export_, "uses a different namespace from its target",
        ),
      )
      continue
    }
    guard find_interface_artifact(interfaces, export_.target.provider_module)
      is Some(provider) else {
      diagnostics.push(
        invalid_interface_export_diagnostic(
          artifact, export_, "references a missing provider module",
        ),
      )
      continue
    }
    guard provider.interface.declaration(export_.target) is Some(declaration) else {
      diagnostics.push(
        invalid_interface_export_diagnostic(
          artifact, export_, "references a missing provider declaration",
        ),
      )
      continue
    }
    match provider.interface.declaration_fingerprint(declaration) {
      Ok(fingerprint) if fingerprint == export_.expected_target_fingerprint =>
        ()
      Ok(_) =>
        diagnostics.push(
          invalid_interface_export_diagnostic(
            artifact, export_, "has a stale provider declaration fingerprint",
          ),
        )
      Err(reason) =>
        diagnostics.push(
          invalid_interface_export_diagnostic(
            artifact,
            export_,
            "references an invalid provider declaration: \{reason}",
          ),
        )
    }
  }
  diagnostics
}

///|
fn find_interface_artifact(
  interfaces : Array[ModuleInterfaceArtifact],
  module_path : String,
) -> ModuleInterfaceArtifact? {
  for artifact in interfaces {
    if artifact.module_path_text == module_path {
      return Some(artifact)
    }
  }
  None
}

///|
fn invalid_interface_export_diagnostic(
  artifact : ModuleInterfaceArtifact,
  export_ : @module_interface.ModuleInterfaceExport,
  reason : String,
) -> CompilerDiagnostic {
  artifact_diagnostic(
    InvalidModuleInterfaceExport(
      module_path_text=artifact.module_path_text,
      exposed_name=export_.exposed_name,
      reason~,
    ),
    None,
  )
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
/// The interface fingerprint this artifact was compiled against for one module.
///
/// A consumer needs only the modules this artifact's content references, but it
/// still checks each of those against the fingerprint recorded here, so
/// narrowing which modules are required never narrows how strictly the required
/// ones are validated. Returns `None` for a module this artifact did not import
/// directly, which leaves the fingerprint check to `link`.
pub fn ModuleInterfaceArtifact::imported_interface_fingerprint(
  self : ModuleInterfaceArtifact,
  module_path_text : String,
) -> CompilationFingerprint? {
  for imported in self.imported_interface_fingerprints {
    if imported.module_path_text == module_path_text {
      return Some(imported.fingerprint)
    }
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
