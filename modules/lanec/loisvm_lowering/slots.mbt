///|
fn FunctionLowerer::fresh_optional_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> (@vmcfg.ValueId?, LocalValue) raise LoisvmLoweringError {
  if type_ == Primitive(Unit) {
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
  if type_ is Parameter(parameter) {
    return self.fresh_erased_slot(self.find_witness(parameter), Owned)
  }
  let slot : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push(slot_metadata(type_))
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
  if type_ is Parameter(parameter) {
    return self.fresh_erased_slot(self.find_witness(parameter), Borrowed)
  }
  let metadata = slot_metadata(type_)
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
fn slot_metadata(
  type_ : @buslane.Type,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  match type_ {
    Primitive(Unit) => raise UnsupportedType(type_~)
    Primitive(Bool) =>
      {
        representation: I32,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(Int) =>
      {
        representation: I64,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(Double) =>
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
fn result_representation(
  type_ : @buslane.Type,
) -> @bytecode.ResultRepresentation raise LoisvmLoweringError {
  match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) | Primitive(String) | Constructor(_) | Apply(_, _) => I32
    Primitive(Int) | Function(_, _, _) | Forall(_, _) | Parameter(_) => I64
    Primitive(Double) => F64
    _ => raise UnsupportedType(type_~)
  }
}

///|
