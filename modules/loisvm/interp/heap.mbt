///|
pub enum VMValue {
  I32(Int)
  I64(Int64)
  F64(Double)
} derive(Debug, Eq)

///|
pub enum ObjectPayload {
  ByteSequence(Array[Byte])
  HostObject(@runtime.HostObjectHandle)
  Data(@bytecode.ObjectShapeId, Array[@bytecode.LayoutId], Array[VMValue])
  Environment(
    @bytecode.ObjectShapeId,
    Array[@bytecode.LayoutId],
    Array[VMValue]
  )
}

///|
pub struct HeapObject {
  mut ref_count : Int
  layout : @bytecode.LayoutId
  payload : ObjectPayload
  size : Int64
  immortal : Bool
}

///|
pub struct Heap {
  image : @bytecode.BytecodeImage
  priv runtime : @runtime.ExecutionRuntime
  objects : Array[HeapObject?]
  constant_refs : Array[Int]
  singleton_refs : Array[Int?]
  mut live_bytes : Int64
  max_live_bytes : Int?
}

///|
priv struct HeapAllocationReservation {
  layout : @bytecode.LayoutId
  size : Int64
}

///|
priv struct ByteSequenceAllocationReservation {
  allocation : HeapAllocationReservation
  length : Int
}

///|
fn Heap::new(
  image : @bytecode.BytecodeImage,
  runtime : @runtime.ExecutionRuntime,
  max_live_bytes : Int?,
) -> Heap {
  let objects : Array[HeapObject?] = [None]
  let constant_refs : Array[Int] = []
  let byte_sequence_layout = find_byte_sequence_layout(image.layouts)
  let layout : @bytecode.LayoutId = {
    value: match byte_sequence_layout {
      Some(index) => index + 1
      None => 0
    },
  }
  for bytes in image.constants {
    let reference = objects.length()
    objects.push(
      Some({
        ref_count: 0,
        layout,
        payload: ByteSequence(bytes.to_array()),
        size: host_byte_sequence_allocation_size(bytes.length()),
        immortal: true,
      }),
    )
    constant_refs.push(reference)
  }
  let singleton_refs : Array[Int?] = []
  for shape_index, shape in image.object_shapes {
    let layout_index = find_shape_layout(image.layouts, shape_index, data=true)
    if shape is Data(data) &&
      data.stored_witness_count == 0 &&
      data.members.is_empty() &&
      layout_index is Some(index) {
      let reference = objects.length()
      let layout : @bytecode.LayoutId = { value: index + 1 }
      objects.push(
        Some({
          ref_count: 0,
          layout,
          payload: Data({ value: shape_index }, [], []),
          size: object_allocation_size(shape),
          immortal: true,
        }),
      )
      singleton_refs.push(Some(reference))
    } else {
      singleton_refs.push(None)
    }
  }
  {
    image,
    runtime,
    objects,
    constant_refs,
    singleton_refs,
    live_bytes: 0,
    max_live_bytes,
  }
}

///|
fn Heap::constant_reference(self : Heap, id : @bytecode.ConstantId) -> Int {
  self.constant_refs[id.value]
}

///|
fn Heap::allocate_host_object(
  self : Heap,
  handle : @runtime.HostObjectHandle,
) -> Int raise ExecutionFailure {
  self.allocate(
    layout=self.reference_layout(),
    payload=HostObject(handle),
    size=host_object_allocation_size(),
  )
}

///|
fn Heap::allocate_byte_sequence(
  self : Heap,
  bytes : Bytes,
) -> Int raise ExecutionFailure {
  let reservation = self.reserve_byte_sequence_allocation(
    bytes.length().to_int64(),
  )
  self.publish_allocation(
    reservation.allocation,
    ByteSequence(bytes.to_array()),
  )
}

///|
fn Heap::allocate_filled_byte_sequence(
  self : Heap,
  length : Int64,
  fill : Byte,
) -> Int raise ExecutionFailure {
  let reservation = self.reserve_byte_sequence_allocation(length)
  let bytes = Array::make(reservation.length, fill)
  self.publish_allocation(reservation.allocation, ByteSequence(bytes))
}

///|
fn Heap::allocate_updated_byte_sequence(
  self : Heap,
  source : Array[Byte],
  index : Int,
  value : Byte,
) -> Int raise ExecutionFailure {
  let reservation = self.reserve_byte_sequence_allocation(
    source.length().to_int64(),
  )
  let bytes = source.copy()
  bytes[index] = value
  self.publish_allocation(reservation.allocation, ByteSequence(bytes))
}

