///|
pub enum InstanceState {
  Ready
  Running
  Terminal
} derive(Eq)

///|
pub struct Frame {
  body : @bytecode.FunctionBody
  slots : Array[VMValue?]
  owned_live : Array[Bool]
  mut block : Int
  mut instruction : Int
  return_destination : @bytecode.SlotId?
}

///|
pub struct ExecutionInstance {
  loaded : LoadedImage
  config : @runtime.ExecutionConfig
  priv runtime : @runtime.ExecutionRuntime
  heap : Heap
  frames : Array[Frame]
  globals : Array[VMValue?]
  initialized_globals : Array[@bytecode.GlobalId]
  mut initializing : Bool
  mut state : InstanceState
}

///|
pub fn LoadedImage::new_instance(
  self : LoadedImage,
  config? : @runtime.ExecutionConfig = @runtime.ExecutionConfig::defaults(),
) -> ExecutionInstance {
  let runtime = @runtime.ExecutionRuntime::new(config~)
  {
    loaded: self,
    config,
    runtime,
    heap: Heap::new(self.image, runtime, config.max_live_heap_bytes),
    frames: [],
    globals: Array::make(self.image.globals.length(), None),
    initialized_globals: [],
    initializing: false,
    state: Ready,
  }
}

///|
pub fn ExecutionInstance::execute(
  self : ExecutionInstance,
  cancel? : (() -> Bool)? = None,
) -> Result[Unit, @runtime.ExecutionError] {
  if self.state != Ready {
    return Err(InstanceNotReady)
  }
  self.state = Running
  let mut should_cleanup = true
  let result = try {
    self.run(cancel)
    self.cleanup_globals()
    Ok(())
  } catch {
    ImportFailure(symbol~, message~) =>
      Err(@runtime.ExecutionError::RuntimeImportFailure(symbol~, message~))
    ResourceLimit(kind) => Err(ExecutionResourceLimit(kind~))
    InterruptedExecution => {
      should_cleanup = false
      Err(Interrupted)
    }
    Trap(detail~) => {
      should_cleanup = false
      Err(EngineTrap(detail~))
    }
    InternalFailure(detail~) => Err(InternalRuntimeFailure(detail~))
  }
  if result is Err(_) && should_cleanup {
    self.cleanup_frames()
    self.cleanup_globals() catch {
      _ => ()
    }
  }
  self.state = Terminal
  result
}

///|
fn ExecutionInstance::run(
  self : ExecutionInstance,
  cancel : (() -> Bool)?,
) -> Unit raise ExecutionFailure {
  if cancel is Some(check) && check() {
    raise InterruptedExecution
  }
  if self.config.max_call_depth is Some(maximum) && maximum < 1 {
    raise ResourceLimit(CallDepth)
  }
  match self.loaded.image.initializer {
    Some(initializer) => {
      self.initializing = true
      self.run_root(initializer, cancel)
      self.validate_initialized_globals()
      self.initializing = false
    }
    None =>
      if !self.loaded.image.globals.is_empty() {
        raise InternalFailure(detail="instance globals require an initializer")
      }
  }
  self.run_root(self.loaded.image.entry, cancel)
}

///|
fn ExecutionInstance::run_root(
  self : ExecutionInstance,
  function : @bytecode.FunctionId,
  cancel : (() -> Bool)?,
) -> Unit raise ExecutionFailure {
  let body = self.bytecode_body(function)
  self.frames.push(make_frame(body, None, [], [], None))
  while !self.frames.is_empty() {
    if cancel is Some(check) && check() {
      raise InterruptedExecution
    }
    let frame = self.frames[self.frames.length() - 1]
    let block = frame.body.blocks[frame.block]
    if frame.instruction < block.instructions.length() {
      let instruction = block.instructions[frame.instruction]
      frame.instruction += 1
      self.execute_instruction(frame, instruction)
    } else {
      self.execute_terminator(frame, block.terminator)
    }
  }
}

