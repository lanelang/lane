///|
fn make_frame(
  body : @bytecode.FunctionBody,
  environment : VMValue?,
  witnesses : Array[VMValue],
  arguments : Array[VMValue],
  return_destination : @bytecode.SlotId?,
) -> Frame {
  let slots : Array[VMValue?] = []
  let owned_live : Array[Bool] = []
  for _index in 0..<body.slots.length() {
    slots.push(None)
    owned_live.push(false)
  }
  let frame = Frame::{
    body,
    slots,
    owned_live,
    block: 0,
    instruction: 0,
    return_destination,
  }
  if body.inputs.environment is Some(destination) && environment is Some(value) {
    frame.write(destination, value)
  }
  for index in 0..<witnesses.length() {
    frame.write(body.inputs.witnesses[index], witnesses[index])
  }
  for index in 0..<arguments.length() {
    frame.write(body.inputs.user_parameters[index], arguments[index])
  }
  frame
}

///|
fn Frame::value(
  self : Frame,
  slot : @bytecode.SlotId,
) -> VMValue raise ExecutionFailure {
  match self.slots[slot.value] {
    Some(value) => value
    None =>
      raise InternalFailure(
        detail="read from uninitialized SlotId \{slot.value}",
      )
  }
}

///|
fn Frame::write(self : Frame, slot : @bytecode.SlotId, value : VMValue) -> Unit {
  self.slots[slot.value] = Some(value)
  self.owned_live[slot.value] = self.body.slots[slot.value].cleanup != Trivial
}

///|
fn Frame::write_borrowed(
  self : Frame,
  slot : @bytecode.SlotId,
  value : VMValue,
) -> Unit {
  self.slots[slot.value] = Some(value)
  self.owned_live[slot.value] = false
}

///|
fn Frame::consume_owner(self : Frame, slot : @bytecode.SlotId) -> Unit {
  if self.body.slots[slot.value].cleanup != Trivial {
    self.owned_live[slot.value] = false
  }
}

///|
fn Frame::transfer(
  self : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  self.transfer_value(destination, source, self.value(source))
}

///|
fn Frame::transfer_value(
  self : Frame,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  value : VMValue,
) -> Unit {
  self.consume_owner(source)
  self.write(destination, value)
}

///|
fn Frame::i32(
  self : Frame,
  slot : @bytecode.SlotId,
) -> Int raise ExecutionFailure {
  match self.value(slot) {
    I32(value) => value
    _ => raise InternalFailure(detail="expected I32 slot")
  }
}

///|
fn Frame::i64(
  self : Frame,
  slot : @bytecode.SlotId,
) -> Int64 raise ExecutionFailure {
  match self.value(slot) {
    I64(value) => value
    _ => raise InternalFailure(detail="expected I64 slot")
  }
}

///|
fn Frame::f64(
  self : Frame,
  slot : @bytecode.SlotId,
) -> Double raise ExecutionFailure {
  match self.value(slot) {
    F64(value) => value
    _ => raise InternalFailure(detail="expected F64 slot")
  }
}

///|
fn Frame::binary_i64(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  operation : (Int64, Int64) -> Int64,
) -> Unit raise ExecutionFailure {
  self.write(destination, I64(operation(self.i64(left), self.i64(right))))
}

///|
fn Frame::binary_f64(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  operation : (Double, Double) -> Double,
) -> Unit raise ExecutionFailure {
  self.write(destination, F64(operation(self.f64(left), self.f64(right))))
}

///|
fn Frame::compare_i32(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  predicate : (Int, Int) -> Bool,
) -> Unit raise ExecutionFailure {
  self.write(
    destination,
    I32(if predicate(self.i32(left), self.i32(right)) { 1 } else { 0 }),
  )
}

///|
fn Frame::compare_i64(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  predicate : (Int64, Int64) -> Bool,
) -> Unit raise ExecutionFailure {
  self.write(
    destination,
    I32(if predicate(self.i64(left), self.i64(right)) { 1 } else { 0 }),
  )
}

///|
fn Frame::compare_f64(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  predicate : (Double, Double) -> Bool,
) -> Unit raise ExecutionFailure {
  self.write(
    destination,
    I32(if predicate(self.f64(left), self.f64(right)) { 1 } else { 0 }),
  )
}

///|
fn ExecutionInstance::bytecode_body(
  self : ExecutionInstance,
  function : @bytecode.FunctionId,
) -> @bytecode.FunctionBody raise ExecutionFailure {
  match self.loaded.image.functions[function.value - 1] {
    BytecodeBody(body) => body
    RuntimeImport(_) =>
      raise InternalFailure(detail="expected bytecode function body")
  }
}

