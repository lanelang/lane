///|
pub enum VMValue {
  I32(Int)
  I64(Int64)
  F64(Double)
} derive(Debug, Eq)

///|
pub enum ObjectPayload {
  String(Bytes)
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
  size : Int
  immortal : Bool
}

///|
pub struct Heap {
  image : @bytecode.BytecodeImage
  priv runtime : @runtime.ExecutionRuntime
  objects : Array[HeapObject?]
  constant_refs : Array[Int]
  singleton_refs : Array[Int?]
  mut live_bytes : Int
  max_live_bytes : Int?
}

///|
fn Heap::new(
  image : @bytecode.BytecodeImage,
  runtime : @runtime.ExecutionRuntime,
  max_live_bytes : Int?,
) -> Heap {
  let objects : Array[HeapObject?] = [None]
  let constant_refs : Array[Int] = []
  let string_layout = find_string_layout(image.layouts)
  let layout : @bytecode.LayoutId = {
    value: match string_layout {
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
        payload: String(bytes),
        size: string_allocation_size(bytes.length()),
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
fn Heap::allocate_string(
  self : Heap,
  bytes : Bytes,
) -> Int raise ExecutionFailure {
  self.allocate(
    layout=self.string_layout(),
    payload=String(bytes),
    size=string_allocation_size(bytes.length()),
  )
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
  size~ : Int,
) -> Int raise ExecutionFailure {
  if self.max_live_bytes is Some(maximum) &&
    (maximum < size || self.live_bytes > maximum - size) {
    raise ResourceLimit(LiveHeapBytes)
  }
  let reference = self.objects.length()
  self.objects.push(
    Some({ ref_count: 1, layout, payload, size, immortal: false }),
  )
  self.live_bytes += size
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
fn Heap::string_bytes(
  self : Heap,
  reference : Int,
) -> Bytes raise ExecutionFailure {
  match self.object(reference).payload {
    String(bytes) => bytes
    _ => raise InternalFailure(detail="object is not a String")
  }
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
    String | Data(_) | Environment(_) | Reference =>
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
    String | Data(_) | Environment(_) | Reference =>
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
    String(_) => ()
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
fn Heap::string_layout(
  self : Heap,
) -> @bytecode.LayoutId raise ExecutionFailure {
  match find_string_layout(self.image.layouts) {
    Some(index) => { value: index + 1 }
    None => raise InternalFailure(detail="bytecode image has no String layout")
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
fn host_object_allocation_size() -> Int {
  16
}

///|
fn string_allocation_size(length : Int) -> Int {
  align_up(12 + length, 8)
}

///|
fn object_allocation_size(shape : @bytecode.ObjectShape) -> Int {
  let (initial_offset, members) = match shape {
    Data(data) => (12 + data.stored_witness_count * 4, data.members)
    Environment(environment) =>
      (8 + environment.stored_witness_count * 4, environment.members)
  }
  let mut offset = initial_offset
  for schema in members {
    let (size, alignment) = match schema.representation {
      I32 => (4, 4)
      I64 | F64 => (8, 8)
    }
    offset = align_up(offset, alignment) + size
  }
  align_up(offset, 8)
}

///|
fn find_string_layout(layouts : Array[@bytecode.LayoutRecipe]) -> Int? {
  for index, recipe in layouts {
    if recipe is String {
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
fn align_up(value : Int, alignment : Int) -> Int {
  (value + alignment - 1) / alignment * alignment
}
