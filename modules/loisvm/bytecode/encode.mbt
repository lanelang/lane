///|
let bytecode_schema_v1 = 1

///|
let bytecode_schema_v2 = 2

///|
pub fn bytecode_image_to_binary(image : BytecodeImage) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  let schema_version = image.schema_version()
  writer.write_u8(schema_version)
  writer.write_function_id(image.entry)
  if schema_version == bytecode_schema_v2 {
    writer.write_optional_function_id(image.initializer)
  }
  writer.write_u32_le(image.functions.length())
  for function in image.functions {
    writer.write_function_entry(function)
  }
  if schema_version == bytecode_schema_v2 {
    writer.write_u32_le(image.globals.length())
    for global in image.globals {
      writer.write_global_metadata(global)
    }
  }
  writer.write_u32_le(image.layouts.length())
  for layout in image.layouts {
    writer.write_layout_recipe(layout)
  }
  writer.write_u32_le(image.object_shapes.length())
  for shape in image.object_shapes {
    writer.write_object_shape(shape)
  }
  writer.write_u32_le(image.constants.length())
  for constant in image.constants {
    writer.write_bytes(constant)
  }
  writer.to_bytes()
}

///|
fn BytecodeImage::schema_version(self : BytecodeImage) -> Int {
  if self.initializer is Some(_) ||
    !self.globals.is_empty() ||
    self.functions.any(function_entry_uses_globals) {
    bytecode_schema_v2
  } else {
    bytecode_schema_v1
  }
}

///|
fn function_entry_uses_globals(entry : FunctionEntry) -> Bool {
  match entry {
    RuntimeImport(_) => false
    BytecodeBody(body) =>
      body.blocks.any(block => {
        block.instructions.any(instruction => {
          instruction is InitGlobal(_, _) || instruction is BorrowGlobal(_, _)
        })
      })
  }
}

