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
  kind : @elaborate.BuslaneModuleExportKind
  name : String
  fingerprint : CompilationFingerprint
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  effect_id : @buslane.EffectId?
  operation : @buslane.OperationId?
  value : @buslane.ValueId?
} derive(Debug, Eq)

///|
pub(all) struct LinkedRuntimeEffectOperation {
  module_path_text : String
  effect_name : String
  operation_name : String
  payload : Array[@types.Type]
  result : @types.Type
  operation : @buslane.OperationId
} derive(Debug, Eq)
