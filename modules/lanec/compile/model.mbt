///|
/// Describes a source compilation rooted at `root`.
///
/// `libraries` is an unordered source pool: compilation discovers the
/// import-reachable closure and ignores dead library modules.
pub(all) struct CompilationRequest {
  root : @module_frontend.SourceInput
  libraries : Array[@module_frontend.SourceInput]
} derive(Debug, Eq)

///|
/// Describes compilation of one source module against persisted interfaces.
/// The interface artifacts are untrusted and are validated before use.
pub(all) struct InterfaceCompilationRequest {
  root : @module_frontend.SourceInput
  interfaces : Array[@artifact.ModuleInterfaceArtifact]
} derive(Debug, Eq)

///|
/// Owns the non-blocking diagnostics from a successful compilation.
/// Accessors return detached diagnostic values, including nested arrays.
pub struct CompilationWarnings {
  priv diagnostics : Array[CompilerDiagnostic]
} derive(Debug, Eq)

///|
/// Owns the blocking diagnostics from a failed compilation. A failure always
/// contains at least one error and never carries a partial product.
pub struct CompilationFailure {
  priv diagnostics : Array[CompilerDiagnostic]
} derive(Debug, Eq)

///|
/// The complete result of a facade operation.
///
/// `Succeeded` may carry warnings but never errors. `Failed` carries at least
/// one error and no partial `T`, so callers cannot accidentally consume output
/// from an incomplete compiler stage.
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
/// Returns a deep, mutation-isolated copy of the successful diagnostics.
pub fn CompilationWarnings::diagnostics(
  self : CompilationWarnings,
) -> Array[CompilerDiagnostic] {
  detached_compiler_diagnostics(self.diagnostics)
}

///|
/// Returns a deep, mutation-isolated copy of the failure diagnostics.
pub fn CompilationFailure::diagnostics(
  self : CompilationFailure,
) -> Array[CompilerDiagnostic] {
  detached_compiler_diagnostics(self.diagnostics)
}

///|
/// Returns all diagnostics regardless of whether the outcome succeeded.
/// The returned diagnostics do not alias storage retained by the outcome.
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
/// An opaque, independently compiled source-module set ready for linking or
/// persistence. Module order is compiler-owned and deterministic.
pub struct CompiledModules {
  priv modules : @module_compile.CompiledModuleSet
} derive(Debug, Eq)

///|
/// Returns a detached persistence artifact for the complete module set.
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
/// An opaque linked Buslane program. Its entry and module queries return values
/// detached from the facade's mutable collections.
pub struct CompiledProgram {
  priv linked : @module_link.LinkedProgram
} derive(Debug, Eq)

///|
/// An entry identity owned by the `CompiledProgram` that produced it.
pub struct CompiledEntry {
  priv entry : @buslane_lowering.BuslaneEntry
} derive(Debug, Eq)

///|
/// Lists linked executable candidates in deterministic link order.
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
/// Elaborates one linked entry through specialization, effect lowering, and
/// core optimization. An entry from another program is rejected structurally.
pub fn CompiledProgram::elaborate_entry(
  self : CompiledProgram,
  entry : CompiledEntry,
  profile : @executable.ExecutionProfile,
) -> Result[
  @executable.ExecutableProgram,
  @executable.ExecutableElaborationError,
] {
  @executable.elaborate(self.linked, entry.entry, profile)
}

///|
/// Elaborates an entry and reports each completed whole-program stage in
/// pipeline order. No later stage is observed after the first failure.
pub fn CompiledProgram::elaborate_entry_observed(
  self : CompiledProgram,
  entry : CompiledEntry,
  profile : @executable.ExecutionProfile,
  observe : (@executable.ExecutableElaborationStage) -> Unit,
) -> Result[
  @executable.ExecutableProgram,
  @executable.ExecutableElaborationError,
] {
  @executable.elaborate_observed(self.linked, entry.entry, profile, observe)
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
pub fn CompiledProgram::entry_type(
  self : CompiledProgram,
  entry : CompiledEntry,
) -> @buslane.Type? {
  guard self.linked.entries.contains(entry.entry) else { return None }
  Some(
    @buslane_lowering.source_value_type(
      self.linked.program.metadata,
      entry.entry.value,
    ),
  ) catch {
    MissingValueMetadata(_) => None
  }
}

///|
pub fn CompiledProgram::entry_type_text(
  self : CompiledProgram,
  entry : CompiledEntry,
  width? : Int = 100,
) -> String? {
  self.entry_type(entry).map(type_ => @prettyprinter.render(type_, width~))
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
