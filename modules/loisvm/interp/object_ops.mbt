///|
fn ExecutionInstance::resolve_layout_operand(
  self : ExecutionInstance,
  frame : Frame,
  operand : @bytecode.LayoutOperand,
) -> @bytecode.LayoutId raise ExecutionFailure {
  ignore(self)
  match operand {
    Immediate(layout) => layout
    Witness(slot) => { value: frame.i32(slot), }
  }
}

///|
fn ExecutionInstance::validate_unerased_object_shape(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  guard @bytecode.statically_known_object_shape(
      self.loaded.image.object_shapes,
      frame.body.slots[destination.value].kind,
    )
    is Some(expected) else {
    return
  }
  let reference = (frame.i64(source) & 0xFFFFFFFFL).to_int()
  let actual = match self.heap.object(reference).payload {
    Data(shape, _, _) => shape
    Environment(shape, _, _) => shape
    _ => raise Trap(detail="unerased object shape mismatch")
  }
  if actual != expected {
    raise Trap(detail="unerased object shape mismatch")
  }
}

///|
fn ExecutionInstance::make_data(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  shape : @bytecode.ObjectShapeId,
  layout : @bytecode.LayoutOperand,
  witnesses : Array[@bytecode.SlotId],
  fields : Array[@bytecode.SlotId],
) -> Unit raise ExecutionFailure {
  let witness_values = witnesses.map(slot => @bytecode.LayoutId::{
    value: frame.i32(slot),
  })
  let field_values = frame.read_values(fields, consume=false)
  let reference = self.heap.allocate_data(
    self.resolve_layout_operand(frame, layout),
    shape,
    witness_values,
    field_values,
  )
  for slot in fields {
    frame.consume_owner(slot)
  }
  frame.write(destination, I32(reference))
}

///|
fn ExecutionInstance::make_environment(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  shape : @bytecode.ObjectShapeId,
  layout : @bytecode.LayoutOperand,
  witnesses : Array[@bytecode.SlotId],
  captures : Array[@bytecode.SlotId],
) -> Unit raise ExecutionFailure {
  let witness_values = witnesses.map(slot => @bytecode.LayoutId::{
    value: frame.i32(slot),
  })
  let capture_values = frame.read_values(captures, consume=false)
  let reference = self.heap.allocate_environment(
    self.resolve_layout_operand(frame, layout),
    shape,
    witness_values,
    capture_values,
  )
  for slot in captures {
    frame.consume_owner(slot)
  }
  frame.write(destination, I32(reference))
}

///|
fn ExecutionInstance::borrow_member(
  self : ExecutionInstance,
  frame : Frame,
  shape : @bytecode.ObjectShapeId,
  source : @bytecode.SlotId,
  index : Int,
  result : @bytecode.ProjectionResult,
  environment~ : Bool,
) -> Unit raise ExecutionFailure {
  let object = self.heap.object(frame.i32(source))
  let (values, witnesses, schemas) = self.object_members(
    object,
    shape,
    environment~,
  )
  frame.write_borrowed(result.value_destination, values[index])
  self.write_projection_witness(frame, result, schemas[index], witnesses)
}

///|
fn ExecutionInstance::load_object_witness(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  expected_shape : @bytecode.ObjectShapeId,
  source : @bytecode.SlotId,
  ordinal : Int,
) -> Unit raise ExecutionFailure {
  let object = self.heap.object(frame.i32(source))
  match
    (self.loaded.image.object_shapes[expected_shape.value], object.payload) {
    (Data(_), Data(_, witnesses, _)) =>
      frame.write(destination, I32(witnesses[ordinal].value))
    (Environment(_), Environment(_, witnesses, _)) =>
      frame.write(destination, I32(witnesses[ordinal].value))
    _ => raise InternalFailure(detail="object witness shape kind mismatch")
  }
}

///|
fn ExecutionInstance::consume_members(
  self : ExecutionInstance,
  frame : Frame,
  shape : @bytecode.ObjectShapeId,
  source : @bytecode.SlotId,
  selections : Array[@bytecode.ProjectionSelection],
  environment~ : Bool,
) -> Unit raise ExecutionFailure {
  let reference = frame.i32(source)
  let object = self.heap.object(reference)
  let (values, witnesses, schemas) = self.object_members(
    object,
    shape,
    environment~,
  )
  for selection in selections {
    let index = selection.member_index
    self.heap.retain_member(values[index], schemas[index], witnesses)
  }
  frame.consume_owner(source)
  self.heap.release_reference(reference)
  for selection in selections {
    let index = selection.member_index
    frame.write(selection.result.value_destination, values[index])
    self.write_projection_witness(
      frame,
      selection.result,
      schemas[index],
      witnesses,
    )
  }
}

///|
fn ExecutionInstance::object_members(
  self : ExecutionInstance,
  object : HeapObject,
  expected_shape : @bytecode.ObjectShapeId,
  environment~ : Bool,
) -> (Array[VMValue], Array[@bytecode.LayoutId], Array[@bytecode.MemberSchema]) raise ExecutionFailure {
  match
    (self.loaded.image.object_shapes[expected_shape.value], object.payload) {
    (Data(data), Data(_, witnesses, values)) if !environment =>
      (values, witnesses, data.members)
    (Environment(schema), Environment(_, witnesses, values)) if environment =>
      (values, witnesses, schema.members)
    _ => raise InternalFailure(detail="object projection shape kind mismatch")
  }
}

///|
fn ExecutionInstance::write_projection_witness(
  self : ExecutionInstance,
  frame : Frame,
  result : @bytecode.ProjectionResult,
  schema : @bytecode.MemberSchema,
  witnesses : Array[@bytecode.LayoutId],
) -> Unit {
  ignore(self)
  if result.witness_destination is Some(destination) &&
    schema.witness_ordinal is Some(ordinal) {
    frame.write(destination, I32(witnesses[ordinal].value))
  }
}
