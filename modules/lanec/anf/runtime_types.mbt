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
/// A runtime representation-evidence identity. Projected identities are owned
/// by Runtime ANF; synthetic identities are owned by a downstream lowering
/// plan and can never collide with them.
pub(all) enum RuntimeEvidenceId {
  Projected(Int)
  Synthetic(Int)
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
  priv values : Array[RuntimeValueInfo]
  priv types : Array[RuntimeDataInfo]
  priv data_constructors : Array[RuntimeDataConstructorInfo]
  priv evidence_parameters : Array[RuntimeEvidenceParameter?]
  priv type_expressions : Array[RuntimeTypeExpression]
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
  match parameter {
    Projected(index) => self.evidence_parameters.get(index).bind(value => value)
    Synthetic(_) => None
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
pub fn RuntimeMetadata::type_expressions(
  self : RuntimeMetadata,
) -> ArrayView[RuntimeTypeExpression] {
  self.type_expressions[:]
}

///|
fn RuntimeMetadata::snapshot(self : RuntimeMetadata) -> RuntimeMetadata {
  {
    values: self.values.map(info => { type_: info.type_.snapshot() }),
    types: self.types.map(info => {
      kind: info.kind,
      evidence_parameters: info.evidence_parameters.copy(),
      constructors: info.constructors.copy(),
    }),
    data_constructors: self.data_constructors.map(info => {
      owner: info.owner,
      hidden_evidence_parameters: info.hidden_evidence_parameters.copy(),
      payload_types: info.payload_types.map(type_ => type_.snapshot()),
    }),
    evidence_parameters: self.evidence_parameters.copy(),
    type_expressions: self.type_expressions.map(expression => {
      expression.snapshot()
    }),
  }
}

///|
fn RuntimeArgument::snapshot(self : RuntimeArgument) -> RuntimeArgument {
  { type_expression: self.type_expression, evidence: self.evidence.snapshot() }
}

///|
fn RuntimeEvidence::snapshot(self : RuntimeEvidence) -> RuntimeEvidence {
  match self {
    Static(_) | Parameter(_) => self
    Apply(callee, arguments) =>
      Apply(callee.snapshot(), arguments.map(argument => argument.snapshot()))
    Lambda(parameters, body) => Lambda(parameters.copy(), body.snapshot())
  }
}

///|
fn RuntimeType::snapshot(self : RuntimeType) -> RuntimeType {
  match self {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => self
    Data(owner, arguments) =>
      Data(owner, arguments.map(argument => argument.snapshot()))
    Callable(parameters, result) =>
      Callable(
        parameters.map(parameter => parameter.snapshot()),
        result.snapshot(),
      )
    Erased(expression, evidence) => Erased(expression, evidence.snapshot())
    Forall(parameters, body) => Forall(parameters.copy(), body.snapshot())
  }
}

///|
fn RuntimeTypeExpression::snapshot(
  self : RuntimeTypeExpression,
) -> RuntimeTypeExpression {
  match self {
    Static(type_) => Static(type_.snapshot())
    Parameter(_) => self
    Apply(callee, arguments) => Apply(callee, arguments.copy())
    Lambda(parameters, body) => Lambda(parameters.copy(), body)
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
