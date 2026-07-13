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
  heap : Heap
  frames : Array[Frame]
  mut state : InstanceState
}

///|
pub fn LoadedImage::new_instance(
  self : LoadedImage,
  config? : @runtime.ExecutionConfig = @runtime.ExecutionConfig::defaults(),
) -> ExecutionInstance {
  {
    loaded: self,
    config,
    heap: Heap::new(self.image, config.max_live_heap_bytes),
    frames: [],
    state: Ready,
  }
}

///|
pub fn ExecutionInstance::execute(
  self : ExecutionInstance,
) -> Result[Unit, @runtime.ExecutionError] {
  if self.state != Ready {
    return Err(InstanceNotReady)
  }
  self.state = Running
  let mut should_cleanup = true
  let result = try {
    self.run()
    Ok(())
  } catch {
    ImportFailure(symbol~, message~) =>
      Err(@runtime.ExecutionError::RuntimeImportFailure(symbol~, message~))
    ResourceLimit(kind) => Err(ExecutionResourceLimit(kind~))
    Trap(detail~) => {
      should_cleanup = false
      Err(EngineTrap(detail~))
    }
    InternalFailure(detail~) => Err(InternalRuntimeFailure(detail~))
  }
  if result is Err(_) && should_cleanup {
    self.cleanup_frames()
  }
  self.state = Terminal
  result
}

///|
fn ExecutionInstance::run(
  self : ExecutionInstance,
) -> Unit raise ExecutionFailure {
  let entry = self.loaded.image.entry
  let body = self.bytecode_body(entry)
  self.frames.push(make_frame(body, None, [], [], None))
  while !self.frames.is_empty() {
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
    ConstInt(destination, value) => frame.write(destination, I64(value))
    ConstDouble(destination, bits) =>
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
    StringLength(destination, source) => {
      let length = self.heap.string_bytes(frame.i32(source)).length()
      frame.write(destination, I64(length.to_int64()))
    }
    StringConcat(destination, left, right) =>
      self.string_concat(frame, destination, left, right)
    StringSlice(destination, source, start, length) =>
      self.string_slice(frame, destination, source, start, length)
    StringEq(destination, left, right) => {
      let equal = self.heap.string_bytes(frame.i32(left)) ==
        self.heap.string_bytes(frame.i32(right))
      frame.write(destination, I32(if equal { 1 } else { 0 }))
    }
    IntAdd(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a + b })
    IntSub(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a - b })
    IntMul(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a * b })
    IntNeg(destination, source) =>
      frame.write(destination, I64(0L - frame.i64(source)))
    IntDiv(destination, left, right) => {
      let dividend = frame.i64(left)
      let divisor = frame.i64(right)
      if divisor == 0L ||
        (dividend == -9223372036854775807L - 1L && divisor == -1L) {
        raise Trap(detail="invalid signed integer division")
      }
      frame.write(destination, I64(dividend / divisor))
    }
    IntRem(destination, left, right) => {
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
    IntAnd(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a & b })
    IntOr(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a | b })
    IntXor(destination, left, right) =>
      frame.binary_i64(destination, left, right, fn(a, b) { a ^ b })
    IntNot(destination, source) =>
      frame.write(destination, I64(frame.i64(source).lnot()))
    IntShl(destination, left, right) =>
      frame.write(
        destination,
        I64(frame.i64(left) << (frame.i64(right).to_int() & 63)),
      )
    IntShrS(destination, left, right) =>
      frame.write(
        destination,
        I64(frame.i64(left) >> (frame.i64(right).to_int() & 63)),
      )
    IntEq(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a == b })
    IntNe(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a != b })
    IntLt(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a < b })
    IntLe(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a <= b })
    IntGt(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a > b })
    IntGe(destination, left, right) =>
      frame.compare_i64(destination, left, right, fn(a, b) { a >= b })
    BoolNot(destination, source) =>
      frame.write(destination, I32(if frame.i32(source) == 0 { 1 } else { 0 }))
    BoolEq(destination, left, right) =>
      frame.compare_i32(destination, left, right, fn(a, b) { a == b })
    BoolNe(destination, left, right) =>
      frame.compare_i32(destination, left, right, fn(a, b) { a != b })
    DoubleAdd(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a + b })
    DoubleSub(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a - b })
    DoubleMul(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a * b })
    DoubleDiv(destination, left, right) =>
      frame.binary_f64(destination, left, right, fn(a, b) { a / b })
    DoubleNeg(destination, source) =>
      frame.write(destination, F64(-frame.f64(source)))
    DoubleEq(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a == b })
    DoubleNe(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a != b })
    DoubleLt(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a < b })
    DoubleLe(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a <= b })
    DoubleGt(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a > b })
    DoubleGe(destination, left, right) =>
      frame.compare_f64(destination, left, right, fn(a, b) { a >= b })
    IntToDouble(destination, source) =>
      frame.write(destination, F64(frame.i64(source).to_double()))
    DoubleToInt(destination, source) => {
      let value = frame.f64(source)
      if value != value ||
        value < -9223372036854775808.0 ||
        value >= 9223372036854775808.0 {
        raise Trap(detail="invalid Double-to-Int conversion")
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
