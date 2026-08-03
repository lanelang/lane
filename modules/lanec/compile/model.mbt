///|
pub(all) struct SourceInput {
  source_id : String
  text : String
} derive(Debug, Eq)

///|
pub(all) struct CompilationRequest {
  root : SourceInput
  libraries : Array[SourceInput]
} derive(Debug, Eq)

///|
pub(all) struct InterfaceCompilationRequest {
  root : SourceInput
  interfaces : Array[@artifact.ModuleInterfaceArtifact]
} derive(Debug, Eq)

///|
pub struct CompilationWarnings {
  priv diagnostics : Array[CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub struct CompilationFailure {
  priv diagnostics : Array[CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub(all) enum CompilationOutcome[T] {
  Succeeded(T, CompilationWarnings)
  Failed(CompilationFailure)
} derive(Debug, Eq)

///|
fn detached_compiler_diagnostic(
  diagnostic : CompilerDiagnostic,
) -> CompilerDiagnostic {
  {
    ..diagnostic,
    labels: diagnostic.labels.copy(),
    notes: diagnostic.notes.copy(),
    helps: diagnostic.helps.copy(),
    facts: diagnostic.facts.copy(),
    suggestions: diagnostic.suggestions.map(suggestion => {
      ..suggestion,
      edits: suggestion.edits.copy(),
    }),
  }
}

///|
fn detached_compiler_diagnostics(
  diagnostics : Array[CompilerDiagnostic],
) -> Array[CompilerDiagnostic] {
  diagnostics.map(detached_compiler_diagnostic)
}

///|
pub fn CompilationWarnings::diagnostics(
  self : CompilationWarnings,
) -> Array[CompilerDiagnostic] {
  detached_compiler_diagnostics(self.diagnostics)
}

///|
pub fn CompilationFailure::diagnostics(
  self : CompilationFailure,
) -> Array[CompilerDiagnostic] {
  detached_compiler_diagnostics(self.diagnostics)
}

///|
pub fn[T] CompilationOutcome::diagnostics(
  self : CompilationOutcome[T],
) -> Array[CompilerDiagnostic] {
  match self {
    Succeeded(_, warnings) => warnings.diagnostics()
    Failed(failure) => failure.diagnostics()
  }
}

///|
fn[T] compilation_succeeded(
  value : T,
  diagnostics : Array[CompilerDiagnostic],
) -> CompilationOutcome[T] {
  if diagnostics.any(diagnostic => diagnostic.severity is Error) {
    abort("successful compilation cannot contain error diagnostics")
  }
  Succeeded(value, { diagnostics: detached_compiler_diagnostics(diagnostics) })
}

///|
fn[T] compilation_failed(
  diagnostics : Array[CompilerDiagnostic],
) -> CompilationOutcome[T] {
  if !diagnostics.any(diagnostic => diagnostic.severity is Error) {
    abort("failed compilation must contain an error diagnostic")
  }
  Failed({ diagnostics: detached_compiler_diagnostics(diagnostics) })
}

///|
pub struct CompiledModules {
  priv modules : @module_compile.CompiledModuleSet
} derive(Debug, Eq)

///|
pub fn CompiledModules::artifact(
  self : CompiledModules,
) -> @artifact.CompiledModuleSetArtifact {
  self.modules.to_artifact()
}

///|
pub fn CompiledModules::root_module_path_text(self : CompiledModules) -> String {
  self.modules.root_module_path_text
}

///|
pub fn CompiledModules::module_count(self : CompiledModules) -> Int {
  self.modules.modules.length()
}

///|
pub struct CompiledProgram {
  priv linked : @module_link.LinkedProgram
} derive(Debug, Eq)

///|
pub struct CompiledEntry {
  priv entry : @buslane_lowering.BuslaneEntry
} derive(Debug, Eq)

///|
pub fn CompiledProgram::entries(self : CompiledProgram) -> Array[CompiledEntry] {
  self.linked.entries.map(entry => { entry, })
}

///|
pub fn CompiledProgram::module_path_texts(
  self : CompiledProgram,
) -> Array[String] {
  self.linked.module_path_texts.copy()
}

///|
pub fn CompiledProgram::buslane_text(
  self : CompiledProgram,
  width? : Int = 100,
) -> String {
  render_buslane_program(self.linked.program, width)
}

///|
pub fn CompiledProgram::elaborate_entry(
  self : CompiledProgram,
  entry : CompiledEntry,
) -> Result[
  @executable.ExecutableProgram,
  @executable.ExecutableElaborationError,
] {
  @executable.elaborate(self.linked, entry.entry)
}

///|
pub fn CompiledProgram::elaborate_entry_observed(
  self : CompiledProgram,
  entry : CompiledEntry,
  observe : (@executable.ExecutableElaborationStage) -> Unit,
) -> Result[
  @executable.ExecutableProgram,
  @executable.ExecutableElaborationError,
] {
  @executable.elaborate_observed(self.linked, entry.entry, observe)
}

///|
pub fn CompiledProgram::entry_effect_is_executable(
  self : CompiledProgram,
  entry : CompiledEntry,
) -> Bool {
  match entry.entry.type_ {
    Function(_, _, effect) =>
      @executable.entry_effect_is_executable(
        self.linked.program.metadata,
        effect,
      )
    _ => false
  }
}

///|
pub fn CompiledEntry::module_path_text(self : CompiledEntry) -> String {
  self.entry.module_path_text
}

///|
pub fn CompiledEntry::name(self : CompiledEntry) -> String {
  self.entry.name
}

///|
pub fn CompiledEntry::type_(self : CompiledEntry) -> @buslane.Type {
  self.entry.type_
}

///|
pub fn CompiledEntry::type_text(
  self : CompiledEntry,
  width? : Int = 100,
) -> String {
  @prettyprinter.render(self.entry.type_, width~)
}

///|
pub(all) struct CompilationStageSnapshot {
  module_path_text : String
  text : String
} derive(Debug, Eq)

///|
pub(all) enum SourceCompilationStage {
  Syntax(CompilationStageSnapshot)
  Resolved(CompilationStageSnapshot)
  Checked(CompilationStageSnapshot)
  BuslaneModule(CompilationStageSnapshot)
} derive(Debug, Eq)
