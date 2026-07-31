///|
pub(all) struct BuslaneBuiltinExternal {
  value : @buslane.ValueId
  intrinsic : @abi.Intrinsic
  type_ : @buslane.Type
} derive(Debug, Eq)

///|
pub(all) struct BuslaneRuntimeImport {
  value : @buslane.ValueId
  symbol : String
  signature : @abi.HostSignature
  type_ : @buslane.Type
} derive(Debug, Eq)

///|
pub(all) struct BuslaneExternalMap {
  builtins : Array[BuslaneBuiltinExternal]
  runtime_imports : Array[BuslaneRuntimeImport]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneEntry {
  module_path_text : String
  name : String
  value : @buslane.ValueId
  type_ : @buslane.Type
} derive(Debug, Eq)

///|
pub(all) enum BuslaneModuleReference {
  Type(@buslane.TypeId)
  DataConstructor(@buslane.DataConId)
  Effect(@buslane.EffectId)
  Operation(@buslane.OperationId)
  FieldSelector(@buslane.ValueId)
  Value(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) struct BuslaneModuleExport {
  name : String
  reference : BuslaneModuleReference
} derive(Debug, Eq)

///|
pub(all) struct BuslaneModuleImport {
  module_path_text : String
  name : String
  reference : BuslaneModuleReference
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

///|
pub(all) suberror BuslaneLoweringError {
  MissingTypeReference(@symbol.TypeSymbolId)
  MissingEffectReference(@symbol.EffectSymbolId)
  MissingTypeDependency(String, String)
  MissingEffectDependency(String, String)
} derive(Debug, Eq)