///|
fn ExecutionInstance::retain_for_slot(
  self : ExecutionInstance,
  frame : Frame,
  slot : @bytecode.SlotId,
  value : VMValue,
) -> Unit raise ExecutionFailure {
  match (frame.body.slots[slot.value].cleanup, value) {
    (OwnedRef, I32(reference)) => self.heap.retain_reference(reference)
    (OwnedCallable, I64(callable)) => self.heap.retain_callable(callable)
    (OwnedErased, I64(payload)) => {
      let companion = match frame.body.slots[slot.value].erased_companion {
        Some(companion) => companion
        None => raise InternalFailure(detail="OwnedErased slot lacks companion")
      }
      self.heap.retain_erased(payload, { value: frame.i32(companion) })
    }
    (Trivial, _) =>
      raise InternalFailure(detail="retain_copy destination is Trivial")
    _ => raise InternalFailure(detail="retain_copy representation mismatch")
  }
}

///|
fn ExecutionInstance::release_for_slot(
  self : ExecutionInstance,
  frame : Frame,
  slot : @bytecode.SlotId,
  value : VMValue,
) -> Unit raise ExecutionFailure {
  match (frame.body.slots[slot.value].cleanup, value) {
    (OwnedRef, I32(reference)) => self.heap.release_reference(reference)
    (OwnedCallable, I64(callable)) => self.heap.release_callable(callable)
    (OwnedErased, I64(payload)) => {
      let companion = match frame.body.slots[slot.value].erased_companion {
        Some(companion) => companion
        None => raise InternalFailure(detail="OwnedErased slot lacks companion")
      }
      self.heap.release_erased(payload, { value: frame.i32(companion) })
    }
    (Trivial, _) => ()
    _ => raise InternalFailure(detail="release representation mismatch")
  }
}

///|
fn ExecutionInstance::call_direct(
  self : ExecutionInstance,
  frame : Frame,
  function : @bytecode.FunctionId,
  environment : @bytecode.SlotId?,
  witnesses : Array[@bytecode.SlotId],
  arguments : Array[@bytecode.SlotId],
  destination : @bytecode.SlotId?,
  tail~ : Bool,
) -> Unit raise ExecutionFailure {
  let environment_value = match environment {
    Some(slot) => {
      let value = frame.value(slot)
      frame.consume_owner(slot)
      Some(value)
    }
    None => None
  }
  self.dispatch_call(
    frame,
    function,
    environment_value,
    frame.read_values(witnesses, consume=false),
    frame.read_values(arguments, consume=true),
    destination,
    tail~,
  )
}

///|
fn ExecutionInstance::call_value(
  self : ExecutionInstance,
  frame : Frame,
  callable_slot : @bytecode.SlotId,
  witnesses : Array[@bytecode.SlotId],
  arguments : Array[@bytecode.SlotId],
  destination : @bytecode.SlotId?,
  tail~ : Bool,
) -> Unit raise ExecutionFailure {
  let packed = frame.i64(callable_slot)
  frame.consume_owner(callable_slot)
  let environment = callable_environment(packed)
  self.dispatch_call(
    frame,
    callable_function(packed),
    if environment == 0 {
      None
    } else {
      Some(I32(environment))
    },
    frame.read_values(witnesses, consume=false),
    frame.read_values(arguments, consume=true),
    destination,
    tail~,
  )
}

///|
fn Frame::read_values(
  self : Frame,
  slots : Array[@bytecode.SlotId],
  consume~ : Bool,
) -> Array[VMValue] raise ExecutionFailure {
  let values : Array[VMValue] = []
  for slot in slots {
    values.push(self.value(slot))
    if consume {
      self.consume_owner(slot)
    }
  }
  values
}

///|
fn ExecutionInstance::dispatch_call(
  self : ExecutionInstance,
  frame : Frame,
  function : @bytecode.FunctionId,
  environment : VMValue?,
  witnesses : Array[VMValue],
  arguments : Array[VMValue],
  destination : @bytecode.SlotId?,
  tail~ : Bool,
) -> Unit raise ExecutionFailure {
  match self.loaded.image.functions[function.value - 1] {
    BytecodeBody(body) => {
      if !tail &&
        self.config.max_call_depth is Some(maximum) &&
        self.frames.length() >= maximum {
        raise ResourceLimit(CallDepth)
      }
      let return_destination = if tail {
        frame.return_destination
      } else {
        destination
      }
      let next = make_frame(
        body, environment, witnesses, arguments, return_destination,
      )
      if tail {
        ignore(self.frames.pop())
      }
      self.frames.push(next)
    }
    RuntimeImport(_) => {
      let result = self.invoke_import(function, arguments)
      if tail {
        self.finish_frame(frame, result)
      } else if destination is Some(slot) && result is Some(value) {
        frame.write(slot, value)
      }
    }
  }
}

