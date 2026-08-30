///|
pub(all) enum CoreValueType {
  I32
  I64
  F32
  F64
} derive(Debug, Eq, Compare)

///|
pub(all) enum ImportParameter {
  ErasedUnit
  Direct(CoreValueType)
  GuestAddress
} derive(Debug, Eq, Compare)

///|
pub(all) enum ImportResult {
  Unit
  Direct(CoreValueType)
} derive(Debug, Eq, Compare)

///|
pub(all) struct ImportContract {
  module_name : String
  field_name : String
  parameters : Array[ImportParameter]
  result : ImportResult
} derive(Debug, Eq, Compare)

///|
/// Returns a contract whose mutable parameter storage is independent.
pub fn ImportContract::snapshot(self : ImportContract) -> ImportContract {
  { ..self, parameters: self.parameters.copy(), }
}

///|
/// Projects the source-facing guest contract to the exact core Wasm import
/// signature. Guest addresses are represented by wasm32 `i32` only after the
/// compiler-owned lifetime adapter has materialized them.
pub fn ImportContract::core_contract(self : ImportContract) -> ImportContract {
  {
    ..self,
    parameters: self.parameters.map(parameter => {
      match parameter {
        GuestAddress => Direct(I32)
        ErasedUnit | Direct(_) => parameter
      }
    }),
  }
}

///|
pub fn ImportParameter::core_types(
  self : ImportParameter,
) -> Array[CoreValueType] {
  match self {
    ErasedUnit => []
    Direct(type_) => [type_]
    GuestAddress => [I32]
  }
}

///|
pub fn ImportResult::core_types(self : ImportResult) -> Array[CoreValueType] {
  match self {
    Unit => []
    Direct(type_) => [type_]
  }
}

///|
pub fn ImportContract::core_parameters(
  self : ImportContract,
) -> Array[CoreValueType] {
  let types = []
  for parameter in self.parameters {
    types.append(parameter.core_types())
  }
  types
}

///|
pub fn ImportContract::core_results(
  self : ImportContract,
) -> Array[CoreValueType] {
  self.result.core_types()
}
