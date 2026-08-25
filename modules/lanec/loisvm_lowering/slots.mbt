///|
fn canonical_scalar_key(
  representation : @bytecode.Representation,
) -> CanonicalRuntimeTypeKey {
  Value({ representation, cleanup: Trivial, kind: ScalarValue, })
}

///|
fn canonical_byte_sequence_key() -> CanonicalRuntimeTypeKey {
  Value({ representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue, })
}

///|
fn FunctionLowerer::fresh_metadata(
  self : FunctionLowerer,
  metadata : @vmcfg.ValueMetadata,
) -> @vmcfg.ValueId {
  let value : @vmcfg.ValueId = { value: self.values.length(), }
  self.values.push(metadata)
  value
}

///|
fn runtime_type_mentions_any(
  type_ : @anf.RuntimeType,
  parameters : Array[@anf.RuntimeEvidenceId],
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => false
    Data(_, _) => false
    Callable(arguments, result) =>
      arguments.any(argument => {
        runtime_type_mentions_any(argument, parameters, bound)
      }) ||
      runtime_type_mentions_any(result, parameters, bound)
    Erased(_, evidence) =>
      runtime_evidence_mentions_any(evidence, parameters, bound)
    Forall(binders, body) => {
      let nested = bound.copy()
      nested.append(binders.map(binder => binder.id))
      runtime_type_mentions_any(body, parameters, nested)
    }
  }
}

///|
fn runtime_evidence_mentions_any(
  evidence : @anf.RuntimeEvidence,
  parameters : Array[@anf.RuntimeEvidenceId],
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match evidence {
    Static(_) => false
    Parameter(parameter) =>
      !bound.contains(parameter) && parameters.contains(parameter)
    Apply(callee, arguments) =>
      runtime_evidence_mentions_any(callee, parameters, bound) ||
      arguments.any(argument => {
        runtime_evidence_mentions_any(argument, parameters, bound)
      })
    Lambda(binders, body) => {
      let nested = bound.copy()
      nested.append(binders.map(binder => binder.id))
      runtime_evidence_mentions_any(body, parameters, nested)
    }
  }
}

///|
fn FunctionLowerer::fresh_erased_slot(
  self : FunctionLowerer,
  witness : @vmcfg.ValueId,
  ownership : @vmcfg.Ownership,
) -> @vmcfg.ValueId {
  self.fresh_metadata({
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    ownership,
    erased_companion: Some(witness),
  })
}

///|
fn ImageLowerer::elaborate_runtime_representation(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> RuntimeRepresentation raise LoisvmLoweringError {
  let metadata : @vmcfg.ValueMetadata = match type_ {
    Unit => return RuntimeUnit
    Erased(_, _) => return RuntimeErased
    Scalar(Bool | I32 | Char | Byte) =>
      canonical_scalar_key(I32).value_metadata(None)
    Scalar(I64) => canonical_scalar_key(I64).value_metadata(None)
    Scalar(F32) => canonical_scalar_key(F32).value_metadata(None)
    Scalar(F64) => canonical_scalar_key(F64).value_metadata(None)
    ByteSequence => canonical_byte_sequence_key().value_metadata(None)
    Callable(_, _) | Forall(_, _) =>
      {
        representation: I64,
        cleanup: OwnedCallable,
        kind: CallableValue,
        ownership: Owned,
        erased_companion: None,
      }
    Data(owner, _) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: DataValue(
          self.materialize_data_family(self.data_family(Declaration(owner))),
        ),
        ownership: Owned,
        erased_companion: None,
      }
    OpaqueReference(_) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: OpaqueReferenceValue,
        ownership: Owned,
        erased_companion: None,
      }
  }
  Concrete(type_, metadata)
}

///|
fn environment_metadata(
  shape : @bytecode.ObjectShapeId,
) -> @vmcfg.ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    kind: EnvironmentValue(shape),
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn layout_witness_metadata() -> @vmcfg.ValueMetadata {
  {
    representation: I32,
    cleanup: Trivial,
    kind: LayoutValue,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
fn layout_constructor_metadata(arity : Int) -> @vmcfg.ValueMetadata {
  {
    representation: I64,
    cleanup: OwnedCallable,
    kind: LayoutConstructorValue(arity),
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn borrowed_evidence_metadata(
  metadata : @vmcfg.ValueMetadata,
) -> @vmcfg.ValueMetadata {
  if metadata.cleanup is Trivial {
    metadata
  } else {
    { ..metadata, ownership: Borrowed, }
  }
}

///|
fn runtime_evidence_metadata(
  parameter : @anf.RuntimeEvidenceParameter,
) -> @vmcfg.ValueMetadata {
  if parameter.arity == 0 {
    layout_witness_metadata()
  } else {
    layout_constructor_metadata(parameter.arity)
  }
}

///|
priv enum RuntimeRepresentation {
  RuntimeUnit
  Concrete(@anf.RuntimeType, @vmcfg.ValueMetadata)
  RuntimeErased
}

///|
priv enum RuntimeTypeClass {
  Erased(@anf.RuntimeEvidence)
  Concrete(@anf.RuntimeType)
}

///|
fn ImageLowerer::types_representation_equivalent(
  self : ImageLowerer,
  left : @anf.RuntimeType,
  right : @anf.RuntimeType,
) -> Bool {
  self.metadata.types_representation_equivalent(left, right)
}

///|
fn ImageLowerer::runtime_type(
  _self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> RuntimeTypeClass {
  match type_ {
    Unit => Concrete(Unit)
    Erased(_, evidence) => Erased(evidence)
    _ => Concrete(type_)
  }
}
