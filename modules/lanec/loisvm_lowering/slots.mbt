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
  if self.image.runtime_type(type_) is Erased(parameter) {
    return self.fresh_erased_slot(self.find_witness(parameter), Owned)
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
  if self.image.runtime_type(type_) is Erased(parameter) {
    return self.fresh_erased_slot(self.find_witness(parameter), Borrowed)
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
    ownership,
    erased_companion: Some(witness),
  })
}

///|
fn ImageLowerer::slot_metadata(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  guard self.runtime_type(type_) is Concrete(type_) else {
    raise UnsupportedType(type_~)
  }
  match type_ {
    Primitive(Unit) => raise UnsupportedType(type_~)
    Primitive(Bool) =>
      {
        representation: I32,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(I32) | Primitive(Char) =>
      {
        representation: I32,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(I64) =>
      {
        representation: I64,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(F32) =>
      {
        representation: F32,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(F64) =>
      {
        representation: F64,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(String) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        ownership: Owned,
        erased_companion: None,
      }
    Primitive(Byte) =>
      {
        representation: I32,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(Bytes) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        ownership: Owned,
        erased_companion: None,
      }
    Function(_, _, _) | Forall(_, _) =>
      {
        representation: I64,
        cleanup: OwnedCallable,
        ownership: Owned,
        erased_companion: None,
      }
    Constructor(_) | Apply(_, _) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        ownership: Owned,
        erased_companion: None,
      }
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn environment_metadata() -> @vmcfg.ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn layout_witness_metadata() -> @vmcfg.ValueMetadata {
  {
    representation: I32,
    cleanup: Trivial,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
fn ImageLowerer::result_representation(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> @bytecode.ResultRepresentation raise LoisvmLoweringError {
  match self.runtime_type(type_) {
    Erased(_) => I64
    Concrete(type_) =>
      match type_ {
        Primitive(Unit) => Unit
        Primitive(Bool)
        | Primitive(I32)
        | Primitive(Char)
        | Primitive(String)
        | Primitive(Byte)
        | Primitive(Bytes)
        | Constructor(_)
        | Apply(_, _) => I32
        Primitive(I64) | Function(_, _, _) | Forall(_, _) => I64
        Primitive(F32) => F32
        Primitive(F64) => F64
        _ => raise UnsupportedType(type_~)
      }
  }
}

///|
priv enum RuntimeType {
  Erased(@buslane.TypeParameterId)
  Concrete(@buslane.Type)
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
) -> RuntimeType {
  let type_ = normalize_runtime_type(type_)
  match type_ {
    Parameter(parameter) if parameter.index < 0 => Erased(parameter)
    Parameter(parameter) =>
      match self.metadata.type_parameter_info(parameter) {
        Some({ kind: Type, .. }) => Erased(parameter)
        _ => Concrete(type_)
      }
    Apply(Parameter(companion), _) if self.effect_source(companion) is Some(_) =>
      Erased(companion)
    _ => Concrete(type_)
  }
}

///|
fn ImageLowerer::layout_runtime_type(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> RuntimeType {
  match normalize_runtime_type(type_) {
    Parameter(companion) if self.effect_source(companion) is Some(_) =>
      Erased(companion)
    TypeLambda(_, body) => self.layout_runtime_type(body)
    type_ => self.runtime_type(type_)
  }
}

///|
fn normalize_runtime_type(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Apply(callee, arguments) => {
      let callee = normalize_runtime_type(callee)
      match callee {
        TypeLambda(parameters, body) if parameters.length() ==
          arguments.length() => {
          let substitution = @buslane.TypeSubstitution::TypeSubstitution()
          for index, parameter in parameters {
            substitution.insert_argument(parameter, arguments[index])
          }
          normalize_runtime_type(body.substitute(substitution))
        }
        _ => Apply(callee, arguments)
      }
    }
    _ => type_
  }
}

///|