///|
fn Heap::allocate_concatenated_byte_sequence(
  self : Heap,
  left : Array[Byte],
  right : Array[Byte],
) -> Int raise ExecutionFailure {
  let left_length = left.length().to_int64()
  let right_length = right.length().to_int64()
  let combined_length = left_length + right_length
  if combined_length < left_length {
    raise Trap(detail="ByteSequence length is out of range")
  }
  let reservation = self.reserve_byte_sequence_allocation(combined_length)
  let bytes = left.copy()
  bytes.append(right)
  self.publish_allocation(reservation.allocation, ByteSequence(bytes))
}

///|
fn Heap::allocate_sliced_byte_sequence(
  self : Heap,
  source : Array[Byte],
  start : Int,
  length : Int,
) -> Int raise ExecutionFailure {
  let reservation = self.reserve_byte_sequence_allocation(length.to_int64())
  let bytes = source[start:start + length].to_owned()
  self.publish_allocation(reservation.allocation, ByteSequence(bytes))
}

///|
fn Heap::reserve_byte_sequence_allocation(
  self : Heap,
  length : Int64,
) -> ByteSequenceAllocationReservation raise ExecutionFailure {
  let size = match checked_byte_sequence_allocation_size(length) {
    Some(size) => size
    None => raise Trap(detail="ByteSequence length is out of range")
  }
  let allocation = self.reserve_allocation(self.byte_sequence_layout(), size)
  let host_length = length.to_int()
  if host_length < 0 || host_length.to_int64() != length {
    raise Trap(detail="ByteSequence length is out of range")
  }
  { allocation, length: host_length }
}

///|
fn Heap::allocate_data(
  self : Heap,
  layout : @bytecode.LayoutId,
  shape : @bytecode.ObjectShapeId,
  witnesses : Array[@bytecode.LayoutId],
  fields : Array[VMValue],
) -> Int raise ExecutionFailure {
  if witnesses.is_empty() &&
    fields.is_empty() &&
    self.singleton_refs[shape.value] is Some(reference) &&
    self.object(reference).layout == layout {
    return reference
  }
  let size = object_allocation_size(self.image.object_shapes[shape.value])
  self.allocate(layout~, payload=Data(shape, witnesses, fields), size~)
}

///|
fn Heap::allocate_environment(
  self : Heap,
  layout : @bytecode.LayoutId,
  shape : @bytecode.ObjectShapeId,
  witnesses : Array[@bytecode.LayoutId],
  captures : Array[VMValue],
) -> Int raise ExecutionFailure {
  let size = object_allocation_size(self.image.object_shapes[shape.value])
  self.allocate(layout~, payload=Environment(shape, witnesses, captures), size~)
}

///|
fn Heap::allocate(
  self : Heap,
  layout~ : @bytecode.LayoutId,
  payload~ : ObjectPayload,
  size~ : Int64,
) -> Int raise ExecutionFailure {
  let reservation = self.reserve_allocation(layout, size)
  self.publish_allocation(reservation, payload)
}

///|
fn Heap::reserve_allocation(
  self : Heap,
  layout : @bytecode.LayoutId,
  size : Int64,
) -> HeapAllocationReservation raise ExecutionFailure {
  self.check_allocation_capacity(size)
  { layout, size }
}

///|
fn Heap::check_allocation_capacity(
  self : Heap,
  size : Int64,
) -> Unit raise ExecutionFailure {
  if self.max_live_bytes is Some(maximum) {
    let maximum = maximum.to_int64()
    if maximum < size || self.live_bytes > maximum - size {
      raise ResourceLimit(LiveHeapBytes)
    }
  }
}

///|
fn Heap::publish_allocation(
  self : Heap,
  reservation : HeapAllocationReservation,
  payload : ObjectPayload,
) -> Int {
  let reference = self.objects.length()
  self.objects.push(
    Some({
      ref_count: 1,
      layout: reservation.layout,
      payload,
      size: reservation.size,
      immortal: false,
    }),
  )
  self.live_bytes += reservation.size
  reference
}

///|
fn Heap::object(
  self : Heap,
  reference : Int,
) -> HeapObject raise ExecutionFailure {
  if reference <= 0 || reference >= self.objects.length() {
    raise InternalFailure(detail="invalid object reference \{reference}")
  }
  match self.objects[reference] {
    Some(object) => object
    None =>
      raise InternalFailure(detail="use of freed object reference \{reference}")
  }
}

