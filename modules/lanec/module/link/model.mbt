///|
pub(all) struct LinkModuleObject {
  module_path_text : String
  interface : @module_interface.ModuleInterface?
  interface_fingerprint : @artifact_core.CompilationFingerprint
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
  exports : Array[@buslane_lowering.BuslaneModuleExport]
  imports : Array[@artifact_core.ModuleImportedReference]
  fingerprint : @artifact_core.CompilationFingerprint
  object_fingerprint_valid : Bool
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ]
} derive(Debug, Eq)

///|
pub(all) struct LinkedProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entries : Array[@buslane_lowering.BuslaneEntry]
} derive(Debug, Eq)

///|
pub(all) struct LinkResult {
  program : LinkedProgram?
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)
