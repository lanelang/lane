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
pub fn ImportParameter::core_types(
  self : ImportParameter,
) -> Array[CoreValueType] {
  match self {
    ErasedUnit => []
    Direct(type_) => [type_]
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
