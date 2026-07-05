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
let module_object_artifact_schema_version = 4

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
  object_fingerprint : CompilationFingerprint
  imported_interface_fingerprints : Array[ImportedInterfaceFingerprint]
} derive(Debug, Eq)

///|
pub(all) struct LinkedProgramArtifact {
  schema_version : Int
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @elaborate.BuslaneExternalMap
  entries : Array[@elaborate.BuslaneEntry]
  runtime_effect_operations : Array[LinkedRuntimeEffectOperation]
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
pub fn CompiledModuleSet::to_artifact(
  self : CompiledModuleSet,
) -> CompiledModuleSetArtifact {
  {
    schema_version: 1,
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
    schema_version: 1,
    module_path_text: self.module_path_text,
    interface: self.to_interface_artifact(),
    object: self.to_object_artifact(),
    module_fingerprint: self.fingerprint,
    imported_interface_fingerprints: self.imported_interface_fingerprints,
  }
}

///|
pub fn CompiledModule::to_interface_artifact(
  self : CompiledModule,
) -> ModuleInterfaceArtifact {
  let interface = self.artifact_interface()
  {
    schema_version: 1,
    module_path_text: self.module_path_text,
    interface,
    interface_fingerprint: interface_fingerprint(interface),
    module_fingerprint: self.fingerprint,
    imported_interface_fingerprints: self.imported_interface_fingerprints,
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
  let interface = self.artifact_interface()
  {
    schema_version: module_object_artifact_schema_version,
    module_path_text: object.module_path_text,
    interface,
    interface_fingerprint: interface_fingerprint(interface),
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
pub fn LinkedProgram::to_artifact(
  self : LinkedProgram,
) -> LinkedProgramArtifact {
  {
    schema_version: 1,
    module_path_texts: self.module_path_texts,
    program: self.program,
    externals: self.externals,
    entries: self.entries,
    runtime_effect_operations: self.runtime_effect_operations,
  }
}

///|
pub fn LinkedProgramArtifact::to_linked_program(
  self : LinkedProgramArtifact,
) -> Result[LinkedProgram, Array[CompilerDiagnostic]] {
  let diagnostics = self.validate()
  if !diagnostics.is_empty() {
    Err(diagnostics)
  } else {
    Ok({
      module_path_texts: self.module_path_texts,
      program: self.program,
      externals: self.externals,
      entries: self.entries,
      runtime_effect_operations: self.runtime_effect_operations,
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
  match artifact.validate_schema() {
    Some(diagnostic) => { program: None, diagnostics: [diagnostic] }
    None => link_compiled_module_set(artifact.to_compiled_module_set())
  }
}

///|
fn compiled_modules_from_object_artifacts(
  objects : Array[ModuleObjectArtifact],
) -> Result[Array[CompiledModule], Array[CompilerDiagnostic]] {
  let diagnostics = ModuleObjectArtifact::validate_all(objects)
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  Ok(objects.map(ModuleObjectArtifact::to_compiled_module))
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
          CompileErrorKind::to_diagnostic(
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
      CompileErrorKind::to_diagnostic(
        UnsupportedModuleObjectArtifactSchema(
          schema=self.schema_version,
          module_path_text=self.module_path_text,
        ),
        None,
      ),
    )
  }
  if self.interface.module_path != self.module_path_text {
    return Some(
      CompileErrorKind::to_diagnostic(
        InvalidModuleObjectArtifact(
          module_path_text=self.module_path_text,
          reason="interface name mismatch",
        ),
        None,
      ),
    )
  }
  if self.interface_fingerprint != interface_fingerprint(self.interface) {
    return Some(
      CompileErrorKind::to_diagnostic(
        InvalidModuleObjectArtifact(
          module_path_text=self.module_path_text,
          reason="interface fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  if self.module_fingerprint !=
    module_fingerprint(self.interface, self.imported_interface_fingerprints) {
    return Some(
      CompileErrorKind::to_diagnostic(
        InvalidModuleObjectArtifact(
          module_path_text=self.module_path_text,
          reason="module fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  if self.object_fingerprint !=
    module_object_fingerprint(
      self.module_fingerprint,
      self.metadata,
      self.terms,
      self.externals,
      self.entries,
      self.exports,
      self.imports,
      self.imported_interface_fingerprints,
    ) {
    return Some(
      CompileErrorKind::to_diagnostic(
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
fn LinkedProgramArtifact::validate(
  self : LinkedProgramArtifact,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  if self.schema_version != 1 {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(
        UnsupportedLinkedProgramArtifactSchema,
        None,
      ),
    )
  }
  let verify_result = @buslane.verify_program(self.program)
  if !verify_result.is_ok() {
    diagnostics.push(
      CompileErrorKind::to_diagnostic(InvalidLinkedBuslaneProgram, None),
    )
  }
  self.validate_modules(diagnostics)
  self.validate_entries(diagnostics)
  self.validate_runtime_effect_operations(diagnostics)
  diagnostics
}

///|
fn LinkedProgramArtifact::validate_modules(
  self : LinkedProgramArtifact,
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  for index in 0..<self.module_path_texts.length() {
    for other_index in (index + 1)..<self.module_path_texts.length() {
      if self.module_path_texts[index] == self.module_path_texts[other_index] {
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            DuplicateLinkedModule(self.module_path_texts[index]),
            None,
          ),
        )
      }
    }
  }
}

///|
fn LinkedProgramArtifact::validate_entries(
  self : LinkedProgramArtifact,
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  for index in 0..<self.entries.length() {
    let entry = self.entries[index]
    if self.program.metadata.value_info(entry.value) is None {
      diagnostics.push(
        CompileErrorKind::to_diagnostic(
          LinkedEntryUnknownValue(entry.name),
          None,
        ),
      )
    }
    for other_index in (index + 1)..<self.entries.length() {
      if entry.name == self.entries[other_index].name {
        diagnostics.push(
          CompileErrorKind::to_diagnostic(
            DuplicateLinkedEntry(entry.name),
            None,
          ),
        )
      }
    }
  }
}

///|
fn LinkedProgramArtifact::validate_runtime_effect_operations(
  self : LinkedProgramArtifact,
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  for operation in self.runtime_effect_operations {
    if self.program.metadata.operation_info(operation.operation) is None {
      diagnostics.push(
        CompileErrorKind::to_diagnostic(InvalidLinkedBuslaneProgram, None),
      )
    }
  }
}

///|
fn CompiledModuleSetArtifact::validate_schema(
  self : CompiledModuleSetArtifact,
) -> CompilerDiagnostic? {
  if self.schema_version != 1 {
    return Some(
      CompileErrorKind::to_diagnostic(
        UnsupportedModuleArtifactSchema(None),
        None,
      ),
    )
  }
  for module_ in self.modules {
    if module_.schema_version != 1 {
      return Some(
        CompileErrorKind::to_diagnostic(
          UnsupportedModuleArtifactSchema(Some(module_.module_path_text)),
          None,
        ),
      )
    }
    if module_.interface.schema_version != 1 {
      return Some(
        CompileErrorKind::to_diagnostic(
          UnsupportedModuleInterfaceArtifactSchema(module_.module_path_text),
          None,
        ),
      )
    }
    match module_.interface.validate() {
      Some(diagnostic) => return Some(diagnostic)
      None => ()
    }
    if module_.object.schema_version != module_object_artifact_schema_version {
      return Some(
        CompileErrorKind::to_diagnostic(
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
        CompileErrorKind::to_diagnostic(
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
        CompileErrorKind::to_diagnostic(
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
        CompileErrorKind::to_diagnostic(
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
        CompileErrorKind::to_diagnostic(
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
        CompileErrorKind::to_diagnostic(
          InvalidModuleArtifact(
            module_path_text=module_.module_path_text,
            reason="fingerprint mismatch",
          ),
          None,
        ),
      )
    }
    if module_.object.object_fingerprint !=
      module_object_fingerprint(
        module_.module_fingerprint,
        module_.object.metadata,
        module_.object.terms,
        module_.object.externals,
        module_.object.entries,
        module_.object.exports,
        module_.object.imports,
        module_.object.imported_interface_fingerprints,
      ) {
      return Some(
        CompileErrorKind::to_diagnostic(
          InvalidModuleArtifact(
            module_path_text=module_.module_path_text,
            reason="object fingerprint mismatch",
          ),
          None,
        ),
      )
    }
  }
  None
}

///|
fn CompiledModuleSetArtifact::to_compiled_module_set(
  self : CompiledModuleSetArtifact,
) -> CompiledModuleSet {
  {
    root_module_path_text: self.root_module_path_text,
    modules: self.modules.map(CompiledModuleArtifact::to_compiled_module),
    reachable_module_path_texts: self.reachable_module_path_texts,
    diagnostics: [],
  }
}

///|
fn CompiledModuleArtifact::to_compiled_module(
  self : CompiledModuleArtifact,
) -> CompiledModule {
  {
    module_path_text: self.module_path_text,
    interface: self.interface.interface,
    object: self.object.to_module_object(),
    fingerprint: self.module_fingerprint,
    imported_interface_fingerprints: self.imported_interface_fingerprints,
  }
}

///|
fn ModuleObjectArtifact::to_compiled_module(
  self : ModuleObjectArtifact,
) -> CompiledModule {
  {
    module_path_text: self.module_path_text,
    interface: self.interface,
    object: self.to_module_object(),
    fingerprint: self.module_fingerprint,
    imported_interface_fingerprints: self.imported_interface_fingerprints,
  }
}

///|
fn ModuleObjectArtifact::to_module_object(
  self : ModuleObjectArtifact,
) -> ModuleObject {
  {
    module_path_text: self.module_path_text,
    checked: empty_checked_source_file(self.module_path_text),
    metadata: self.metadata,
    terms: self.terms,
    externals: self.externals,
    entries: self.entries,
    exports: self.exports,
    imports: self.imports,
    fingerprint: self.module_fingerprint,
    object_fingerprint: self.object_fingerprint,
    imported_interface_fingerprints: self.imported_interface_fingerprints,
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
