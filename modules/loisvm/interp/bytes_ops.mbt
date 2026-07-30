///|
fn ExecutionInstance::bytes_make(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  length : @bytecode.SlotId,
  fill : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let fill = frame.i32(fill).to_byte()
  let reference = self.heap.allocate_filled_bytes(frame.i64(length), fill)
  frame.write(destination, I32(reference))
}

///|
fn ExecutionInstance::bytes_length(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let length = self.heap.bytes_array(frame.i32(source)).length()
  frame.write(destination, I64(length.to_int64()))
}

///|
fn checked_bytes_index(
  bytes : Array[Byte],
  index : Int64,
) -> Int raise ExecutionFailure {
  if index < 0L || index >= bytes.length().to_int64() {
    raise Trap(detail="Bytes index is out of bounds")
  }
  index.to_int()
}

///|
fn ExecutionInstance::bytes_get(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  index : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let bytes = self.heap.bytes_array(frame.i32(source))
  let value = bytes[checked_bytes_index(bytes, frame.i64(index))].to_int()
  frame.write(destination, I32(value))
}

///|
fn ExecutionInstance::bytes_set(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  index : @bytecode.SlotId,
  value : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let reference = frame.i32(source)
  let bytes = self.heap.bytes_array(reference)
  let index = checked_bytes_index(bytes, frame.i64(index))
  let value = frame.i32(value).to_byte()
  let result = if self.heap.reference_is_unique(reference) {
    bytes[index] = value
    reference
  } else {
    let result = self.heap.allocate_updated_bytes(bytes, index, value)
    self.heap.release_reference(reference)
    result
  }
  frame.consume_owner(source)
  frame.write(destination, I32(result))
}
