///|
fn ExecutionInstance::byte_sequence_make(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  length : @bytecode.SlotId,
  fill : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let fill = frame.i32(fill).to_byte()
  let reference = self.heap.allocate_filled_byte_sequence(
    frame.i64(length),
    fill,
  )
  frame.write(destination, I32(reference))
}

///|
fn ExecutionInstance::byte_sequence_length(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let length = self.heap.byte_sequence(frame.i32(source)).length()
  frame.write(destination, I64(length.to_int64()))
}

///|
fn checked_byte_sequence_index(
  bytes : Array[Byte],
  index : Int64,
) -> Int raise ExecutionFailure {
  if index < 0L || index >= bytes.length().to_int64() {
    raise Trap(detail="ByteSequence index is out of bounds")
  }
  index.to_int()
}

///|
fn ExecutionInstance::byte_sequence_get(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  index : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let bytes = self.heap.byte_sequence(frame.i32(source))
  let value = bytes[checked_byte_sequence_index(bytes, frame.i64(index))].to_int()
  frame.write(destination, I32(value))
}

///|
fn ExecutionInstance::byte_sequence_set(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  index : @bytecode.SlotId,
  value : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let reference = frame.i32(source)
  let bytes = self.heap.byte_sequence(reference)
  let index = checked_byte_sequence_index(bytes, frame.i64(index))
  let value = frame.i32(value).to_byte()
  let result = if self.heap.reference_is_unique(reference) {
    bytes[index] = value
    reference
  } else {
    let result = self.heap.allocate_updated_byte_sequence(bytes, index, value)
    self.heap.release_reference(reference)
    result
  }
  frame.consume_owner(source)
  frame.write(destination, I32(result))
}

///|
fn ExecutionInstance::byte_sequence_equal(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let equal = self.heap.byte_sequence(frame.i32(left)) ==
    self.heap.byte_sequence(frame.i32(right))
  frame.write(destination, I32(if equal { 1 } else { 0 }))
}

///|
fn ExecutionInstance::byte_sequence_concat(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let left_reference = frame.i32(left)
  let right_reference = frame.i32(right)
  let result = self.heap.allocate_concatenated_byte_sequence(
    self.heap.byte_sequence(left_reference),
    self.heap.byte_sequence(right_reference),
  )
  frame.consume_owner(left)
  frame.consume_owner(right)
  self.heap.release_reference(left_reference)
  self.heap.release_reference(right_reference)
  frame.write(destination, I32(result))
}

///|
fn ExecutionInstance::byte_sequence_slice(
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
  let bytes = self.heap.byte_sequence(reference)
  if start_value < 0L ||
    length_value < 0L ||
    start_value > bytes.length().to_int64() ||
    length_value > bytes.length().to_int64() - start_value {
    raise Trap(detail="ByteSequence slice is out of bounds")
  }
  let result = self.heap.allocate_sliced_byte_sequence(
    bytes,
    start_value.to_int(),
    length_value.to_int(),
  )
  frame.consume_owner(source)
  self.heap.release_reference(reference)
  frame.write(destination, I32(result))
}

///|
fn ExecutionInstance::byte_sequence_is_valid_utf8(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let valid = byte_sequence_is_valid_utf8(
    self.heap.byte_sequence(frame.i32(source)),
  )
  frame.write(destination, I32(if valid { 1 } else { 0 }))
}

///|
fn byte_sequence_is_valid_utf8(bytes : Array[Byte]) -> Bool {
  let mut index = 0
  while index < bytes.length() {
    let first = bytes[index].to_int()
    if first <= 0x7F {
      index += 1
    } else if first >= 0xC2 && first <= 0xDF {
      if !has_utf8_continuations(bytes, index, 1) {
        return false
      }
      index += 2
    } else if first >= 0xE0 && first <= 0xEF {
      if !has_utf8_continuations(bytes, index, 2) {
        return false
      }
      let second = bytes[index + 1].to_int()
      if (first == 0xE0 && second < 0xA0) || (first == 0xED && second > 0x9F) {
        return false
      }
      index += 3
    } else if first >= 0xF0 && first <= 0xF4 {
      if !has_utf8_continuations(bytes, index, 3) {
        return false
      }
      let second = bytes[index + 1].to_int()
      if (first == 0xF0 && second < 0x90) || (first == 0xF4 && second > 0x8F) {
        return false
      }
      index += 4
    } else {
      return false
    }
  }
  true
}

///|
fn has_utf8_continuations(
  bytes : Array[Byte],
  start : Int,
  count : Int,
) -> Bool {
  if start + count >= bytes.length() {
    return false
  }
  for offset in 1..<=count {
    let byte = bytes[start + offset].to_int()
    if byte < 0x80 || byte > 0xBF {
      return false
    }
  }
  true
}
