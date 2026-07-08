///|
pub(all) struct BuslaneBuiltinExternal {
  value : @buslane.ValueId
  name : String
  type_ : @buslane.Type
} derive(Debug, Eq)

///|
pub(all) struct BuslaneExternalMap {
  builtins : Array[BuslaneBuiltinExternal]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneEntry {
  module_path_text : String
  name : String
  value : @buslane.ValueId
  type_ : @buslane.Type
} derive(Debug, Eq)

///|
pub(all) enum BuslaneModuleExportKind {
  Type
  DataConstructor
  Effect
  Operation
  FieldSelector
  Value
} derive(Debug, Eq)

///|
pub(all) struct BuslaneModuleExport {
  kind : BuslaneModuleExportKind
  name : String
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  effect_id : @buslane.EffectId?
  operation : @buslane.OperationId?
  value : @buslane.ValueId?
} derive(Debug, Eq)

///|
pub(all) struct BuslaneModuleImport {
  module_path_text : String
  kind : BuslaneModuleExportKind
  name : String
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  effect_id : @buslane.EffectId?
  operation : @buslane.OperationId?
  value : @buslane.ValueId?
} derive(Debug, Eq)

///|
pub(all) struct BuslaneLowerResult {
  program : @buslane.Program
  externals : BuslaneExternalMap
  entries : Array[BuslaneEntry]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneModuleObject {
  module_path_text : String
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : BuslaneExternalMap
  entries : Array[BuslaneEntry]
  exports : Array[BuslaneModuleExport]
  imports : Array[BuslaneModuleImport]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneModuleObjectSet {
  objects : Array[BuslaneModuleObject]
} derive(Debug, Eq)
