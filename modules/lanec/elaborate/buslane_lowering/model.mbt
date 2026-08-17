///|
pub struct BuslaneBuiltinExternal {
  priv value : @buslane.ValueId
  priv intrinsic : @abi.Intrinsic
} derive(Debug, Eq)

///|
pub fn BuslaneBuiltinExternal::from_intrinsic(
  value : @buslane.ValueId,
  intrinsic : @abi.Intrinsic,
) -> BuslaneBuiltinExternal {
  { value, intrinsic }
}

///|
pub fn BuslaneBuiltinExternal::value(
  self : BuslaneBuiltinExternal,
) -> @buslane.ValueId {
  self.value
}

///|
pub fn BuslaneBuiltinExternal::intrinsic(
  self : BuslaneBuiltinExternal,
) -> @abi.Intrinsic {
  self.intrinsic
}

///|
pub suberror BuslaneSourceTypeError {
  MissingValueMetadata(value~ : @buslane.ValueId)
} derive(Debug, Eq)

///|
/// Returns the one source semantic type owned by Buslane metadata.
pub fn source_value_type(
  metadata : @buslane.MetadataRegistry,
  value : @buslane.ValueId,
) -> @buslane.Type raise BuslaneSourceTypeError {
  match metadata.value_info(value) {
    Some(info) => info.type_
    None => raise MissingValueMetadata(value~)
  }
}

///|
pub(all) struct BuslaneRuntimeImport {
  value : @buslane.ValueId
  symbol : String
  signature : @abi.HostSignature
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
  canonical_basic_abi : @canonical_basic_abi.CanonicalBasicAbiRuntimeContract
  program : @buslane.Program
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
  MetadataAllocationCompilerDefect(@buslane.MetadataAllocationError)
  MissingTypeReference(@symbol.TypeSymbolId)
  MissingEffectReference(@symbol.EffectSymbolId)
  MissingTypeDependency(String, String)
  MissingEffectDependency(String, String)
} derive(Debug, Eq)
