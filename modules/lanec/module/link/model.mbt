///|
/// A module object prepared for the linker. Public construction is intentional:
/// the linker treats every field as untrusted and validates ordering,
/// fingerprints, imports, exports, and object integrity before remapping it.
pub(all) struct LinkModuleObject {
  module_path_text : String
  interface : @module_interface.ModuleInterface?
  interface_fingerprint : @artifact_model.CompilationFingerprint
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact_model.ModuleImportedReference]
  fingerprint : @artifact_model.CompilationFingerprint
  object_fingerprint_valid : Bool
  imported_interface_fingerprints : Array[
    @artifact_model.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
priv struct ValidatedLinkModuleObject {
  object : LinkModuleObject
}

///|
/// A fully linked Buslane program whose module paths and entries are in stable
/// linker order and whose metadata identities have been remapped exactly once.
pub(all) struct LinkedProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
} derive(Debug, Eq)

///|
/// Complete link result. `program` is `None` whenever diagnostics contain a
/// blocking link failure; the linker never exposes a partial linked program.
pub(all) struct LinkResult {
  program : LinkedProgram?
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)
