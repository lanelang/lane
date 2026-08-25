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
fn Frame::f32(
  self : Frame,
  slot : @bytecode.SlotId,
) -> Float raise ExecutionFailure {
  match self.value(slot) {
    F32(value) => value
    _ => raise InternalFailure(detail="expected F32 slot")
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
fn Frame::binary_i32(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  operation : (Int, Int) -> Int,
) -> Unit raise ExecutionFailure {
  self.write(destination, I32(operation(self.i32(left), self.i32(right))))
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
fn Frame::binary_f32(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  operation : (Float, Float) -> Float,
) -> Unit raise ExecutionFailure {
  self.write(destination, F32(operation(self.f32(left), self.f32(right))))
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
fn Frame::compare_f32(
  self : Frame,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  predicate : (Float, Float) -> Bool,
) -> Unit raise ExecutionFailure {
  self.write(
    destination,
    I32(if predicate(self.f32(left), self.f32(right)) { 1 } else { 0 }),
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
      self.heap.retain_erased(payload, { value: frame.i32(companion), })
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
      self.heap.release_erased(payload, { value: frame.i32(companion), })
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
  expected_abi_id : @bytecode.CallableAbiId,
  witnesses : Array[@bytecode.SlotId],
  arguments : Array[@bytecode.SlotId],
  destination : @bytecode.SlotId?,
  tail~ : Bool,
) -> Unit raise ExecutionFailure {
  let packed = frame.i64(callable_slot)
  let function = callable_function(packed)
  let environment = callable_environment(packed)
  self.validate_callable_invocation(
    frame,
    function,
    expected_abi_id,
    environment != 0,
    witnesses,
    arguments,
    destination,
    tail~,
  )
  frame.consume_owner(callable_slot)
  self.dispatch_call(
    frame,
    function,
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
fn ExecutionInstance::validate_callable_invocation(
  self : ExecutionInstance,
  frame : Frame,
  function : @bytecode.FunctionId,
  expected_abi_id : @bytecode.CallableAbiId,
  has_environment : Bool,
  witnesses : Array[@bytecode.SlotId],
  arguments : Array[@bytecode.SlotId],
  destination : @bytecode.SlotId?,
  tail~ : Bool,
) -> Unit raise ExecutionFailure {
  let expected = match self.loaded.image.callable_abi(expected_abi_id) {
    Some(abi) => abi
    None => raise InvalidCallable(InvalidAbi(abi=expected_abi_id))
  }
  let entry = match self.loaded.image.functions.get(function.value - 1) {
    Some(entry) if function.value > 0 => entry
    _ => raise InvalidCallable(InvalidTarget(function~))
  }
  let actual = match entry.callable_abi() {
    Some(abi) => abi
    None => raise InvalidCallable(InvalidTarget(function~))
  }
  let actual_abi_id = match
    self.loaded.image.function_callable_abi_id(function) {
    Some(id) => id
    None => raise InvalidCallable(InvalidTarget(function~))
  }
  if !actual.accepts_callsite(expected) {
    raise InvalidCallable(
      AbiMismatch(function~, expected=expected_abi_id, actual=actual_abi_id),
    )
  }
  let expects_environment = match entry {
    BytecodeBody(body) => body.inputs.environment is Some(_)
    RuntimeImport(_) => false
  }
  if expects_environment != has_environment {
    raise InvalidCallable(
      EnvironmentMismatch(
        function~,
        expected=expects_environment,
        actual=has_environment,
      ),
    )
  }
  if witnesses.length() != expected.witnesses.length() {
    raise InvalidCallable(
      WitnessCountMismatch(
        expected=expected.witnesses.length(),
        actual=witnesses.length(),
      ),
    )
  }
  if arguments.length() != expected.parameters.length() {
    raise InvalidCallable(
      ArgumentCountMismatch(
        expected=expected.parameters.length(),
        actual=arguments.length(),
      ),
    )
  }
  for index, witness in witnesses {
    let actual = frame.body.slots[witness.value]
    let expected_witness = expected.witnesses[index]
    if actual.representation != expected_witness.representation ||
      actual.cleanup != expected_witness.cleanup ||
      actual.kind != expected_witness.kind ||
      !value_has_representation(
        frame.value(witness),
        expected_witness.representation,
      ) {
      raise InvalidCallable(WitnessShapeMismatch(index~))
    }
  }
  for index, argument in arguments {
    let slot = frame.body.slots[argument.value]
    let parameter = expected.parameters[index]
    if slot.representation != parameter.representation ||
      slot.cleanup != parameter.cleanup ||
      slot.kind != parameter.kind ||
      !value_has_representation(frame.value(argument), parameter.representation) {
      raise InvalidCallable(ArgumentShapeMismatch(index~))
    }
  }
  let result_matches = if tail {
    frame.body.result == expected.result
  } else {
    match (expected.result, destination) {
      (Unit, None) => true
      (Value(representation, cleanup, kind), Some(slot)) => {
        let metadata = frame.body.slots[slot.value]
        metadata.representation == representation &&
        metadata.cleanup == cleanup &&
        metadata.kind == kind
      }
      _ => false
    }
  }
  if !result_matches {
    raise InvalidCallable(ResultShapeMismatch)
  }
}

///|
fn value_has_representation(
  value : VMValue,
  representation : @bytecode.Representation,
) -> Bool {
  match (value, representation) {
    (I32(_), I32) | (I64(_), I64) | (F32(_), F32) | (F64(_), F64) => true
    _ => false
  }
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
  let entry = match self.loaded.image.functions.get(function.value - 1) {
    Some(entry) if function.value > 0 => entry
    _ => raise InvalidCallable(InvalidTarget(function~))
  }
  match entry {
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
    (I64, I64(value)) => I64(value)
    (F64, F64(value)) => F64(value)
    (F32, F32(value)) => F32(value)
    (String, I32(reference)) => {
      let bytes = self.heap.byte_sequence(reference)
      BorrowedString(
        @runtime.HostStringView::new(length=bytes.length(), read_byte=index => {
          bytes[index]
        }),
      )
    }
    (Opaque, I32(reference)) =>
      BorrowedOpaque(self.heap.borrow_host_object(reference))
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
    (I64, I64(value)) => Some(I64(value))
    (F64, F64(value)) => Some(F64(value))
    (F32, F32(value)) => Some(F32(value))
    (String, String(bytes)) => {
      ignore(
        @utf8.decode(bytes) catch {
          _ =>
            raise ImportFailure(
              symbol~,
              message="runtime import returned invalid UTF-8 String",
            )
        },
      )
      Some(I32(self.heap.allocate_byte_sequence(bytes)))
    }
    (Opaque, OwnedOpaque(object)) => {
      let result : Result[Int, ExecutionFailure] = self.runtime.adopt_host_object(
        object,
        handle => {
          Ok(self.heap.allocate_host_object(handle)) catch {
            error => Err(error)
          }
        },
      ) catch {
        HostObjectLimitExceeded => raise ResourceLimit(HostObjects)
        InvalidOwnedResult(detail~) =>
          raise ImportFailure(symbol~, message=detail)
        InvalidHostObjectHandle(detail~) => raise InternalFailure(detail~)
      }
      match result {
        Ok(reference) => Some(I32(reference))
        Err(error) => raise error
      }
    }
    _ =>
      raise ImportFailure(
        symbol~,
        message="runtime import returned the wrong value kind",
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
    if (kind is String || kind is Opaque) &&
      arguments[argument_index] is I32(reference) {
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
        self.release_for_slot(frame, { value: index, }, value) catch {
          _ => ()
        }
        frame.owned_live[index] = false
      }
    }
  }
  self.frames.clear()
}
