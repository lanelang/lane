///|
pub(all) struct CompilationFingerprint {
  value : String
} derive(Debug, Eq)

///|
pub(all) struct ImportedInterfaceFingerprint {
  module_path_text : String
  fingerprint : CompilationFingerprint
} derive(Debug, Eq)

///|
pub(all) struct ModuleImportedReference {
  module_path_text : String
  kind : @buslane_lowering.BuslaneModuleExportKind
  name : String
  fingerprint : CompilationFingerprint
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  effect_id : @buslane.EffectId?
  operation : @buslane.OperationId?
  value : @buslane.ValueId?
} derive(Debug, Eq)
