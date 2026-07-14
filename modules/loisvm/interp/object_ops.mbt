///|
fn ExecutionInstance::string_concat(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let left_reference = frame.i32(left)
  let right_reference = frame.i32(right)
  let bytes = self.heap.string_bytes(left_reference).to_array()
  for byte in self.heap.string_bytes(right_reference) {
    bytes.push(byte)
  }
  let result = self.heap.allocate_string(Bytes::from_array(bytes))
  frame.consume_owner(left)
  frame.consume_owner(right)
  self.heap.release_reference(left_reference)
  self.heap.release_reference(right_reference)
  frame.write(destination, I32(result))
}

///|
fn ExecutionInstance::string_slice(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  start : @bytecode.SlotId,
  length : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let reference = frame.i32(source)
  let start_value = frame.i64(start)
  let length_value = frame.i64(length)
  let bytes = self.heap.string_bytes(reference)
  if start_value < 0L ||
    length_value < 0L ||
    start_value > bytes.length().to_int64() ||
    length_value > bytes.length().to_int64() - start_value {
    raise InternalFailure(detail="String slice is out of bounds")
  }
  let first = start_value.to_int()
  let last = first + length_value.to_int()
  let result = self.heap.allocate_string(bytes[first:last].to_owned())
  frame.consume_owner(source)
  self.heap.release_reference(reference)
  frame.write(destination, I32(result))
}

///|
fn ExecutionInstance::resolve_layout_operand(
  self : ExecutionInstance,
  frame : Frame,
  operand : @bytecode.LayoutOperand,
) -> @bytecode.LayoutId raise ExecutionFailure {
  ignore(self)
  match operand {
    Immediate(layout) => layout
    Witness(slot) => { value: frame.i32(slot) }
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
  match object.payload {
    Data(shape, witnesses, _) if shape == expected_shape =>
      match self.loaded.image.object_shapes[shape.value] {
        Data(_) => frame.write(destination, I32(witnesses[ordinal].value))
        _ => raise InternalFailure(detail="Data object has Environment shape")
      }
    Environment(shape, witnesses, _) if shape == expected_shape =>
      match self.loaded.image.object_shapes[shape.value] {
        Environment(_) =>
          frame.write(destination, I32(witnesses[ordinal].value))
        _ => raise InternalFailure(detail="Environment object has Data shape")
      }
    _ => raise InternalFailure(detail="object witness shape mismatch")
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
  match object.payload {
    Data(shape, witnesses, values) if !environment && shape == expected_shape => {
      let schemas = match self.loaded.image.object_shapes[shape.value] {
        Data(data) => data.members
        _ => raise InternalFailure(detail="Data object has wrong shape variant")
      }
      (values, witnesses, schemas)
    }
    Environment(shape, witnesses, values) if environment &&
      shape == expected_shape => {
      let schemas = match self.loaded.image.object_shapes[shape.value] {
        Environment(environment) => environment.members
        _ =>
          raise InternalFailure(
            detail="Environment object has wrong shape variant",
          )
      }
      (values, witnesses, schemas)
    }
    _ => raise InternalFailure(detail="object projection shape mismatch")
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
