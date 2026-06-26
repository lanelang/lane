///|
pub(all) struct ModuleInterfaceArtifact {
  schema_version : Int
  module_path_text : String
  interface : @module_interface.ModuleInterface
  interface_fingerprint : CompilationFingerprint
  module_fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct ModuleObjectArtifact {
  schema_version : Int
  module_path_text : String
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  exports : Array[@elaborate.BuslaneModuleExport]
  imports : Array[ModuleImportedReference]
  module_fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleArtifact {
  schema_version : Int
  module_path_text : String
  interface : ModuleInterfaceArtifact
  object : ModuleObjectArtifact
  module_fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleSetArtifact {
  schema_version : Int
  root_module_path_text : String
  modules : Array[CompiledModuleArtifact]
  reachable_module_path_texts : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct ModuleArtifactManifestEntry {
  module_path_text : String
  interface_file : String
  object_file : String
  module_fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct CompiledModuleSetManifestArtifact {
  schema_version : Int
  root_module_path_text : String
  modules : Array[ModuleArtifactManifestEntry]
  reachable_module_path_texts : Array[String]
} derive(Debug, Eq)

///|
pub fn compiled_module_set_artifact(
  modules : CompiledModuleSet,
) -> CompiledModuleSetArtifact {
  {
    schema_version: 1,
    root_module_path_text: modules.root_module_path_text,
    modules: modules.modules.map(compiled_module_artifact),
    reachable_module_path_texts: modules.reachable_module_path_texts,
  }
}

///|
pub fn compiled_module_set_manifest_artifact(
  modules : CompiledModuleSet,
) -> CompiledModuleSetManifestArtifact {
  {
    schema_version: 1,
    root_module_path_text: modules.root_module_path_text,
    modules: modules.modules.map(fn(module_) {
      {
        module_path_text: module_.module_path_text,
        interface_file: module_.module_path_text + ".lmi",
        object_file: module_.module_path_text + ".lmo",
        module_fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    }),
    reachable_module_path_texts: modules.reachable_module_path_texts,
  }
}

///|
pub fn compiled_module_artifact(
  module_ : CompiledModule,
) -> CompiledModuleArtifact {
  {
    schema_version: 1,
    module_path_text: module_.module_path_text,
    interface: module_interface_artifact(module_),
    object: module_object_artifact(module_.object),
    module_fingerprint: module_.fingerprint,
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
}

///|
pub fn module_interface_artifact(
  module_ : CompiledModule,
) -> ModuleInterfaceArtifact {
  {
    schema_version: 1,
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    interface_fingerprint: interface_fingerprint(module_.interface),
    module_fingerprint: module_.fingerprint,
    imported_interface_fingerprints: module_.imported_interface_fingerprints,
  }
}

///|
pub fn module_object_artifact(object : ModuleObject) -> ModuleObjectArtifact {
  {
    schema_version: 1,
    module_path_text: object.module_path_text,
    metadata: object.metadata,
    terms: object.terms,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    module_fingerprint: object.fingerprint,
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
}

///|
pub fn link_module_artifacts(
  artifact : CompiledModuleSetArtifact,
) -> LinkResult {
  match validate_artifact_schema(artifact) {
    Some(diagnostic) => { program: None, diagnostics: [diagnostic] }
    None =>
      link_compiled_module_set(compiled_module_set_from_artifact(artifact))
  }
}

///|
pub fn link_module_artifact_parts(
  manifest : CompiledModuleSetManifestArtifact,
  interfaces : Array[ModuleInterfaceArtifact],
  objects : Array[ModuleObjectArtifact],
) -> LinkResult {
  match compiled_module_set_artifact_from_parts(manifest, interfaces, objects) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(artifact) => link_module_artifacts(artifact)
  }
}

///|
fn compiled_module_set_artifact_from_parts(
  manifest : CompiledModuleSetManifestArtifact,
  interfaces : Array[ModuleInterfaceArtifact],
  objects : Array[ModuleObjectArtifact],
) -> Result[CompiledModuleSetArtifact, Array[CompileDiagnostic]] {
  if manifest.schema_version != 1 {
    return Err([
      make_error("unsupported module artifact manifest schema", span=None),
    ])
  }
  let modules = []
  for entry in manifest.modules {
    guard find_interface_artifact(interfaces, entry.module_path_text)
      is Some(interface) else {
      return Err([
        make_error(
          "missing module interface artifact " + entry.module_path_text,
          span=None,
        ),
      ])
    }
    guard find_object_artifact(objects, entry.module_path_text) is Some(object) else {
      return Err([
        make_error(
          "missing module object artifact " + entry.module_path_text,
          span=None,
        ),
      ])
    }
    modules.push({
      schema_version: 1,
      module_path_text: entry.module_path_text,
      interface,
      object,
      module_fingerprint: entry.module_fingerprint,
      imported_interface_fingerprints: entry.imported_interface_fingerprints,
    })
  }
  Ok({
    schema_version: 1,
    root_module_path_text: manifest.root_module_path_text,
    modules,
    reachable_module_path_texts: manifest.reachable_module_path_texts,
  })
}

///|
fn find_interface_artifact(
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
fn find_object_artifact(
  objects : Array[ModuleObjectArtifact],
  module_path_text : String,
) -> ModuleObjectArtifact? {
  for object in objects {
    if object.module_path_text == module_path_text {
      return Some(object)
    }
  }
  None
}

///|
fn validate_artifact_schema(
  artifact : CompiledModuleSetArtifact,
) -> CompileDiagnostic? {
  if artifact.schema_version != 1 {
    return Some(make_error("unsupported module artifact schema", span=None))
  }
  for module_ in artifact.modules {
    if module_.schema_version != 1 {
      return Some(
        make_error(
          "unsupported module artifact schema " + module_.module_path_text,
          span=None,
        ),
      )
    }
    if module_.interface.schema_version != 1 {
      return Some(
        make_error(
          "unsupported module interface artifact schema " +
          module_.module_path_text,
          span=None,
        ),
      )
    }
    match validate_module_interface_artifact(module_.interface) {
      Some(diagnostic) => return Some(diagnostic)
      None => ()
    }
    if module_.object.schema_version != 1 {
      return Some(
        make_error(
          "unsupported module object artifact schema " +
          module_.module_path_text,
          span=None,
        ),
      )
    }
    if module_.interface.module_path_text != module_.module_path_text ||
      module_.object.module_path_text != module_.module_path_text {
      return Some(
        make_error(
          "module artifact name mismatch " + module_.module_path_text,
          span=None,
        ),
      )
    }
    if module_.interface.imported_interface_fingerprints !=
      module_.imported_interface_fingerprints ||
      module_.object.imported_interface_fingerprints !=
      module_.imported_interface_fingerprints {
      return Some(
        make_error(
          "module artifact imported interface mismatch " +
          module_.module_path_text,
          span=None,
        ),
      )
    }
    if module_.interface.module_fingerprint != module_.module_fingerprint ||
      module_.object.module_fingerprint != module_.module_fingerprint {
      return Some(
        make_error(
          "module artifact fingerprint mismatch " + module_.module_path_text,
          span=None,
        ),
      )
    }
    if module_.interface.interface_fingerprint !=
      interface_fingerprint(module_.interface.interface) {
      return Some(
        make_error(
          "module interface artifact fingerprint mismatch " +
          module_.module_path_text,
          span=None,
        ),
      )
    }
    if module_.module_fingerprint !=
      module_fingerprint(
        module_.interface.interface,
        module_.imported_interface_fingerprints,
      ) {
      return Some(
        make_error(
          "module artifact fingerprint mismatch " + module_.module_path_text,
          span=None,
        ),
      )
    }
  }
  None
}

///|
fn compiled_module_set_from_artifact(
  artifact : CompiledModuleSetArtifact,
) -> CompiledModuleSet {
  {
    root_module_path_text: artifact.root_module_path_text,
    modules: artifact.modules.map(compiled_module_from_artifact),
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  }
}

///|
fn compiled_module_from_artifact(
  artifact : CompiledModuleArtifact,
) -> CompiledModule {
  {
    module_path_text: artifact.module_path_text,
    interface: artifact.interface.interface,
    object: module_object_from_artifact(artifact.object),
    fingerprint: artifact.module_fingerprint,
    imported_interface_fingerprints: artifact.imported_interface_fingerprints,
  }
}

///|
fn module_object_from_artifact(artifact : ModuleObjectArtifact) -> ModuleObject {
  {
    module_path_text: artifact.module_path_text,
    checked: empty_checked_source_file(artifact.module_path_text),
    metadata: artifact.metadata,
    terms: artifact.terms,
    externals: artifact.externals,
    entries: artifact.entries,
    exports: artifact.exports,
    imports: artifact.imports,
    fingerprint: artifact.module_fingerprint,
    imported_interface_fingerprints: artifact.imported_interface_fingerprints,
  }
}

///|
fn empty_checked_source_file(
  module_path_text : String,
) -> @checked.CheckedSourceFile {
  let loc = @basic.SourceSpan::dummy()
  {
    module_path: {
      components: module_path_text
      .split(".")
      .map(StringView::to_owned)
      .collect(),
      loc,
    },
    declarations: [],
    loc,
  }
}