///|
fn ExecutionInstance::invoke_import(
  self : ExecutionInstance,
  function : @bytecode.FunctionId,
  arguments : Array[VMValue],
) -> VMValue? raise ExecutionFailure {
  let binding = match self.loaded.bindings[function.value - 1] {
    Some(binding) => binding
    None =>
      raise InternalFailure(detail="runtime import has no resolved binding")
  }
  let kinds = binding.parameters()
  let host_arguments : Array[@runtime.HostValue] = []
  let mut argument_index = 0
  for kind in kinds {
    if kind is Unit {
      host_arguments.push(Unit)
    } else {
      if argument_index >= arguments.length() {
        raise InternalFailure(detail="runtime import argument count mismatch")
      }
      host_arguments.push(self.to_host_value(arguments[argument_index], kind))
      argument_index += 1
    }
  }
  if argument_index != arguments.length() {
    raise InternalFailure(detail="runtime import argument count mismatch")
  }
  let host_result = binding.call(self.runtime.context(), host_arguments) catch {
    Failure(message~) => {
      self.release_import_arguments(arguments, kinds)
      raise ImportFailure(symbol=binding.symbol(), message~)
    }
  }
  self.release_import_arguments(arguments, kinds)
  self.from_host_value(binding.symbol(), host_result, binding.result())
}

///|
fn ExecutionInstance::to_host_value(
  self : ExecutionInstance,
  value : VMValue,
  kind : @runtime.RuntimeValueKind,
) -> @runtime.HostValue raise ExecutionFailure {
  match (kind, value) {
    (Bool, I32(value)) => Bool(value != 0)
    (Int, I64(value)) => Int(value)
    (Double, F64(value)) => Double(value)
    (String, I32(reference)) => {
      let bytes = self.heap.string_bytes(reference)
      BorrowedString(
        @runtime.HostStringView::new(length=bytes.length(), read_byte=index => {
          bytes[index]
        }),
      )
    }
    (Unit, _) => Unit
    _ =>
      raise InternalFailure(
        detail="runtime import argument representation mismatch",
      )
  }
}

///|
fn ExecutionInstance::from_host_value(
  self : ExecutionInstance,
  symbol : String,
  value : @runtime.HostValue,
  kind : @runtime.RuntimeValueKind,
) -> VMValue? raise ExecutionFailure {
  match (kind, value) {
    (Unit, Unit) => None
    (Bool, Bool(value)) => Some(I32(if value { 1 } else { 0 }))
    (Int, Int(value)) => Some(I64(value))
    (Double, Double(value)) => Some(F64(value))
    (String, String(value)) => {
      let bytes = @utf8.encode(value)
      for byte in bytes {
        if byte.to_int() > 0x7F {
          raise ImportFailure(
            symbol~,
            message="runtime import returned non-ASCII String",
          )
        }
      }
      Some(I32(self.heap.allocate_string(bytes)))
    }
    _ =>
      raise ImportFailure(
        symbol~,
        message="runtime import returned the wrong primitive kind",
      )
  }
}

///|
fn ExecutionInstance::release_import_arguments(
  self : ExecutionInstance,
  arguments : Array[VMValue],
  kinds : Array[@runtime.RuntimeValueKind],
) -> Unit raise ExecutionFailure {
  let mut argument_index = 0
  for kind in kinds {
    if kind is Unit {
      continue
    }
    if kind is String && arguments[argument_index] is I32(reference) {
      self.heap.release_reference(reference)
    }
    argument_index += 1
  }
}

///|
fn ExecutionInstance::return_from_frame(
  self : ExecutionInstance,
  frame : Frame,
  source : @bytecode.SlotId?,
) -> Unit raise ExecutionFailure {
  let result = match source {
    Some(slot) => {
      let value = frame.value(slot)
      frame.consume_owner(slot)
      Some(value)
    }
    None => None
  }
  self.finish_frame(frame, result)
}

///|
fn ExecutionInstance::finish_frame(
  self : ExecutionInstance,
  frame : Frame,
  result : VMValue?,
) -> Unit {
  ignore(self.frames.pop())
  if !self.frames.is_empty() &&
    frame.return_destination is Some(destination) &&
    result is Some(value) {
    self.frames[self.frames.length() - 1].write(destination, value)
  }
}

///|
fn ExecutionInstance::transfer_edge(
  self : ExecutionInstance,
  frame : Frame,
  edge : @bytecode.Edge,
) -> Unit raise ExecutionFailure {
  ignore(self)
  let target = frame.body.blocks[edge.target.value]
  let values = frame.read_values(edge.arguments, consume=true)
  for index in 0..<values.length() {
    frame.write(target.parameters[index], values[index])
  }
  frame.block = edge.target.value
  frame.instruction = 0
}

///|
fn ExecutionInstance::cleanup_frames(self : ExecutionInstance) -> Unit {
  for frame in self.frames {
    for index in 0..<frame.owned_live.length() {
      if frame.owned_live[index] && frame.slots[index] is Some(value) {
        self.release_for_slot(frame, { value: index }, value) catch {
          _ => ()
        }
        frame.owned_live[index] = false
      }
    }
  }
  self.frames.clear()
}
