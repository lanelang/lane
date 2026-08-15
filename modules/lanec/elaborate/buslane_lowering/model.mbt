///|
pub struct BuslaneIntrinsicContract {
  priv intrinsic : @abi.Intrinsic
  priv type_ : @buslane.Type
} derive(Debug, Eq)

///|
pub struct BuslaneIntrinsicFunctionContract {
  priv intrinsic : @abi.Intrinsic
  priv parameters : Array[@buslane.Type]
  priv result : @buslane.Type
  priv effect : @buslane.Effect
  priv implementation : @abi.IntrinsicFunctionImplementation
} derive(Debug, Eq)

///|
pub struct BuslaneBuiltinExternal {
  priv value : @buslane.ValueId
  priv contract : BuslaneIntrinsicContract
} derive(Debug, Eq)

///|
pub fn BuslaneBuiltinExternal::from_intrinsic(
  value : @buslane.ValueId,
  intrinsic : @abi.Intrinsic,
  type_ : @buslane.Type,
) -> BuslaneBuiltinExternal {
  { value, contract: { intrinsic, type_ } }
}

///|
fn BuslaneBuiltinExternal::from_contract(
  value : @buslane.ValueId,
  contract : BuslaneIntrinsicContract,
) -> BuslaneBuiltinExternal {
  { value, contract }
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
  self.contract.intrinsic()
}

///|
pub fn BuslaneBuiltinExternal::contract(
  self : BuslaneBuiltinExternal,
) -> BuslaneIntrinsicContract {
  self.contract
}

///|
pub fn BuslaneBuiltinExternal::type_(
  self : BuslaneBuiltinExternal,
) -> @buslane.Type {
  self.contract.type_()
}

///|
pub fn BuslaneIntrinsicContract::intrinsic(
  self : BuslaneIntrinsicContract,
) -> @abi.Intrinsic {
  self.intrinsic
}

///|
pub fn BuslaneIntrinsicContract::type_(
  self : BuslaneIntrinsicContract,
) -> @buslane.Type {
  self.type_
}

///|
pub fn BuslaneIntrinsicContract::function_contract(
  self : BuslaneIntrinsicContract,
) -> BuslaneIntrinsicFunctionContract? {
  match (self.type_, self.intrinsic.signature()) {
    (Function(parameters, result, effect), Function(implementation~, ..)) =>
      Some({
        intrinsic: self.intrinsic,
        parameters: parameters.copy(),
        result,
        effect,
        implementation,
      })
    _ => None
  }
}

///|
pub fn BuslaneIntrinsicFunctionContract::intrinsic(
  self : BuslaneIntrinsicFunctionContract,
) -> @abi.Intrinsic {
  self.intrinsic
}

///|
pub fn BuslaneIntrinsicFunctionContract::implementation(
  self : BuslaneIntrinsicFunctionContract,
) -> @abi.IntrinsicFunctionImplementation {
  self.implementation
}

///|
pub fn BuslaneIntrinsicFunctionContract::parameter_types(
  self : BuslaneIntrinsicFunctionContract,
) -> Array[@buslane.Type] {
  self.parameters.copy()
}

///|
pub fn BuslaneIntrinsicFunctionContract::result_type(
  self : BuslaneIntrinsicFunctionContract,
) -> @buslane.Type {
  self.result
}

///|
pub fn BuslaneIntrinsicFunctionContract::type_(
  self : BuslaneIntrinsicFunctionContract,
) -> @buslane.Type {
  Function(self.parameters.copy(), self.result, self.effect)
}

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
  MetadataAllocationCompilerDefect(@buslane.MetadataAllocationError)
  MissingTypeReference(@symbol.TypeSymbolId)
  MissingEffectReference(@symbol.EffectSymbolId)
  MissingTypeDependency(String, String)
  MissingEffectDependency(String, String)
} derive(Debug, Eq)