///|
fn ExecutionInstance::execute_instruction(
  self : ExecutionInstance,
  frame : Frame,
  instruction : @bytecode.Instruction,
) -> Unit raise ExecutionFailure {
  match instruction {
    Copy(destination, source) => frame.write(destination, frame.value(source))
    Move(destination, source) => frame.transfer(destination, source)
    RetainCopy(destination, source) => {
      let value = frame.value(source)
      self.retain_for_slot(frame, destination, value)
      frame.write(destination, value)
    }
    Release(slot) => {
      self.release_for_slot(frame, slot, frame.value(slot))
      frame.consume_owner(slot)
    }
    ConstI64(destination, value) => frame.write(destination, I64(value))
    ConstI32(destination, value) => frame.write(destination, I32(value))
    ConstChar(destination, value) => frame.write(destination, I32(value))
    ConstF64(destination, bits) =>
      frame.write(destination, F64(bits.reinterpret_as_double()))
    ConstBool(destination, value) =>
      frame.write(destination, I32(if value { 1 } else { 0 }))
    ConstLayout(destination, layout) =>
      frame.write(destination, I32(layout.value))
    ConstFunction(destination, function) =>
      frame.write(destination, I64(callable(function, 0)))
    ConstString(destination, constant) =>
      frame.write(destination, I32(self.heap.constant_reference(constant)))
    CallDirect(function, environment, witnesses, arguments, destination) =>
      self.call_direct(
        frame,
        function,
        environment,
        witnesses,
        arguments,
        destination,
        tail=false,
      )
    CallValue(callable_slot, witnesses, arguments, destination) =>
      self.call_value(
        frame,
        callable_slot,
        witnesses,
        arguments,
        destination,
        tail=false,
      )
    MakeClosure(destination, function, environment) => {
      let reference = frame.i32(environment)
      frame.consume_owner(environment)
      frame.write(destination, I64(callable(function, reference)))
    }
    ByteToI64(destination, source) =>
      frame.write(destination, I64(frame.i32(source).to_int64()))
    I64ToByte(destination, source) =>
      frame.write(destination, I32((frame.i64(source) & 255L).to_int()))
    ByteSequenceMake(destination, length, fill) =>
      self.byte_sequence_make(frame, destination, length, fill)
    ByteSequenceLength(destination, source) =>
      self.byte_sequence_length(frame, destination, source)
    ByteSequenceGet(destination, source, index) =>
      self.byte_sequence_get(frame, destination, source, index)
    ByteSequenceSet(destination, source, index, value) =>
      self.byte_sequence_set(frame, destination, source, index, value)
    ByteSequenceEqual(destination, left, right) =>
      self.byte_sequence_equal(frame, destination, left, right)
    ByteSequenceConcat(destination, left, right) =>
      self.byte_sequence_concat(frame, destination, left, right)
    ByteSequenceSlice(destination, source, start, length) =>
      self.byte_sequence_slice(frame, destination, source, start, length)
    ByteSequenceIsValidUtf8(destination, source) =>
      self.byte_sequence_is_valid_utf8(frame, destination, source)
    I32Add(destination, left, right) =>
      frame.binary_i32(destination, left, right, fn(a, b) { a + b })
    I32Sub(destination, left, right) =>
      frame.binary_i32(destination, left, right, fn(a, b) { a - b })
    I32Mul(destination, left, right) =>
      frame.binary_i32(destination, left, right, fn(a, b) { a * b })
    I32Neg(destination, source) =>
      frame.write(destination, I32(0 - frame.i32(source)))
    I32Div(destination, left, right) => {
      let dividend = frame.i32(left)
      let divisor = frame.i32(right)
      if divisor == 0 || (dividend == -2147483647 - 1 && divisor == -1) {
        raise Trap(detail="invalid signed 32-bit integer division")
      }
      frame.write(destination, I32(dividend / divisor))
    }
    I32Rem(destination, left, right) => {
      let dividend = frame.i32(left)
      let divisor = frame.i32(right)
      if divisor == 0 {
        raise Trap(detail="signed 32-bit integer remainder by zero")
      }
      let value = if dividend == -2147483647 - 1 && divisor == -1 {
        0
      } else {
        dividend % divisor
      }
      frame.write(destination, I32(value))
    }
    I32Eq(destination, left, right) =>
      frame.compare_i32(destination, left, right, fn(a, b) { a == b })
    I32Lt(destination, left, right) =>
      frame.compare_i32(destination, left, right, fn(a, b) { a < b })
    I32ToI64(destination, source) =>
      frame.write(destination, I64(frame.i32(source).to_int64()))
    I64ToI32(destination, source) =>
      frame.write(destination, I32(frame.i64(source).to_int()))
    I64Add(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a + b })
    I64Sub(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a - b })
    I64Mul(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a * b })
    I64Neg(destination, source) =>
      frame.write(destination, I64(0L - frame.i64(source)))
    I64Div(destination, left, right) => {
      let dividend = frame.i64(left)
      let divisor = frame.i64(right)
      if divisor == 0L ||
        (dividend == -9223372036854775807L - 1L && divisor == -1L) {
        raise Trap(detail="invalid signed integer division")
      }
      frame.write(destination, I64(dividend / divisor))
    }
    I64Rem(destination, left, right) => {
      let dividend = frame.i64(left)
      let divisor = frame.i64(right)
      if divisor == 0L {
        raise Trap(detail="integer remainder by zero")
      }
      let value = if dividend == -9223372036854775807L - 1L && divisor == -1L {
        0L
      } else {
        dividend % divisor
      }
      frame.write(destination, I64(value))
    }
    I64And(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a & b })
    I64Or(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a | b })
    I64Xor(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a ^ b })
    I64Not(destination, source) =>
      frame.write(destination, I64(frame.i64(source).lnot()))
    I64Shl(destination, left, right) =>
      frame.write(
        destination,
        I64(frame.i64(left) << (frame.i64(right).to_int() & 63)),
      )
    I64ShrS(destination, left, right) =>
      frame.write(
        destination,
        I64(frame.i64(left) >> (frame.i64(right).to_int() & 63)),
      )
    I64Eq(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a == b })
    I64Ne(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a != b })
    I64Lt(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a < b })
    I64Le(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a <= b })
    I64Gt(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a > b })
    I64Ge(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a >= b })
    BoolNot(destination, source) =>
      frame.write(destination, I32(if frame.i32(source) == 0 { 1 } else { 0 }))
    BoolEq(destination, left, right) =>
      frame.compare_i32(destination, left, right, fn(a, b) { a == b })
    BoolNe(destination, left, right) =>
      frame.compare_i32(destination, left, right, fn(a, b) { a != b })
    F64Add(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a + b })
    F64Sub(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a - b })
    F64Mul(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a * b })
    F64Div(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a / b })
    F64Neg(destination, source) =>
      frame.write(destination, F64(-frame.f64(source)))
    F64Eq(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a == b })
    F64Ne(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a != b })
    F64Lt(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a < b })
    F64Le(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a <= b })
    F64Gt(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a > b })
    F64Ge(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a >= b })
    I64ToF64(destination, source) =>
      frame.write(destination, F64(frame.i64(source).to_double()))
    F64ToI64(destination, source) => {
      let value = frame.f64(source)
      if value != value ||
        value < -9223372036854775808.0 ||
        value >= 9223372036854775808.0 {
        raise Trap(detail="invalid F64-to-I64 conversion")
      }
      frame.write(destination, I64(value.to_int64()))
    }
    EraseI32(destination, source) => {
      let value = frame.i32(source).to_int64() & 0xFFFFFFFFL
      frame.transfer_value(destination, source, I64(value))
    }
    UneraseI32(destination, source) =>
      frame.transfer_value(
        destination,
        source,
        I32((frame.i64(source) & 0xFFFFFFFFL).to_int()),
      )
    EraseI64(destination, source) =>
      frame.transfer_value(destination, source, frame.value(source))
    UneraseI64(destination, source) =>
      frame.transfer_value(destination, source, frame.value(source))
    EraseF64(destination, source) =>
      frame.transfer_value(
        destination,
        source,
        I64(frame.f64(source).reinterpret_as_int64()),
      )
    UneraseF64(destination, source) =>
      frame.transfer_value(
        destination,
        source,
        F64(frame.i64(source).reinterpret_as_double()),
      )
    EraseUnit(destination) => frame.write(destination, I64(0L))
    UneraseUnit(source) => frame.consume_owner(source)
    MakeData(destination, shape, layout, witnesses, fields) =>
      self.make_data(frame, destination, shape, layout, witnesses, fields)
    LoadTag(destination, source) => {
      let object = self.heap.object(frame.i32(source))
      match object.payload {
        Data(shape, _, _) => {
          let tag = match self.loaded.image.object_shapes[shape.value] {
            Data(data) => data.constructor_tag
            _ =>
              raise InternalFailure(detail="Data object has Environment shape")
          }
          frame.write(destination, I32(tag))
        }
        _ => raise InternalFailure(detail="load_tag source is not Data")
      }
    }
    LoadObjectWitness(destination, shape, source, ordinal) =>
      self.load_object_witness(frame, destination, shape, source, ordinal)
    BorrowField(shape, source, index, result) =>
      self.borrow_member(frame, shape, source, index, result, environment=false)
    ConsumeFields(shape, source, selections) =>
      self.consume_members(frame, shape, source, selections, environment=false)
    MakeEnv(destination, shape, layout, witnesses, captures) =>
      self.make_environment(
        frame, destination, shape, layout, witnesses, captures,
      )
    BorrowCapture(shape, source, index, result) =>
      self.borrow_member(frame, shape, source, index, result, environment=true)
    ConsumeCaptures(shape, source, selections) =>
      self.consume_members(frame, shape, source, selections, environment=true)
    InitGlobal(global, source) => self.initialize_global(frame, global, source)
    BorrowGlobal(destination, global) =>
      self.borrow_global(frame, destination, global)
  }
}

///|
fn ExecutionInstance::execute_terminator(
  self : ExecutionInstance,
  frame : Frame,
  terminator : @bytecode.Terminator,
) -> Unit raise ExecutionFailure {
  match terminator {
    Jump(edge) => self.transfer_edge(frame, edge)
    BranchBool(condition, true_edge, false_edge) =>
      self.transfer_edge(
        frame,
        if frame.i32(condition) != 0 {
          true_edge
        } else {
          false_edge
        },
      )
    SwitchTag(tag, cases, default) => {
      let value = frame.i32(tag)
      let edge = if value >= 0 && value < cases.length() {
        cases[value]
      } else {
        default
      }
      self.transfer_edge(frame, edge)
    }
    Return(source) => self.return_from_frame(frame, source)
    TailCallDirect(function, environment, witnesses, arguments) =>
      self.call_direct(
        frame,
        function,
        environment,
        witnesses,
        arguments,
        None,
        tail=true,
      )
    TailCallValue(callable_slot, witnesses, arguments) =>
      self.call_value(
        frame,
        callable_slot,
        witnesses,
        arguments,
        None,
        tail=true,
      )
    Unreachable => raise Trap(detail="reached unreachable bytecode terminator")
  }
}