///|
fn Heap::borrow_host_object(
  self : Heap,
  reference : Int,
) -> @runtime.BorrowedHostObject raise ExecutionFailure {
  let handle = match self.object(reference).payload {
    HostObject(handle) => handle
    _ => raise InternalFailure(detail="object is not a Host Object")
  }
  self.runtime.resolve_host_object(handle) catch {
    InvalidHostObjectHandle(detail~) => raise InternalFailure(detail~)
    _ =>
      raise InternalFailure(detail="unexpected Host Object resolution failure")
  }
}

///|
fn Heap::byte_sequence(
  self : Heap,
  reference : Int,
) -> Array[Byte] raise ExecutionFailure {
  match self.object(reference).payload {
    ByteSequence(bytes) => bytes
    _ => raise InternalFailure(detail="object is not a ByteSequence")
  }
}

///|
fn Heap::reference_is_unique(
  self : Heap,
  reference : Int,
) -> Bool raise ExecutionFailure {
  let object = self.object(reference)
  !object.immortal && object.ref_count == 1
}

///|
fn Heap::retain_reference(
  self : Heap,
  reference : Int,
) -> Unit raise ExecutionFailure {
  if reference == 0 {
    return
  }
  let object = self.object(reference)
  if object.immortal {
    return
  }
  if object.ref_count == 0x7FFFFFFF {
    raise InternalFailure(detail="reference count overflow")
  }
  object.ref_count += 1
}

///|
fn Heap::release_reference(
  self : Heap,
  reference : Int,
) -> Unit raise ExecutionFailure {
  if reference == 0 {
    return
  }
  let object = self.object(reference)
  if object.immortal {
    return
  }
  if object.ref_count <= 0 {
    raise InternalFailure(detail="reference count underflow")
  }
  object.ref_count -= 1
  if object.ref_count == 0 {
    self.objects[reference] = None
    self.live_bytes -= object.size
    self.destroy_payload(object.payload)
  }
}

///|
fn Heap::retain_callable(
  self : Heap,
  callable : Int64,
) -> Unit raise ExecutionFailure {
  self.retain_reference(callable_environment(callable))
}

///|
fn Heap::release_callable(
  self : Heap,
  callable : Int64,
) -> Unit raise ExecutionFailure {
  self.release_reference(callable_environment(callable))
}

///|
fn Heap::retain_erased(
  self : Heap,
  payload : Int64,
  layout : @bytecode.LayoutId,
) -> Unit raise ExecutionFailure {
  match self.image.layouts[layout.value - 1] {
    Callable => self.retain_callable(payload)
    ByteSequence | Data(_) | Environment(_) | Reference =>
      self.retain_reference((payload & 0xFFFFFFFFL).to_int())
    _ => ()
  }
}

///|
fn Heap::release_erased(
  self : Heap,
  payload : Int64,
  layout : @bytecode.LayoutId,
) -> Unit raise ExecutionFailure {
  match self.image.layouts[layout.value - 1] {
    Callable => self.release_callable(payload)
    ByteSequence | Data(_) | Environment(_) | Reference =>
      self.release_reference((payload & 0xFFFFFFFFL).to_int())
    _ => ()
  }
}

///|
fn Heap::destroy_payload(
  self : Heap,
  payload : ObjectPayload,
) -> Unit raise ExecutionFailure {
  match payload {
    ByteSequence(_) => ()
    HostObject(handle) =>
      self.runtime.release_host_object(handle) catch {
        InvalidHostObjectHandle(detail~) => raise InternalFailure(detail~)
        _ =>
          raise InternalFailure(detail="unexpected Host Object release failure")
      }
    Data(shape, witnesses, fields) => {
      let schema = match self.image.object_shapes[shape.value] {
        Data(data) => data
        _ => raise InternalFailure(detail="Data object has Environment shape")
      }
      for index in 0..<fields.length() {
        self.release_member(fields[index], schema.members[index], witnesses)
      }
    }
    Environment(shape, witnesses, captures) => {
      let schema = match self.image.object_shapes[shape.value] {
        Environment(environment) => environment
        _ => raise InternalFailure(detail="Environment object has Data shape")
      }
      for index in 0..<captures.length() {
        self.release_member(captures[index], schema.members[index], witnesses)
      }
    }
  }
}

