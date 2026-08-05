///|
pub fn bytecode_image_to_binary(image : BytecodeImage) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_function_id(image.entry)
  writer.write_optional_function_id(image.initializer)
  writer.write_u32_le_int(image.callable_abis.length())
  for abi in image.callable_abis {
    writer.write_callable_abi(abi)
  }
  writer.write_u32_le_int(image.data_family_count)
  writer.write_u32_le_int(image.functions.length())
  for function in image.functions {
    writer.write_function_entry(function)
  }
  writer.write_u32_le_int(image.globals.length())
  for global in image.globals {
    writer.write_global_metadata(global)
  }
  writer.write_u32_le_int(image.layouts.length())
  for layout in image.layouts {
    writer.write_layout_recipe(layout)
  }
  writer.write_u32_le_int(image.object_shapes.length())
  for shape in image.object_shapes {
    writer.write_object_shape(shape)
  }
  writer.write_u32_le_int(image.constants.length())
  for constant in image.constants {
    writer.write_bytes(constant)
  }
  writer.to_bytes()
}

///|
fn @bytecodec.ByteWriter::write_callable_abi(
  self : @bytecodec.ByteWriter,
  abi : CallableAbi,
) -> Unit {
  self.write_u32_le_int(abi.witness_count)
  self.write_u32_le_int(abi.parameters.length())
  for parameter in abi.parameters {
    self.write_representation(parameter.representation)
    self.write_cleanup(parameter.cleanup)
    self.write_semantic_value_kind(parameter.kind)
  }
  self.write_result_abi(abi.result)
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
      self.write_u32_le_int(import_.abi_major)
      self.write_u32_le_int(import_.parameters.length())
      for parameter in import_.parameters {
        self.write_runtime_value_kind(parameter)
      }
      self.write_runtime_value_kind(import_.result)
      self.write_bytes(@utf8.encode(import_.symbol))
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_runtime_value_kind(
  self : @bytecodec.ByteWriter,
  kind : RuntimeValueKind,
) -> Unit {
  self.write_u8(
    match kind {
      Unit => 0x00
      Bool => 0x01
      I64 => 0x02
      F64 => 0x03
      String => 0x04
      Opaque => 0x05
      F32 => 0x06
    },
  )
}

///|
fn @bytecodec.ByteWriter::write_function_body(
  self : @bytecodec.ByteWriter,
  body : FunctionBody,
) -> Unit {
  let payload = @bytecodec.ByteWriter::new()
  payload.write_u32_le_int(body.slots.length())
  for slot in body.slots {
    payload.write_slot_metadata(slot)
  }
  payload.write_optional_slot(body.inputs.environment)
  payload.write_slot_ids(body.inputs.witnesses)
  payload.write_slot_ids(body.inputs.user_parameters)
  payload.write_result_abi(body.result)
  payload.write_u32_le_int(body.blocks.length())
  for block in body.blocks {
    payload.write_block(block)
  }
  let bytes = payload.to_bytes()
  self.write_u32_le_int(bytes.length())
  self.write_raw_bytes(bytes)
}

///|
fn @bytecodec.ByteWriter::write_slot_metadata(
  self : @bytecodec.ByteWriter,
  slot : SlotMetadata,
) -> Unit {
  self.write_representation(slot.representation)
  self.write_cleanup(slot.cleanup)
  self.write_semantic_value_kind(slot.kind)
  if slot.cleanup is OwnedErased {
    match slot.erased_companion {
      Some(companion) => self.write_slot_id(companion)
      None => self.write_u32_le_int(0)
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
  self.write_semantic_value_kind(global.kind)
  if global.cleanup is OwnedErased {
    match global.erased_companion {
      Some(companion) => self.write_global_id(companion)
      None => self.write_u32_le_int(0)
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
      F32 => 0x04
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
fn @bytecodec.ByteWriter::write_semantic_value_kind(
  self : @bytecodec.ByteWriter,
  kind : SemanticValueKind,
) -> Unit {
  match kind {
    ScalarValue => self.write_u8(0x01)
    LayoutValue => self.write_u8(0x02)
    CallableValue => self.write_u8(0x03)
    ByteSequenceValue => self.write_u8(0x04)
    DataValue(family) => {
      self.write_u8(0x05)
      self.write_u32_le_int(family.value)
    }
    EnvironmentValue(shape) => {
      self.write_u8(0x06)
      self.write_object_shape_id(shape)
    }
    OpaqueReferenceValue => self.write_u8(0x07)
    ErasedValue => self.write_u8(0x08)
    AbstractReferenceValue(parameter) => {
      self.write_u8(0x09)
      self.write_u32_le_int(parameter)
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_result_abi(
  self : @bytecodec.ByteWriter,
  result : ResultAbi,
) -> Unit {
  match result {
    Unit => self.write_u8(0x01)
    Value(representation, cleanup, kind) => {
      self.write_u8(0x02)
      self.write_representation(representation)
      self.write_cleanup(cleanup)
      self.write_semantic_value_kind(kind)
    }
  }
}

///|
fn @bytecodec.ByteWriter::write_layout_recipe(
  self : @bytecodec.ByteWriter,
  layout : LayoutRecipe,
) -> Unit {
  match layout {
    Unit => self.write_u8(0x01)
    Bool => self.write_u8(0x02)
    I64 => self.write_u8(0x03)
    F64 => self.write_u8(0x04)
    Callable => self.write_u8(0x05)
    ByteSequence => self.write_u8(0x06)
    Data(shape) => {
      self.write_u8(0x07)
      self.write_object_shape_id(shape)
    }
    Environment(shape) => {
      self.write_u8(0x08)
      self.write_object_shape_id(shape)
    }
    Reference => self.write_u8(0x09)
    Byte => self.write_u8(0x0A)
    I32 => self.write_u8(0x0C)
    Char => self.write_u8(0x0D)
    F32 => self.write_u8(0x0E)
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
      self.write_u32_le_int(data.family.value)
      self.write_u32_le_int(data.constructor_tag)
      self.write_u32_le_int(data.stored_witness_count)
      self.write_u32_le_int(data.members.length())
      for schema in data.members {
        self.write_member_schema(schema)
      }
    }
    Environment(environment) => {
      self.write_u8(0x02)
      self.write_u32_le_int(environment.stored_witness_count)
      self.write_u32_le_int(environment.members.length())
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
  self.write_semantic_value_kind(schema.kind)
  match schema.witness_ordinal {
    None => self.write_u32_le_int(0)
    Some(ordinal) => self.write_u32_le_int(ordinal + 1)
  }
}

///|
fn @bytecodec.ByteWriter::write_block(
  self : @bytecodec.ByteWriter,
  block : Block,
) -> Unit {
  self.write_slot_ids(block.parameters)
  self.write_u32_le_int(block.instructions.length())
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
    ConstI64(destination, value) => {
      self.write_u8(0x05)
      self.write_slot_id(destination)
      self.write_i64_le(value)
    }
    ConstF64(destination, bits) => {
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
    CallValue(callable, abi, witnesses, arguments, destination) => {
      self.write_u8(0x0C)
      self.write_slot_id(callable)
      self.write_callable_abi_id(abi)
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
      self.write_u32_le_int(index)
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
      self.write_u32_le_int(index)
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
    I64Add(destination, left, right) =>
      self.write_ternary_slots(0x19, destination, left, right)
    I64Sub(destination, left, right) =>
      self.write_ternary_slots(0x1A, destination, left, right)
    I64Mul(destination, left, right) =>
      self.write_ternary_slots(0x1B, destination, left, right)
    I64Neg(destination, source) =>
      self.write_binary_slots(0x1C, destination, source)
    I64Div(destination, left, right) =>
      self.write_ternary_slots(0x1D, destination, left, right)
    I64Rem(destination, left, right) =>
      self.write_ternary_slots(0x1E, destination, left, right)
    I64And(destination, left, right) =>
      self.write_ternary_slots(0x1F, destination, left, right)
    I64Or(destination, left, right) =>
      self.write_ternary_slots(0x20, destination, left, right)
    I64Xor(destination, left, right) =>
      self.write_ternary_slots(0x21, destination, left, right)
    I64Not(destination, source) =>
      self.write_binary_slots(0x22, destination, source)
    I64Shl(destination, left, right) =>
      self.write_ternary_slots(0x23, destination, left, right)
    I64ShrS(destination, left, right) =>
      self.write_ternary_slots(0x24, destination, left, right)
    I64Eq(destination, left, right) =>
      self.write_ternary_slots(0x25, destination, left, right)
    I64Ne(destination, left, right) =>
      self.write_ternary_slots(0x26, destination, left, right)
    I64Lt(destination, left, right) =>
      self.write_ternary_slots(0x27, destination, left, right)
    I64Le(destination, left, right) =>
      self.write_ternary_slots(0x28, destination, left, right)
    I64Gt(destination, left, right) =>
      self.write_ternary_slots(0x29, destination, left, right)
    I64Ge(destination, left, right) =>
      self.write_ternary_slots(0x2A, destination, left, right)
    BoolNot(destination, source) =>
      self.write_binary_slots(0x2B, destination, source)
    BoolEq(destination, left, right) =>
      self.write_ternary_slots(0x2C, destination, left, right)
    BoolNe(destination, left, right) =>
      self.write_ternary_slots(0x2D, destination, left, right)
    F64Add(destination, left, right) =>
      self.write_ternary_slots(0x2E, destination, left, right)
    F64Sub(destination, left, right) =>
      self.write_ternary_slots(0x2F, destination, left, right)
    F64Mul(destination, left, right) =>
      self.write_ternary_slots(0x30, destination, left, right)
    F64Div(destination, left, right) =>
      self.write_ternary_slots(0x31, destination, left, right)
    F64Neg(destination, source) =>
      self.write_binary_slots(0x32, destination, source)
    F64Eq(destination, left, right) =>
      self.write_ternary_slots(0x33, destination, left, right)
    F64Ne(destination, left, right) =>
      self.write_ternary_slots(0x34, destination, left, right)
    F64Lt(destination, left, right) =>
      self.write_ternary_slots(0x35, destination, left, right)
    F64Le(destination, left, right) =>
      self.write_ternary_slots(0x36, destination, left, right)
    F64Gt(destination, left, right) =>
      self.write_ternary_slots(0x37, destination, left, right)
    F64Ge(destination, left, right) =>
      self.write_ternary_slots(0x38, destination, left, right)
    I64ToF64(destination, source) =>
      self.write_binary_slots(0x39, destination, source)
    F64ToI64(destination, source) =>
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
      self.write_u32_le_int(ordinal)
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
    ByteToI64(destination, source) =>
      self.write_binary_slots(0x46, destination, source)
    I64ToByte(destination, source) =>
      self.write_binary_slots(0x47, destination, source)
    ByteSequenceMake(destination, length, fill) =>
      self.write_ternary_slots(0x48, destination, length, fill)
    ByteSequenceLength(destination, source) =>
      self.write_binary_slots(0x49, destination, source)
    ByteSequenceGet(destination, source, index) =>
      self.write_ternary_slots(0x4A, destination, source, index)
    ByteSequenceSet(destination, source, index, value) => {
      self.write_u8(0x4B)
      self.write_slot_id(destination)
      self.write_slot_id(source)
      self.write_slot_id(index)
      self.write_slot_id(value)
    }
    ConstI32(destination, value) => {
      self.write_u8(0x4C)
      self.write_slot_id(destination)
      self.write_i32_le(value)
    }
    I32Add(destination, left, right) =>
      self.write_ternary_slots(0x4D, destination, left, right)
    I32Sub(destination, left, right) =>
      self.write_ternary_slots(0x4E, destination, left, right)
    I32Mul(destination, left, right) =>
      self.write_ternary_slots(0x4F, destination, left, right)
    I32Neg(destination, source) =>
      self.write_binary_slots(0x50, destination, source)
    I32Div(destination, left, right) =>
      self.write_ternary_slots(0x51, destination, left, right)
    I32Rem(destination, left, right) =>
      self.write_ternary_slots(0x52, destination, left, right)
    I32Eq(destination, left, right) =>
      self.write_ternary_slots(0x53, destination, left, right)
    I32Lt(destination, left, right) =>
      self.write_ternary_slots(0x54, destination, left, right)
    I32ToI64(destination, source) =>
      self.write_binary_slots(0x55, destination, source)
    I64ToI32(destination, source) =>
      self.write_binary_slots(0x56, destination, source)
    ConstChar(destination, value) => {
      self.write_u8(0x57)
      self.write_slot_id(destination)
      self.write_i32_le(value)
    }
    ByteSequenceEqual(destination, left, right) =>
      self.write_ternary_slots(0x58, destination, left, right)
    ByteSequenceConcat(destination, left, right) =>
      self.write_ternary_slots(0x59, destination, left, right)
    ByteSequenceSlice(destination, source, start, length) => {
      self.write_u8(0x5A)
      self.write_slot_id(destination)
      self.write_slot_id(source)
      self.write_slot_id(start)
      self.write_slot_id(length)
    }
    ByteSequenceIsValidUtf8(destination, source) =>
      self.write_binary_slots(0x5B, destination, source)
    ConstF32(destination, bits) => {
      self.write_u8(0x5C)
      self.write_slot_id(destination)
      self.write_i32_le(bits)
    }
    F32Add(destination, left, right) =>
      self.write_ternary_slots(0x5D, destination, left, right)
    F32Sub(destination, left, right) =>
      self.write_ternary_slots(0x5E, destination, left, right)
    F32Mul(destination, left, right) =>
      self.write_ternary_slots(0x5F, destination, left, right)
    F32Div(destination, left, right) =>
      self.write_ternary_slots(0x60, destination, left, right)
    F32Neg(destination, source) =>
      self.write_binary_slots(0x61, destination, source)
    F32Eq(destination, left, right) =>
      self.write_ternary_slots(0x62, destination, left, right)
    F32Ne(destination, left, right) =>
      self.write_ternary_slots(0x63, destination, left, right)
    F32Lt(destination, left, right) =>
      self.write_ternary_slots(0x64, destination, left, right)
    F32Le(destination, left, right) =>
      self.write_ternary_slots(0x65, destination, left, right)
    F32Gt(destination, left, right) =>
      self.write_ternary_slots(0x66, destination, left, right)
    F32Ge(destination, left, right) =>
      self.write_ternary_slots(0x67, destination, left, right)
    I64ToF32(destination, source) =>
      self.write_binary_slots(0x68, destination, source)
    F32ToI64(destination, source) =>
      self.write_binary_slots(0x69, destination, source)
    F32ToF64(destination, source) =>
      self.write_binary_slots(0x6A, destination, source)
    F64ToF32(destination, source) =>
      self.write_binary_slots(0x6B, destination, source)
    EraseF32(destination, source) =>
      self.write_binary_slots(0x6C, destination, source)
    UneraseF32(destination, source) =>
      self.write_binary_slots(0x6D, destination, source)
    F32ToString(destination, source) =>
      self.write_binary_slots(0x6E, destination, source)
    F64ToString(destination, source) =>
      self.write_binary_slots(0x6F, destination, source)
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
      self.write_u32_le_int(cases.length())
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
    TailCallValue(callable, abi, witnesses, arguments) => {
      self.write_u8(0x06)
      self.write_slot_id(callable)
      self.write_callable_abi_id(abi)
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
  self.write_u32_le_int(selections.length())
  for selection in selections {
    self.write_u32_le_int(selection.member_index)
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
  self.write_u32_le_int(slots.length())
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
    None => self.write_u32_le_int(0)
    Some(slot) => self.write_u32_le_int(slot.value + 1)
  }
}

///|
fn @bytecodec.ByteWriter::write_function_id(
  self : @bytecodec.ByteWriter,
  id : FunctionId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_callable_abi_id(
  self : @bytecodec.ByteWriter,
  id : CallableAbiId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_optional_function_id(
  self : @bytecodec.ByteWriter,
  id : FunctionId?,
) -> Unit {
  match id {
    None => self.write_u32_le_int(0)
    Some(id) => self.write_function_id(id)
  }
}

///|
fn @bytecodec.ByteWriter::write_global_id(
  self : @bytecodec.ByteWriter,
  id : GlobalId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_layout_id(
  self : @bytecodec.ByteWriter,
  id : LayoutId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_block_id(
  self : @bytecodec.ByteWriter,
  id : BlockId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_slot_id(
  self : @bytecodec.ByteWriter,
  id : SlotId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_constant_id(
  self : @bytecodec.ByteWriter,
  id : ConstantId,
) -> Unit {
  self.write_u32_le_int(id.value)
}

///|
fn @bytecodec.ByteWriter::write_object_shape_id(
  self : @bytecodec.ByteWriter,
  id : ObjectShapeId,
) -> Unit {
  self.write_u32_le_int(id.value)
}
