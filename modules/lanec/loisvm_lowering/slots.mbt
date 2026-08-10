///|
fn FunctionLowerer::fresh_optional_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> (@vmcfg.ValueId?, LocalValue) raise LoisvmLoweringError {
  if self.image.runtime_type(type_) is Concrete(Primitive(Unit)) {
    (None, Unit)
  } else {
    let slot = self.fresh_slot(type_)
    (Some(slot), Slot(slot, type_))
  }
}

///|
fn FunctionLowerer::fresh_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if self.image.runtime_type(type_) is Erased(_) {
    return self.fresh_erased_slot(self.layout_witness(type_), Owned)
  }
  let slot : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push(self.image.slot_metadata(type_))
  slot
}

///|
fn FunctionLowerer::fresh_metadata(
  self : FunctionLowerer,
  metadata : @vmcfg.ValueMetadata,
) -> @vmcfg.ValueId {
  let value : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push(metadata)
  value
}

///|
fn FunctionLowerer::fresh_borrowed_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if self.image.runtime_type(type_) is Erased(_) {
    return self.fresh_erased_slot(self.layout_witness(type_), Borrowed)
  }
  let metadata = self.image.slot_metadata(type_)
  let ownership : @vmcfg.Ownership = match metadata.ownership {
    Trivial => Trivial
    Owned | Borrowed => Borrowed
  }
  let slot : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push({ ..metadata, ownership, })
  slot
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
fn ImageLowerer::slot_metadata(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    Concrete(_, metadata) => metadata
    Unit | Erased(_) => raise UnsupportedType(type_~)
  }
}

///|
fn ImageLowerer::elaborate_runtime_representation(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> RuntimeRepresentation raise LoisvmLoweringError {
  let type_ = type_.normalize() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
  match type_ {
    Parameter(parameter) if parameter.index < 0 => return Erased(type_)
    Parameter(parameter) =>
      if self.metadata.type_parameter_info(parameter)
        is Some({ kind: Type, .. }) {
        return Erased(type_)
      }
    Apply(Parameter(parameter), _) =>
      if self.metadata.type_parameter_info(parameter)
        is Some({ kind: Function(_, Type), .. }) {
        return Erased(type_)
      }
    _ => ()
  }
  if type_ is Primitive(Unit) {
    return Unit
  }
  let metadata : @vmcfg.ValueMetadata = match type_ {
    Primitive(Bool) =>
      {
        representation: I32,
        cleanup: Trivial,
        kind: ScalarValue,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(I32) | Primitive(Char) =>
      {
        representation: I32,
        cleanup: Trivial,
        kind: ScalarValue,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(I64) =>
      {
        representation: I64,
        cleanup: Trivial,
        kind: ScalarValue,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(F32) =>
      {
        representation: F32,
        cleanup: Trivial,
        kind: ScalarValue,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(F64) =>
      {
        representation: F64,
        cleanup: Trivial,
        kind: ScalarValue,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(String) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        ownership: Owned,
        erased_companion: None,
      }
    Primitive(Byte) =>
      {
        representation: I32,
        cleanup: Trivial,
        kind: ScalarValue,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(Bytes) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        ownership: Owned,
        erased_companion: None,
      }
    Function(_, _, _) | Forall(_, _) =>
      {
        representation: I64,
        cleanup: OwnedCallable,
        kind: CallableValue,
        ownership: Owned,
        erased_companion: None,
      }
    Constructor(owner) | Apply(Constructor(owner), _) => {
      let kind : @bytecode.SemanticValueKind = match
        self.metadata.type_info(owner) {
        Some({ flavor: Data, .. }) => DataValue(self.intern_data_family(owner))
        Some({ flavor: External, .. }) => OpaqueReferenceValue
        None => raise UnsupportedType(type_~)
      }
      {
        representation: I32,
        cleanup: OwnedRef,
        kind,
        ownership: Owned,
        erased_companion: None,
      }
    }
    Apply(_, _) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: OpaqueReferenceValue,
        ownership: Owned,
        erased_companion: None,
      }
    _ => raise UnsupportedType(type_~)
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
    { ..metadata, ownership: Borrowed }
  }
}

///|
fn ImageLowerer::runtime_evidence_metadata(
  self : ImageLowerer,
  parameter : @buslane.TypeParameterId,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  let kind = match self.metadata.type_parameter_info(parameter) {
    Some(info) => info.kind
    None if parameter.index < 0 => @buslane.Kind::Type
    None => raise UnsupportedType(type_=Parameter(parameter))
  }
  match kind {
    Type => layout_witness_metadata()
    Function(parameters, Type) =>
      layout_constructor_metadata(runtime_evidence_arity(parameters))
    _ => raise UnsupportedType(type_=Parameter(parameter))
  }
}

///|
fn runtime_evidence_arity(parameters : Array[@buslane.Kind]) -> Int {
  parameters.fold(init=0, fn(count, kind) {
    if kind_requires_runtime_evidence(kind) {
      count + 1
    } else {
      count
    }
  })
}

///|
fn kind_requires_runtime_evidence(kind : @buslane.Kind) -> Bool {
  match kind {
    Type | Function(_, Type) => true
    _ => false
  }
}

///|
fn ImageLowerer::result_abi(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> @bytecode.ResultAbi raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    Unit => Unit
    Erased(_) => Value(I64, OwnedErased, ErasedValue)
    Concrete(_, metadata) =>
      Value(metadata.representation, metadata.cleanup, metadata.kind)
  }
}

///|
priv enum RuntimeRepresentation {
  Unit
  Concrete(@buslane.Type, @vmcfg.ValueMetadata)
  Erased(@buslane.Type)
}

///|
priv enum RuntimeType {
  Erased(@buslane.Type)
  Concrete(@buslane.Type)
}

///|
fn ImageLowerer::types_definitionally_equal(
  self : ImageLowerer,
  left : @buslane.Type,
  right : @buslane.Type,
) -> Bool raise LoisvmLoweringError {
  self.metadata.types_definitionally_equal(left, right) catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
}

///|
/// Resolve the runtime representation of a value type.
///
/// Ordinary `Type` parameters and applied effect companions are erased. A
/// concrete companion argument beta-reduces before its representation is
/// classified, so `Apply(TypeLambda(...), ...)` uses the lambda body's layout.
fn ImageLowerer::runtime_type(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> RuntimeType raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    Unit => Concrete(Primitive(Unit))
    Concrete(type_, _) => Concrete(type_)
    Erased(type_) => Erased(type_)
  }
}

///|
fn ImageLowerer::layout_runtime_type(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> RuntimeType raise LoisvmLoweringError {
  let type_ = type_.normalize() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
  match type_ {
    TypeLambda(_, body) => self.layout_runtime_type(body)
    type_ => self.runtime_type(type_)
  }
}

///|