///|
fn @bytecodec.ByteWriter::write_function_entry(
  self : @bytecodec.ByteWriter,
  entry : FunctionEntry,
) -> Unit {
  match entry {
    BytecodeBody(body) => {
      self.write_u8(0x01)
      self.write_function_body(body)
    }
    RuntimeImport(import_) => {
      self.write_u8(0x02)
      self.write_u32_le(import_.abi_major)
      self.write_u32_le(import_.user_arity)
      self.write_bytes(@utf8.encode(import_.symbol))
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_function_body(
  self : @bytecodec.ByteWriter,
  body : FunctionBody,
) -> Unit {
  let payload = @bytecodec.ByteWriter::new()
  payload.write_u32_le(body.slots.length())
  for slot in body.slots {
    payload.write_slot_metadata(slot)
  }
  payload.write_optional_slot(body.inputs.environment)
  payload.write_slot_ids(body.inputs.witnesses)
  payload.write_slot_ids(body.inputs.user_parameters)
  payload.write_result_representation(body.result)
  payload.write_u32_le(body.blocks.length())
  for block in body.blocks {
    payload.write_block(block)
  }
  let bytes = payload.to_bytes()
  self.write_u32_le(bytes.length())
  self.write_raw_bytes(bytes)
}

///|
fn @bytecodec.ByteWriter::write_slot_metadata(
  self : @bytecodec.ByteWriter,
  slot : SlotMetadata,
) -> Unit {
  self.write_representation(slot.representation)
  self.write_cleanup(slot.cleanup)
  if slot.cleanup is OwnedErased {
    match slot.erased_companion {
      Some(companion) => self.write_slot_id(companion)
      None => self.write_u32_le(0)
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_global_metadata(
  self : @bytecodec.ByteWriter,
  global : GlobalMetadata,
) -> Unit {
  self.write_representation(global.representation)
  self.write_cleanup(global.cleanup)
  if global.cleanup is OwnedErased {
    match global.erased_companion {
      Some(companion) => self.write_global_id(companion)
      None => self.write_u32_le(0)
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_representation(
  self : @bytecodec.ByteWriter,
  representation : Representation,
) -> Unit {
  self.write_u8(
    match representation {
      I32 => 0x01
      I64 => 0x02
      F64 => 0x03
    },
  )
}

///|
fn @bytecodec.ByteWriter::write_cleanup(
  self : @bytecodec.ByteWriter,
  cleanup : Cleanup,
) -> Unit {
  self.write_u8(
    match cleanup {
      Trivial => 0x01
      OwnedRef => 0x02
      OwnedCallable => 0x03
      OwnedErased => 0x04
    },
  )
}

///|
fn @bytecodec.ByteWriter::write_result_representation(
  self : @bytecodec.ByteWriter,
  result : ResultRepresentation,
) -> Unit {
  self.write_u8(
    match result {
      Unit => 0x01
      I32 => 0x02
      I64 => 0x03
      F64 => 0x04
    },
  )
}

///|
fn @bytecodec.ByteWriter::write_layout_recipe(
  self : @bytecodec.ByteWriter,
  layout : LayoutRecipe,
) -> Unit {
  match layout {
    Unit => self.write_u8(0x01)
    Bool => self.write_u8(0x02)
    Int => self.write_u8(0x03)
    Double => self.write_u8(0x04)
    Callable => self.write_u8(0x05)
    String => self.write_u8(0x06)
    Data(shape) => {
      self.write_u8(0x07)
      self.write_object_shape_id(shape)
    }
    Environment(shape) => {
      self.write_u8(0x08)
      self.write_object_shape_id(shape)
    }
    Reference => self.write_u8(0x09)
  }
}

///|
fn @bytecodec.ByteWriter::write_object_shape(
  self : @bytecodec.ByteWriter,
  shape : ObjectShape,
) -> Unit {
  match shape {
    Data(data) => {
      self.write_u8(0x01)
      self.write_u32_le(data.constructor_tag)
      self.write_u32_le(data.stored_witness_count)
      self.write_u32_le(data.members.length())
      for schema in data.members {
        self.write_member_schema(schema)
      }
    }
    Environment(environment) => {
      self.write_u8(0x02)
      self.write_u32_le(environment.stored_witness_count)
      self.write_u32_le(environment.members.length())
      for schema in environment.members {
        self.write_member_schema(schema)
      }
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_member_schema(
  self : @bytecodec.ByteWriter,
  schema : MemberSchema,
) -> Unit {
  self.write_representation(schema.representation)
  self.write_cleanup(schema.cleanup)
  match schema.witness_ordinal {
    None => self.write_u32_le(0)
    Some(ordinal) => self.write_u32_le(ordinal + 1)
  }
}

///|
fn @bytecodec.ByteWriter::write_block(
  self : @bytecodec.ByteWriter,
  block : Block,
) -> Unit {
  self.write_slot_ids(block.parameters)
  self.write_u32_le(block.instructions.length())
  for instruction in block.instructions {
    self.write_instruction(instruction)
  }
  self.write_terminator(block.terminator)
}

///|
fn @bytecodec.ByteWriter::write_instruction(
  self : @bytecodec.ByteWriter,
  instruction : Instruction,
) -> Unit {
  match instruction {
    Copy(destination, source) =>
      self.write_binary_slots(0x01, destination, source)
    Move(destination, source) =>
      self.write_binary_slots(0x02, destination, source)
    RetainCopy(destination, source) =>
      self.write_binary_slots(0x03, destination, source)
    Release(slot) => {
      self.write_u8(0x04)
      self.write_slot_id(slot)
    }
    ConstInt(destination, value) => {
      self.write_u8(0x05)
      self.write_slot_id(destination)
      self.write_i64_le(value)
    }
    ConstDouble(destination, bits) => {
      self.write_u8(0x06)
      self.write_slot_id(destination)
      self.write_i64_le(bits)
    }
    ConstBool(destination, value) => {
      self.write_u8(0x07)
      self.write_slot_id(destination)
      self.write_bool(value)
    }
    ConstLayout(destination, layout) => {
      self.write_u8(0x08)
      self.write_slot_id(destination)
      self.write_layout_id(layout)
    }
    ConstFunction(destination, function) => {
      self.write_u8(0x09)
      self.write_slot_id(destination)
      self.write_function_id(function)
    }
    ConstString(destination, constant) => {
      self.write_u8(0x0A)
      self.write_slot_id(destination)
      self.write_constant_id(constant)
    }
    CallDirect(function, environment, witnesses, arguments, destination) => {
      self.write_u8(0x0B)
      self.write_function_id(function)
      self.write_optional_slot(environment)
      self.write_slot_ids(witnesses)
      self.write_slot_ids(arguments)
      self.write_optional_slot(destination)
    }
    CallValue(callable, witnesses, arguments, destination) => {
      self.write_u8(0x0C)
      self.write_slot_id(callable)
      self.write_slot_ids(witnesses)
      self.write_slot_ids(arguments)
      self.write_optional_slot(destination)
    }
    MakeData(destination, shape, layout, witnesses, fields) => {
      self.write_u8(0x0D)
      self.write_slot_id(destination)
      self.write_object_shape_id(shape)
      self.write_layout_operand(layout)
      self.write_slot_ids(witnesses)
      self.write_slot_ids(fields)
    }
    LoadTag(destination, source) =>
      self.write_binary_slots(0x0E, destination, source)
    BorrowField(shape, source, index, result) => {
      self.write_u8(0x0F)
      self.write_object_shape_id(shape)
      self.write_slot_id(source)
      self.write_u32_le(index)
      self.write_projection_result(result)
    }
    ConsumeFields(shape, source, selections) => {
      self.write_u8(0x10)
      self.write_object_shape_id(shape)
      self.write_slot_id(source)
      self.write_projection_selections(selections)
    }
    MakeEnv(destination, shape, layout, witnesses, captures) => {
      self.write_u8(0x11)
      self.write_slot_id(destination)
      self.write_object_shape_id(shape)
      self.write_layout_operand(layout)
      self.write_slot_ids(witnesses)
      self.write_slot_ids(captures)
    }
    BorrowCapture(shape, source, index, result) => {
      self.write_u8(0x12)
      self.write_object_shape_id(shape)
      self.write_slot_id(source)
      self.write_u32_le(index)
      self.write_projection_result(result)
    }
    ConsumeCaptures(shape, source, selections) => {
      self.write_u8(0x13)
      self.write_object_shape_id(shape)
      self.write_slot_id(source)
      self.write_projection_selections(selections)
    }
    MakeClosure(destination, function, environment) => {
      self.write_u8(0x14)
      self.write_slot_id(destination)
      self.write_function_id(function)
      self.write_slot_id(environment)
    }
    StringLength(destination, source) =>
      self.write_binary_slots(0x15, destination, source)
    StringConcat(destination, left, right) =>
      self.write_ternary_slots(0x16, destination, left, right)
    StringSlice(destination, source, start, length) => {
      self.write_u8(0x17)
      self.write_slot_id(destination)
      self.write_slot_id(source)
      self.write_slot_id(start)
      self.write_slot_id(length)
    }
    StringEq(destination, left, right) =>
      self.write_ternary_slots(0x18, destination, left, right)
    IntAdd(destination, left, right) =>
      self.write_ternary_slots(0x19, destination, left, right)
    IntSub(destination, left, right) =>
      self.write_ternary_slots(0x1A, destination, left, right)
    IntMul(destination, left, right) =>
      self.write_ternary_slots(0x1B, destination, left, right)
    IntNeg(destination, source) =>
      self.write_binary_slots(0x1C, destination, source)
    IntDiv(destination, left, right) =>
      self.write_ternary_slots(0x1D, destination, left, right)
    IntRem(destination, left, right) =>
      self.write_ternary_slots(0x1E, destination, left, right)
    IntAnd(destination, left, right) =>
      self.write_ternary_slots(0x1F, destination, left, right)
    IntOr(destination, left, right) =>
      self.write_ternary_slots(0x20, destination, left, right)
    IntXor(destination, left, right) =>
      self.write_ternary_slots(0x21, destination, left, right)
    IntNot(destination, source) =>
      self.write_binary_slots(0x22, destination, source)
    IntShl(destination, left, right) =>
      self.write_ternary_slots(0x23, destination, left, right)
    IntShrS(destination, left, right) =>
      self.write_ternary_slots(0x24, destination, left, right)
    IntEq(destination, left, right) =>
      self.write_ternary_slots(0x25, destination, left, right)
    IntNe(destination, left, right) =>
      self.write_ternary_slots(0x26, destination, left, right)
    IntLt(destination, left, right) =>
      self.write_ternary_slots(0x27, destination, left, right)
    IntLe(destination, left, right) =>
      self.write_ternary_slots(0x28, destination, left, right)
    IntGt(destination, left, right) =>
      self.write_ternary_slots(0x29, destination, left, right)
    IntGe(destination, left, right) =>
      self.write_ternary_slots(0x2A, destination, left, right)
    BoolNot(destination, source) =>
      self.write_binary_slots(0x2B, destination, source)
    BoolEq(destination, left, right) =>
      self.write_ternary_slots(0x2C, destination, left, right)
    BoolNe(destination, left, right) =>
      self.write_ternary_slots(0x2D, destination, left, right)
    DoubleAdd(destination, left, right) =>
      self.write_ternary_slots(0x2E, destination, left, right)
    DoubleSub(destination, left, right) =>
      self.write_ternary_slots(0x2F, destination, left, right)
    DoubleMul(destination, left, right) =>
      self.write_ternary_slots(0x30, destination, left, right)
    DoubleDiv(destination, left, right) =>
      self.write_ternary_slots(0x31, destination, left, right)
    DoubleNeg(destination, source) =>
      self.write_binary_slots(0x32, destination, source)
    DoubleEq(destination, left, right) =>
      self.write_ternary_slots(0x33, destination, left, right)
    DoubleNe(destination, left, right) =>
      self.write_ternary_slots(0x34, destination, left, right)
    DoubleLt(destination, left, right) =>
      self.write_ternary_slots(0x35, destination, left, right)
    DoubleLe(destination, left, right) =>
      self.write_ternary_slots(0x36, destination, left, right)
    DoubleGt(destination, left, right) =>
      self.write_ternary_slots(0x37, destination, left, right)
    DoubleGe(destination, left, right) =>
      self.write_ternary_slots(0x38, destination, left, right)
    IntToDouble(destination, source) =>
      self.write_binary_slots(0x39, destination, source)
    DoubleToInt(destination, source) =>
      self.write_binary_slots(0x3A, destination, source)
    EraseI32(destination, source) =>
      self.write_binary_slots(0x3B, destination, source)
    UneraseI32(destination, source) =>
      self.write_binary_slots(0x3C, destination, source)
    EraseI64(destination, source) =>
      self.write_binary_slots(0x3D, destination, source)
    UneraseI64(destination, source) =>
      self.write_binary_slots(0x3E, destination, source)
    EraseF64(destination, source) =>
      self.write_binary_slots(0x3F, destination, source)
    UneraseF64(destination, source) =>
      self.write_binary_slots(0x40, destination, source)
    EraseUnit(destination) => {
      self.write_u8(0x41)
      self.write_slot_id(destination)
    }
    UneraseUnit(source) => {
      self.write_u8(0x42)
      self.write_slot_id(source)
    }
    LoadObjectWitness(destination, shape, object, ordinal) => {
      self.write_u8(0x43)
      self.write_slot_id(destination)
      self.write_object_shape_id(shape)
      self.write_slot_id(object)
      self.write_u32_le(ordinal)
    }
    InitGlobal(global, source) => {
      self.write_u8(0x44)
      self.write_global_id(global)
      self.write_slot_id(source)
    }
    BorrowGlobal(destination, global) => {
      self.write_u8(0x45)
      self.write_slot_id(destination)
      self.write_global_id(global)
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_terminator(
  self : @bytecodec.ByteWriter,
  terminator : Terminator,
) -> Unit {
  match terminator {
    Jump(edge) => {
      self.write_u8(0x01)
      self.write_edge(edge)
    }
    BranchBool(condition, true_edge, false_edge) => {
      self.write_u8(0x02)
      self.write_slot_id(condition)
      self.write_edge(true_edge)
      self.write_edge(false_edge)
    }
    SwitchTag(tag, cases, default) => {
      self.write_u8(0x03)
      self.write_slot_id(tag)
      self.write_u32_le(cases.length())
      for edge in cases {
        self.write_edge(edge)
      }
      self.write_edge(default)
    }
    Return(source) => {
      self.write_u8(0x04)
      self.write_optional_slot(source)
    }
    TailCallDirect(function, environment, witnesses, arguments) => {
      self.write_u8(0x05)
      self.write_function_id(function)
      self.write_optional_slot(environment)
      self.write_slot_ids(witnesses)
      self.write_slot_ids(arguments)
    }
    TailCallValue(callable, witnesses, arguments) => {
      self.write_u8(0x06)
      self.write_slot_id(callable)
      self.write_slot_ids(witnesses)
      self.write_slot_ids(arguments)
    }
    Unreachable => self.write_u8(0x07)
  }
}

///|
fn @bytecodec.ByteWriter::write_edge(
  self : @bytecodec.ByteWriter,
  edge : Edge,
) -> Unit {
  self.write_block_id(edge.target)
  self.write_slot_ids(edge.arguments)
}

///|
fn @bytecodec.ByteWriter::write_layout_operand(
  self : @bytecodec.ByteWriter,
  operand : LayoutOperand,
) -> Unit {
  match operand {
    Immediate(layout) => {
      self.write_u8(0x01)
      self.write_layout_id(layout)
    }
    Witness(slot) => {
      self.write_u8(0x02)
      self.write_slot_id(slot)
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_projection_result(
  self : @bytecodec.ByteWriter,
  result : ProjectionResult,
) -> Unit {
  self.write_slot_id(result.value_destination)
  self.write_optional_slot(result.witness_destination)
}

///|
fn @bytecodec.ByteWriter::write_projection_selections(
  self : @bytecodec.ByteWriter,
  selections : Array[ProjectionSelection],
) -> Unit {
  self.write_u32_le(selections.length())
  for selection in selections {
    self.write_u32_le(selection.member_index)
    self.write_projection_result(selection.result)
  }
}

///|
fn @bytecodec.ByteWriter::write_binary_slots(
  self : @bytecodec.ByteWriter,
  tag : Int,
  first : SlotId,
  second : SlotId,
) -> Unit {
  self.write_u8(tag)
  self.write_slot_id(first)
  self.write_slot_id(second)
}

///|
fn @bytecodec.ByteWriter::write_ternary_slots(
  self : @bytecodec.ByteWriter,
  tag : Int,
  first : SlotId,
  second : SlotId,
  third : SlotId,
) -> Unit {
  self.write_u8(tag)
  self.write_slot_id(first)
  self.write_slot_id(second)
  self.write_slot_id(third)
}

///|
fn @bytecodec.ByteWriter::write_slot_ids(
  self : @bytecodec.ByteWriter,
  slots : Array[SlotId],
) -> Unit {
  self.write_u32_le(slots.length())
  for slot in slots {
    self.write_slot_id(slot)
  }
}

///|
fn @bytecodec.ByteWriter::write_optional_slot(
  self : @bytecodec.ByteWriter,
  slot : SlotId?,
) -> Unit {
  match slot {
    None => self.write_u32_le(0)
    Some(slot) => self.write_u32_le(slot.value + 1)
  }
}

///|
fn @bytecodec.ByteWriter::write_function_id(
  self : @bytecodec.ByteWriter,
  id : FunctionId,
) -> Unit {
  self.write_u32_le(id.value)
}

///|
fn @bytecodec.ByteWriter::write_optional_function_id(
  self : @bytecodec.ByteWriter,
  id : FunctionId?,
) -> Unit {
  match id {
    None => self.write_u32_le(0)
    Some(id) => self.write_function_id(id)
  }
}

///|
fn @bytecodec.ByteWriter::write_global_id(
  self : @bytecodec.ByteWriter,
  id : GlobalId,
) -> Unit {
  self.write_u32_le(id.value)
}

///|
fn @bytecodec.ByteWriter::write_layout_id(
  self : @bytecodec.ByteWriter,
  id : LayoutId,
) -> Unit {
  self.write_u32_le(id.value)
}

///|
fn @bytecodec.ByteWriter::write_block_id(
  self : @bytecodec.ByteWriter,
  id : BlockId,
) -> Unit {
  self.write_u32_le(id.value)
}

///|
fn @bytecodec.ByteWriter::write_slot_id(
  self : @bytecodec.ByteWriter,
  id : SlotId,
) -> Unit {
  self.write_u32_le(id.value)
}

///|
fn @bytecodec.ByteWriter::write_constant_id(
  self : @bytecodec.ByteWriter,
  id : ConstantId,
) -> Unit {
  self.write_u32_le(id.value)
}

///|
fn @bytecodec.ByteWriter::write_object_shape_id(
  self : @bytecodec.ByteWriter,
  id : ObjectShapeId,
) -> Unit {
  self.write_u32_le(id.value)
}
