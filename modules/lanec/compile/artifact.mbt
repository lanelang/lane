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
let module_object_artifact_schema_version = 2

///|
pub(all) struct ModuleObjectArtifact {
  schema_version : Int
  module_path_text : String
  interface : @module_interface.ModuleInterface
  interface_fingerprint : CompilationFingerprint
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
pub(all) struct LinkedProgramArtifact {
  schema_version : Int
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
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
pub fn compiled_module_artifact(
  module_ : CompiledModule,
) -> CompiledModuleArtifact {
  {
    schema_version: 1,
    module_path_text: module_.module_path_text,
    interface: module_interface_artifact(module_),
    object: module_object_artifact(module_),
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
pub fn module_object_artifact(module_ : CompiledModule) -> ModuleObjectArtifact {
  let object = module_.object
  {
    schema_version: module_object_artifact_schema_version,
    module_path_text: object.module_path_text,
    interface: module_.interface,
    interface_fingerprint: interface_fingerprint(module_.interface),
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
pub fn linked_program_artifact(
  program : LinkedProgram,
) -> LinkedProgramArtifact {
  {
    schema_version: 1,
    module_path_texts: program.module_path_texts,
    program: program.program,
    externals: program.externals,
    entries: program.entries,
  }
}

///|
pub fn linked_program_from_artifact(
  artifact : LinkedProgramArtifact,
) -> Result[LinkedProgram, Array[CompileDiagnostic]] {
  let diagnostics = validate_linked_program_artifact(artifact)
  if !diagnostics.is_empty() {
    Err(diagnostics)
  } else {
    Ok({
      module_path_texts: artifact.module_path_texts,
      program: artifact.program,
      externals: artifact.externals,
      entries: artifact.entries,
    })
  }
}

///|
pub fn link_module_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> LinkResult {
  match compiled_modules_from_object_artifacts(objects) {
    Err(diagnostics) => { program: None, diagnostics }
    Ok(modules) => link_compiled_modules(modules)
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
fn compiled_modules_from_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> Result[Array[CompiledModule], Array[CompileDiagnostic]] {
  let diagnostics = validate_object_artifacts(objects)
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  Ok(objects.map(compiled_module_from_object_artifact))
}

///|
fn validate_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for object in objects {
    match validate_module_object_artifact(object) {
      Some(diagnostic) => diagnostics.push(diagnostic)
      None => ()
    }
  }
  for index in 0..<objects.length() {
    for other_index in (index + 1)..<objects.length() {
      if objects[index].module_path_text ==
        objects[other_index].module_path_text {
        diagnostics.push(
          compile_error(
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
fn validate_module_object_artifact(
  object : ModuleObjectArtifact,
) -> CompileDiagnostic? {
  if object.schema_version != module_object_artifact_schema_version {
    return Some(
      compile_error(
        UnsupportedModuleObjectArtifactSchema(
          schema=object.schema_version,
          module_path_text=object.module_path_text,
        ),
        None,
      ),
    )
  }
  if object.interface.module_path != object.module_path_text {
    return Some(
      compile_error(
        InvalidModuleObjectArtifact(
          module_path_text=object.module_path_text,
          reason="interface name mismatch",
        ),
        None,
      ),
    )
  }
  if object.interface_fingerprint != interface_fingerprint(object.interface) {
    return Some(
      compile_error(
        InvalidModuleObjectArtifact(
          module_path_text=object.module_path_text,
          reason="interface fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  if object.module_fingerprint !=
    module_fingerprint(object.interface, object.imported_interface_fingerprints) {
    return Some(
      compile_error(
        InvalidModuleObjectArtifact(
          module_path_text=object.module_path_text,
          reason="module fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  None
}

///|
fn validate_linked_program_artifact(
  artifact : LinkedProgramArtifact,
) -> Array[CompileDiagnostic] {
  let diagnostics = []
  if artifact.schema_version != 1 {
    diagnostics.push(
      compile_error(UnsupportedLinkedProgramArtifactSchema, None),
    )
  }
  let verify_result = @buslane.verify_program(artifact.program)
  if !verify_result.is_ok() {
    diagnostics.push(compile_error(InvalidLinkedBuslaneProgram, None))
  }
  validate_linked_program_modules(artifact, diagnostics)
  validate_linked_program_entries(artifact, diagnostics)
  diagnostics
}

///|
fn validate_linked_program_modules(
  artifact : LinkedProgramArtifact,
  diagnostics : Array[CompileDiagnostic],
) -> Unit {
  for index in 0..<artifact.module_path_texts.length() {
    for other_index in (index + 1)..<artifact.module_path_texts.length() {
      if artifact.module_path_texts[index] ==
        artifact.module_path_texts[other_index] {
        diagnostics.push(
          compile_error(
            DuplicateLinkedModule(artifact.module_path_texts[index]),
            None,
          ),
        )
      }
    }
  }
}

///|
fn validate_linked_program_entries(
  artifact : LinkedProgramArtifact,
  diagnostics : Array[CompileDiagnostic],
) -> Unit {
  for index in 0..<artifact.entries.length() {
    let entry = artifact.entries[index]
    if artifact.program.metadata.value_info(entry.value) is None {
      diagnostics.push(compile_error(LinkedEntryUnknownValue(entry.name), None))
    }
    for other_index in (index + 1)..<artifact.entries.length() {
      if entry.name == artifact.entries[other_index].name {
        diagnostics.push(compile_error(DuplicateLinkedEntry(entry.name), None))
      }
    }
  }
}

///|
fn validate_artifact_schema(
  artifact : CompiledModuleSetArtifact,
) -> CompileDiagnostic? {
  if artifact.schema_version != 1 {
    return Some(compile_error(UnsupportedModuleArtifactSchema(None), None))
  }
  for module_ in artifact.modules {
    if module_.schema_version != 1 {
      return Some(
        compile_error(
          UnsupportedModuleArtifactSchema(Some(module_.module_path_text)),
          None,
        ),
      )
    }
    if module_.interface.schema_version != 1 {
      return Some(
        compile_error(
          UnsupportedModuleInterfaceArtifactSchema(module_.module_path_text),
          None,
        ),
      )
    }
    match validate_module_interface_artifact(module_.interface) {
      Some(diagnostic) => return Some(diagnostic)
      None => ()
    }
    if module_.object.schema_version != module_object_artifact_schema_version {
      return Some(
        compile_error(
          UnsupportedModuleObjectArtifactSchema(
            schema=module_.object.schema_version,
            module_path_text=module_.module_path_text,
          ),
          None,
        ),
      )
    }
    if module_.interface.module_path_text != module_.module_path_text ||
      module_.object.module_path_text != module_.module_path_text {
      return Some(
        compile_error(
          InvalidModuleArtifact(
            module_path_text=module_.module_path_text,
            reason="name mismatch",
          ),
          None,
        ),
      )
    }
    if module_.interface.imported_interface_fingerprints !=
      module_.imported_interface_fingerprints ||
      module_.object.imported_interface_fingerprints !=
      module_.imported_interface_fingerprints {
      return Some(
        compile_error(
          InvalidModuleArtifact(
            module_path_text=module_.module_path_text,
            reason="imported interface mismatch",
          ),
          None,
        ),
      )
    }
    if module_.interface.module_fingerprint != module_.module_fingerprint ||
      module_.object.module_fingerprint != module_.module_fingerprint {
      return Some(
        compile_error(
          InvalidModuleArtifact(
            module_path_text=module_.module_path_text,
            reason="fingerprint mismatch",
          ),
          None,
        ),
      )
    }
    if module_.interface.interface_fingerprint !=
      interface_fingerprint(module_.interface.interface) {
      return Some(
        compile_error(
          InvalidModuleInterfaceArtifact(
            module_path_text=module_.module_path_text,
            reason="fingerprint mismatch",
          ),
          None,
        ),
      )
    }
    if module_.module_fingerprint !=
      module_fingerprint(
        module_.interface.interface,
        module_.imported_interface_fingerprints,
      ) {
      return Some(
        compile_error(
          InvalidModuleArtifact(
            module_path_text=module_.module_path_text,
            reason="fingerprint mismatch",
          ),
          None,
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
fn compiled_module_from_object_artifact(
  artifact : ModuleObjectArtifact,
) -> CompiledModule {
  {
    module_path_text: artifact.module_path_text,
    interface: artifact.interface,
    object: module_object_from_artifact(artifact),
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
