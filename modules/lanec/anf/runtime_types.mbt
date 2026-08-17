///|
/// The execution-level scalar distinctions that survive CPS Core projection.
pub(all) enum RuntimeScalarType {
  Bool
  I64
  I32
  Char
  F64
  F32
  Byte
} derive(Debug, Eq)

///|
/// A layout that can be materialized without source type computation.
pub(all) enum RuntimeLayout {
  Unit
  Bool
  I64
  I32
  Char
  F64
  F32
  Byte
  ByteSequence
  Reference
  Callable
} derive(Debug, Eq)

///|
/// A program-wide identity for runtime representation evidence.
pub(all) struct RuntimeEvidenceId {
  index : Int
} derive(Debug, Eq, Compare, Hash)

///|
/// A runtime-polymorphic binder. `arity == 0` denotes a layout witness;
/// positive arity denotes a layout-constructor witness.
pub(all) struct RuntimeEvidenceParameter {
  id : RuntimeEvidenceId
  arity : Int
} derive(Debug, Eq)

///|
/// A closed description of the evidence passed by a runtime type application.
pub(all) enum RuntimeEvidence {
  Static(RuntimeLayout)
  Parameter(RuntimeEvidenceId)
  Apply(RuntimeEvidence, Array[RuntimeEvidence])
  Lambda(Array[RuntimeEvidenceParameter], RuntimeEvidence)
} derive(Debug, Eq)

///|
/// An interned representation-level type expression used only to instantiate
/// abstract runtime shapes. It carries no source effect or nominal argument
/// semantics.
pub(all) struct RuntimeTypeExpressionId {
  index : Int
} derive(Debug, Eq, Compare, Hash)

///|
/// The value types observable after runtime projection. This is deliberately
/// not a second source type language: effects, kinds, nominal type arguments,
/// and type-level computation do not survive this seam.
pub(all) enum RuntimeType {
  Unit
  Scalar(RuntimeScalarType)
  ByteSequence
  OpaqueReference(@buslane.TypeId)
  Data(@buslane.TypeId, Array[RuntimeArgument])
  Callable(Array[RuntimeType], RuntimeType)
  Erased(RuntimeTypeExpressionId, RuntimeEvidence)
  Forall(Array[RuntimeEvidenceParameter], RuntimeType)
} derive(Debug, Eq)

///|
pub(all) enum RuntimeTypeExpression {
  Static(RuntimeType)
  Parameter(RuntimeEvidenceId)
  Apply(RuntimeTypeExpressionId, Array[RuntimeTypeExpressionId])
  Lambda(Array[RuntimeEvidenceParameter], RuntimeTypeExpressionId)
} derive(Debug, Eq)

///|
pub(all) struct RuntimeArgument {
  type_expression : RuntimeTypeExpressionId
  evidence : RuntimeEvidence
} derive(Debug, Eq)

///|
pub(all) struct RuntimeValueInfo {
  type_ : RuntimeType
} derive(Debug, Eq)

///|
pub(all) enum RuntimeNominalKind {
  Data
  OpaqueReference
} derive(Debug, Eq)

///|
pub(all) struct RuntimeDataInfo {
  kind : RuntimeNominalKind
  evidence_parameters : Array[RuntimeEvidenceParameter]
  constructors : Array[@buslane.DataConId]
} derive(Debug, Eq)

///|
pub(all) struct RuntimeDataConstructorInfo {
  owner : @buslane.TypeId
  hidden_evidence_parameters : Array[RuntimeEvidenceParameter]
  payload_types : Array[RuntimeType]
} derive(Debug, Eq)

///|
/// Runtime metadata is indexed by stable Buslane declaration identities, but
/// contains no Buslane type or effect terms.
pub(all) struct RuntimeMetadata {
  values : Array[RuntimeValueInfo]
  types : Array[RuntimeDataInfo]
  data_constructors : Array[RuntimeDataConstructorInfo]
  evidence_parameters : Array[RuntimeEvidenceParameter?]
  type_expressions : Array[RuntimeTypeExpression]
} derive(Debug, Eq)

///|
pub fn RuntimeMetadata::value_info(
  self : RuntimeMetadata,
  value : @buslane.ValueId,
) -> RuntimeValueInfo? {
  self.values.get(value.index)
}

///|
pub fn RuntimeMetadata::evidence_parameter(
  self : RuntimeMetadata,
  parameter : RuntimeEvidenceId,
) -> RuntimeEvidenceParameter? {
  if parameter.index < 0 {
    Some({ id: parameter, arity: 0 })
  } else {
    self.evidence_parameters.get(parameter.index).bind(value => value)
  }
}

///|
pub fn RuntimeMetadata::type_info(
  self : RuntimeMetadata,
  type_ : @buslane.TypeId,
) -> RuntimeDataInfo? {
  self.types.get(type_.index)
}

///|
pub fn RuntimeMetadata::data_constructor_info(
  self : RuntimeMetadata,
  data_constructor : @buslane.DataConId,
) -> RuntimeDataConstructorInfo? {
  self.data_constructors.get(data_constructor.index)
}

///|
pub fn RuntimeMetadata::type_expression(
  self : RuntimeMetadata,
  expression : RuntimeTypeExpressionId,
) -> RuntimeTypeExpression? {
  self.type_expressions.get(expression.index)
}

///|
pub fn RuntimeMetadata::intern_type_expression(
  self : RuntimeMetadata,
  expression : RuntimeTypeExpression,
) -> RuntimeTypeExpressionId {
  for index, existing in self.type_expressions {
    if existing == expression {
      return { index, }
    }
  }
  let id : RuntimeTypeExpressionId = { index: self.type_expressions.length() }
  self.type_expressions.push(expression)
  id
}

///|
fn RuntimeMetadata::snapshot(self : RuntimeMetadata) -> RuntimeMetadata {
  {
    values: self.values.copy(),
    types: self.types.copy(),
    data_constructors: self.data_constructors.copy(),
    evidence_parameters: self.evidence_parameters.copy(),
    type_expressions: self.type_expressions.copy(),
  }
}

///|
pub fn RuntimeMetadata::parameter_type_expression(
  self : RuntimeMetadata,
  parameter : RuntimeEvidenceId,
) -> RuntimeTypeExpressionId? {
  for index, expression in self.type_expressions {
    if expression is Parameter(actual) && actual == parameter {
      return Some({ index, })
    }
  }
  None
}

///|
pub fn RuntimeType::layout(self : RuntimeType) -> RuntimeLayout? {
  match self {
    Unit => Some(Unit)
    Scalar(Bool) => Some(Bool)
    Scalar(I64) => Some(I64)
    Scalar(I32) => Some(I32)
    Scalar(Char) => Some(Char)
    Scalar(F64) => Some(F64)
    Scalar(F32) => Some(F32)
    Scalar(Byte) => Some(Byte)
    ByteSequence => Some(ByteSequence)
    OpaqueReference(_) | Data(_, _) => Some(Reference)
    Callable(_, _) | Forall(_, _) => Some(Callable)
    Erased(_, _) => None
  }
}