///|
fn Heap::retain_member(
  self : Heap,
  value : VMValue,
  schema : @bytecode.MemberSchema,
  witnesses : Array[@bytecode.LayoutId],
) -> Unit raise ExecutionFailure {
  match (schema.cleanup, value) {
    (Trivial, _) => ()
    (OwnedRef, I32(reference)) => self.retain_reference(reference)
    (OwnedCallable, I64(callable)) => self.retain_callable(callable)
    (OwnedErased, I64(payload)) =>
      match schema.witness_ordinal {
        Some(ordinal) => self.retain_erased(payload, witnesses[ordinal])
        None => raise InternalFailure(detail="erased member lacks witness")
      }
    _ => raise InternalFailure(detail="member cleanup representation mismatch")
  }
}

///|
fn Heap::release_member(
  self : Heap,
  value : VMValue,
  schema : @bytecode.MemberSchema,
  witnesses : Array[@bytecode.LayoutId],
) -> Unit raise ExecutionFailure {
  match (schema.cleanup, value) {
    (Trivial, _) => ()
    (OwnedRef, I32(reference)) => self.release_reference(reference)
    (OwnedCallable, I64(callable)) => self.release_callable(callable)
    (OwnedErased, I64(payload)) =>
      match schema.witness_ordinal {
        Some(ordinal) => self.release_erased(payload, witnesses[ordinal])
        None => raise InternalFailure(detail="erased member lacks witness")
      }
    _ => raise InternalFailure(detail="member cleanup representation mismatch")
  }
}

///|
fn Heap::reference_layout(
  self : Heap,
) -> @bytecode.LayoutId raise ExecutionFailure {
  for index, recipe in self.image.layouts {
    if recipe is Reference {
      return { value: index + 1 }
    }
  }
  raise InternalFailure(detail="bytecode image has no Reference layout")
}

///|
fn Heap::byte_sequence_layout(
  self : Heap,
) -> @bytecode.LayoutId raise ExecutionFailure {
  match find_byte_sequence_layout(self.image.layouts) {
    Some(index) => { value: index + 1 }
    None =>
      raise InternalFailure(detail="bytecode image has no ByteSequence layout")
  }
}

///|
fn callable(function : @bytecode.FunctionId, environment : Int) -> Int64 {
  function.value.to_int64() | (environment.to_int64() << 32)
}

///|
fn callable_function(value : Int64) -> @bytecode.FunctionId {
  { value: (value & 0xFFFFFFFFL).to_int() }
}

///|
fn callable_environment(value : Int64) -> Int {
  (value >> 32).to_int()
}

///|
fn host_object_allocation_size() -> Int64 {
  16L
}

///|
fn checked_byte_sequence_allocation_size(length : Int64) -> Int64? {
  if length < 0L {
    return None
  }
  let unaligned = length + 12L
  if unaligned < length {
    return None
  }
  let padded = unaligned + 7L
  if padded < unaligned {
    return None
  }
  Some(padded / 8L * 8L)
}

///|
fn host_byte_sequence_allocation_size(length : Int) -> Int64 {
  let unaligned = 12L + length.to_int64()
  (unaligned + 7L) / 8L * 8L
}

///|
fn object_allocation_size(shape : @bytecode.ObjectShape) -> Int64 {
  let (initial_offset, members) = match shape {
    Data(data) =>
      (12L + data.stored_witness_count.to_int64() * 4L, data.members)
    Environment(environment) =>
      (
        8L + environment.stored_witness_count.to_int64() * 4L,
        environment.members,
      )
  }
  let mut offset = initial_offset
  for schema in members {
    let (size, alignment) = match schema.representation {
      I32 => (4L, 4L)
      I64 | F64 => (8L, 8L)
    }
    offset = align_up(offset, alignment) + size
  }
  align_up(offset, 8L)
}

///|
fn find_byte_sequence_layout(layouts : Array[@bytecode.LayoutRecipe]) -> Int? {
  for index, recipe in layouts {
    if recipe is ByteSequence {
      return Some(index)
    }
  }
  None
}

///|
fn find_shape_layout(
  layouts : Array[@bytecode.LayoutRecipe],
  shape_index : Int,
  data~ : Bool,
) -> Int? {
  for index, recipe in layouts {
    match recipe {
      Data(shape) if data && shape.value == shape_index => return Some(index)
      Environment(shape) if !data && shape.value == shape_index =>
        return Some(index)
      _ => ()
    }
  }
  None
}

///|
fn align_up(value : Int64, alignment : Int64) -> Int64 {
  (value + alignment - 1) / alignment * alignment
}
