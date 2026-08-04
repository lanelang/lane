///|
pub(all) suberror BytecodeDecodeError {
  MalformedEncoding(offset~ : Int, detail~ : String)
  ResourceLimit(offset~ : Int, detail~ : String)
  InvalidBytecode(error~ : BytecodeVerificationError)
} derive(Debug, Eq)

///|
priv struct Decoder {
  reader : @bytecodec.ByteReader
}

///|
pub fn parse_bytecode_image_binary(
  bytes : Bytes,
) -> Result[BytecodeImage, BytecodeDecodeError] {
  Ok(decode_bytecode_image(bytes)) catch {
    error => Err(error)
  }
}

///|
fn decode_bytecode_image(
  bytes : Bytes,
) -> BytecodeImage raise BytecodeDecodeError {
  let decoder = Decoder::{ reader: @bytecodec.ByteReader::from_bytes(bytes) }
  let entry = decoder.read_function_id()
  let initializer = decoder.read_optional_function_id()
  let function_count_offset = decoder.offset()
  let function_count = decoder.read_count(minimum_size=1, table="function")
  if function_count == 0 {
    decoder.fail_at(function_count_offset, "function table must be nonempty")
  }
  let functions : Array[FunctionEntry] = []
  for _index in 0..<function_count {
    functions.push(decoder.read_function_entry())
  }
  let globals : Array[GlobalMetadata] = []
  let global_count = decoder.read_count(minimum_size=2, table="instance global")
  for _index in 0..<global_count {
    globals.push(decoder.read_global_metadata())
  }
  let layout_count = decoder.read_count(minimum_size=1, table="layout")
  let layouts : Array[LayoutRecipe] = []
  for _index in 0..<layout_count {
    layouts.push(decoder.read_layout_recipe())
  }
  let shape_count = decoder.read_count(minimum_size=1, table="object shape")
  let object_shapes : Array[ObjectShape] = []
  for _index in 0..<shape_count {
    object_shapes.push(decoder.read_object_shape())
  }
  let constant_count = decoder.read_count(minimum_size=4, table="constant")
  let constants : Array[Bytes] = []
  for _index in 0..<constant_count {
    let offset = decoder.offset()
    let constant = decoder.read_bytes(expected="String constant")
    validate_utf8_bytes(constant, offset=offset + 4, what="String constant")
    constants.push(constant)
  }
  decoder.expect_end(what="bytecode section")
  let image : BytecodeImage = {
    entry,
    initializer,
    functions,
    globals,
    layouts,
    object_shapes,
    constants,
  }
  match verify_bytecode_image(image) {
    Ok(_) => ()
    Err(error) => raise InvalidBytecode(error~)
  }
  image
}

///|
fn Decoder::read_function_entry(
  self : Decoder,
) -> FunctionEntry raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="function entry tag") {
    0x01 => BytecodeBody(self.read_function_body())
    0x02 => RuntimeImport(self.read_runtime_import())
    tag => self.invalid_tag(offset~, domain="function entry", tag~)
  }
}

///|
fn Decoder::read_runtime_import(
  self : Decoder,
) -> RuntimeImport raise BytecodeDecodeError {
  let abi_major = self.read_nonnegative_u32(expected="runtime import ABI major")
  let parameter_count = self.read_nonnegative_u32(
    expected="runtime import parameter count",
  )
  let parameters = []
  for _ in 0..<parameter_count {
    parameters.push(self.read_runtime_value_kind())
  }
  let result = self.read_runtime_value_kind()
  let symbol_offset = self.offset()
  let symbol_bytes = self.read_bytes(expected="runtime import symbol")
  if symbol_bytes.length() == 0 {
    self.fail_at(symbol_offset + 4, "runtime import symbol must be nonempty")
  }
  validate_ascii_bytes(
    symbol_bytes,
    offset=symbol_offset + 4,
    what="runtime import symbol",
  )
  for index, byte in symbol_bytes {
    if byte == b'\x00' {
      self.fail_at(
        symbol_offset + 4 + index,
        "runtime import symbol must not contain NUL",
      )
    }
  }
  let symbol = @utf8.decode(symbol_bytes) catch {
    _ => self.fail_at(symbol_offset + 4, "runtime import symbol is not ASCII")
  }
  { abi_major, parameters, result, symbol }
}

///|
fn Decoder::read_runtime_value_kind(
  self : Decoder,
) -> RuntimeValueKind raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="runtime value kind") {
    0x00 => Unit
    0x01 => Bool
    0x02 => I64
    0x03 => F64
    0x04 => String
    0x05 => Opaque
    0x06 => F32
    tag => self.invalid_tag(offset~, domain="runtime value kind", tag~)
  }
}

///|
fn Decoder::read_function_body(
  self : Decoder,
) -> FunctionBody raise BytecodeDecodeError {
  let length_offset = self.offset()
  let body_length = self.read_nonnegative_u32(expected="function body length")
  if body_length > self.remaining() {
    self.fail_at(
      length_offset, "function body exceeds enclosing bytecode section",
    )
  }
  let body_reader = self.reader.read_section(
    body_length,
    expected="function body",
  ) catch {
    _ =>
      self.fail_at(
        length_offset, "function body exceeds enclosing bytecode section",
      )
  }
  let body_decoder = Decoder::{ reader: body_reader }
  let slot_count = body_decoder.read_count(minimum_size=2, table="slot")
  let slots : Array[SlotMetadata] = []
  for _index in 0..<slot_count {
    slots.push(body_decoder.read_slot_metadata())
  }
  let inputs : FunctionInputs = {
    environment: body_decoder.read_optional_slot(),
    witnesses: body_decoder.read_slot_ids(),
    user_parameters: body_decoder.read_slot_ids(),
  }
  let result = body_decoder.read_result_representation()
  let block_count = body_decoder.read_count(minimum_size=9, table="block")
  if block_count == 0 {
    body_decoder.fail("block table must be nonempty")
  }
  let blocks : Array[Block] = []
  for _index in 0..<block_count {
    blocks.push(body_decoder.read_block())
  }
  body_decoder.expect_end(what="function body")
  { slots, inputs, result, blocks }
}

///|
fn Decoder::read_slot_metadata(
  self : Decoder,
) -> SlotMetadata raise BytecodeDecodeError {
  let representation = self.read_representation()
  let cleanup = self.read_cleanup()
  let erased_companion = if cleanup is OwnedErased {
    Some(self.read_slot_id())
  } else {
    None
  }
  { representation, cleanup, erased_companion }
}

///|
fn Decoder::read_global_metadata(
  self : Decoder,
) -> GlobalMetadata raise BytecodeDecodeError {
  let representation = self.read_representation()
  let cleanup = self.read_cleanup()
  let erased_companion = if cleanup is OwnedErased {
    Some(self.read_global_id())
  } else {
    None
  }
  { representation, cleanup, erased_companion }
}

///|
fn Decoder::read_representation(
  self : Decoder,
) -> Representation raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="representation tag") {
    0x01 => I32
    0x02 => I64
    0x03 => F64
    0x04 => F32
    tag => self.invalid_tag(offset~, domain="representation", tag~)
  }
}

///|
fn Decoder::read_cleanup(self : Decoder) -> Cleanup raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="cleanup tag") {
    0x01 => Trivial
    0x02 => OwnedRef
    0x03 => OwnedCallable
    0x04 => OwnedErased
    tag => self.invalid_tag(offset~, domain="cleanup", tag~)
  }
}

///|
fn Decoder::read_result_representation(
  self : Decoder,
) -> ResultRepresentation raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="result tag") {
    0x01 => Unit
    0x02 => I32
    0x03 => I64
    0x04 => F64
    0x05 => F32
    tag => self.invalid_tag(offset~, domain="result", tag~)
  }
}

///|
fn Decoder::read_layout_recipe(
  self : Decoder,
) -> LayoutRecipe raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="layout recipe tag") {
    0x01 => Unit
    0x02 => Bool
    0x03 => I64
    0x04 => F64
    0x05 => Callable
    0x06 => ByteSequence
    0x07 => Data(self.read_object_shape_id())
    0x08 => Environment(self.read_object_shape_id())
    0x09 => Reference
    0x0A => Byte
    0x0C => I32
    0x0D => Char
    0x0E => F32
    tag => self.invalid_tag(offset~, domain="layout recipe", tag~)
  }
}

///|
fn Decoder::read_object_shape(
  self : Decoder,
) -> ObjectShape raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="object shape tag") {
    0x01 => {
      let constructor_tag = self.read_nonnegative_u32(
        expected="constructor tag",
      )
      let stored_witness_count = self.read_nonnegative_u32(
        expected="stored witness count",
      )
      let members = self.read_member_schemas()
      Data({ constructor_tag, stored_witness_count, members })
    }
    0x02 => {
      let stored_witness_count = self.read_nonnegative_u32(
        expected="stored witness count",
      )
      let members = self.read_member_schemas()
      Environment({ stored_witness_count, members })
    }
    tag => self.invalid_tag(offset~, domain="object shape", tag~)
  }
}

///|
fn Decoder::read_member_schemas(
  self : Decoder,
) -> Array[MemberSchema] raise BytecodeDecodeError {
  let count = self.read_count(minimum_size=6, table="object member")
  let schemas : Array[MemberSchema] = []
  for _index in 0..<count {
    let representation = self.read_representation()
    let cleanup = self.read_cleanup()
    let witness_plus_one = self.read_nonnegative_u32(expected="witness ordinal")
    schemas.push({
      representation,
      cleanup,
      witness_ordinal: if witness_plus_one == 0 {
        None
      } else {
        Some(witness_plus_one - 1)
      },
    })
  }
  schemas
}

///|
fn Decoder::read_block(self : Decoder) -> Block raise BytecodeDecodeError {
  let parameters = self.read_slot_ids()
  let instruction_count = self.read_count(minimum_size=5, table="instruction")
  let instructions : Array[Instruction] = []
  for _index in 0..<instruction_count {
    instructions.push(self.read_instruction())
  }
  let terminator = self.read_terminator()
  { parameters, instructions, terminator }
}

///|
fn Decoder::read_instruction(
  self : Decoder,
) -> Instruction raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="instruction tag") {
    0x01 => Copy(self.read_slot_id(), self.read_slot_id())
    0x02 => Move(self.read_slot_id(), self.read_slot_id())
    0x03 => RetainCopy(self.read_slot_id(), self.read_slot_id())
    0x04 => Release(self.read_slot_id())
    0x05 =>
      ConstI64(self.read_slot_id(), self.read_i64(expected="I64 constant"))
    0x06 => ConstF64(self.read_slot_id(), self.read_i64(expected="F64 bits"))
    0x07 => ConstBool(self.read_slot_id(), self.read_bool())
    0x08 => ConstLayout(self.read_slot_id(), self.read_layout_id())
    0x09 => ConstFunction(self.read_slot_id(), self.read_function_id())
    0x0A => ConstString(self.read_slot_id(), self.read_constant_id())
    0x0B =>
      CallDirect(
        self.read_function_id(),
        self.read_optional_slot(),
        self.read_slot_ids(),
        self.read_slot_ids(),
        self.read_optional_slot(),
      )
    0x0C =>
      CallValue(
        self.read_slot_id(),
        self.read_slot_ids(),
        self.read_slot_ids(),
        self.read_optional_slot(),
      )
    0x0D =>
      MakeData(
        self.read_slot_id(),
        self.read_object_shape_id(),
        self.read_layout_operand(),
        self.read_slot_ids(),
        self.read_slot_ids(),
      )
    0x0E => LoadTag(self.read_slot_id(), self.read_slot_id())
    0x0F =>
      BorrowField(
        self.read_object_shape_id(),
        self.read_slot_id(),
        self.read_nonnegative_u32(expected="field index"),
        self.read_projection_result(),
      )
    0x10 =>
      ConsumeFields(
        self.read_object_shape_id(),
        self.read_slot_id(),
        self.read_projection_selections(what="field"),
      )
    0x11 =>
      MakeEnv(
        self.read_slot_id(),
        self.read_object_shape_id(),
        self.read_layout_operand(),
        self.read_slot_ids(),
        self.read_slot_ids(),
      )
    0x12 =>
      BorrowCapture(
        self.read_object_shape_id(),
        self.read_slot_id(),
        self.read_nonnegative_u32(expected="capture index"),
        self.read_projection_result(),
      )
    0x13 =>
      ConsumeCaptures(
        self.read_object_shape_id(),
        self.read_slot_id(),
        self.read_projection_selections(what="capture"),
      )
    0x14 =>
      MakeClosure(
        self.read_slot_id(),
        self.read_function_id(),
        self.read_slot_id(),
      )
    0x19 =>
      I64Add(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1A =>
      I64Sub(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1B =>
      I64Mul(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1C => I64Neg(self.read_slot_id(), self.read_slot_id())
    0x1D =>
      I64Div(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1E =>
      I64Rem(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1F =>
      I64And(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x20 => I64Or(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x21 =>
      I64Xor(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x22 => I64Not(self.read_slot_id(), self.read_slot_id())
    0x23 =>
      I64Shl(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x24 =>
      I64ShrS(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x25 => I64Eq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x26 => I64Ne(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x27 => I64Lt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x28 => I64Le(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x29 => I64Gt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2A => I64Ge(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2B => BoolNot(self.read_slot_id(), self.read_slot_id())
    0x2C =>
      BoolEq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2D =>
      BoolNe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2E =>
      F64Add(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2F =>
      F64Sub(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x30 =>
      F64Mul(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x31 =>
      F64Div(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x32 => F64Neg(self.read_slot_id(), self.read_slot_id())
    0x33 => F64Eq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x34 => F64Ne(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x35 => F64Lt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x36 => F64Le(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x37 => F64Gt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x38 => F64Ge(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x39 => I64ToF64(self.read_slot_id(), self.read_slot_id())
    0x3A => F64ToI64(self.read_slot_id(), self.read_slot_id())
    0x3B => EraseI32(self.read_slot_id(), self.read_slot_id())
    0x3C => UneraseI32(self.read_slot_id(), self.read_slot_id())
    0x3D => EraseI64(self.read_slot_id(), self.read_slot_id())
    0x3E => UneraseI64(self.read_slot_id(), self.read_slot_id())
    0x3F => EraseF64(self.read_slot_id(), self.read_slot_id())
    0x40 => UneraseF64(self.read_slot_id(), self.read_slot_id())
    0x41 => EraseUnit(self.read_slot_id())
    0x42 => UneraseUnit(self.read_slot_id())
    0x43 =>
      LoadObjectWitness(
        self.read_slot_id(),
        self.read_object_shape_id(),
        self.read_slot_id(),
        self.read_nonnegative_u32(expected="witness ordinal"),
      )
    0x44 => InitGlobal(self.read_global_id(), self.read_slot_id())
    0x45 => BorrowGlobal(self.read_slot_id(), self.read_global_id())
    0x46 => ByteToI64(self.read_slot_id(), self.read_slot_id())
    0x47 => I64ToByte(self.read_slot_id(), self.read_slot_id())
    0x48 =>
      ByteSequenceMake(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x49 => ByteSequenceLength(self.read_slot_id(), self.read_slot_id())
    0x4A =>
      ByteSequenceGet(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x4B =>
      ByteSequenceSet(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x4C =>
      ConstI32(self.read_slot_id(), self.read_i32(expected="I32 constant"))
    0x4D =>
      I32Add(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x4E =>
      I32Sub(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x4F =>
      I32Mul(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x50 => I32Neg(self.read_slot_id(), self.read_slot_id())
    0x51 =>
      I32Div(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x52 =>
      I32Rem(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x53 => I32Eq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x54 => I32Lt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x55 => I32ToI64(self.read_slot_id(), self.read_slot_id())
    0x56 => I64ToI32(self.read_slot_id(), self.read_slot_id())
    0x57 => {
      let destination = self.read_slot_id()
      let value_offset = self.offset()
      let value = self.read_i32(expected="Char constant")
      guard value.to_char() is Some(scalar) else {
        self.fail_at(
          value_offset,
          "Char constant \{value} is not a Unicode scalar value",
        )
      }
      ConstChar(destination, scalar.to_int())
    }
    0x58 =>
      ByteSequenceEqual(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x59 =>
      ByteSequenceConcat(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x5A =>
      ByteSequenceSlice(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x5B => ByteSequenceIsValidUtf8(self.read_slot_id(), self.read_slot_id())
    0x5C => ConstF32(self.read_slot_id(), self.read_i32(expected="F32 bits"))
    0x5D =>
      F32Add(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x5E =>
      F32Sub(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x5F =>
      F32Mul(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x60 =>
      F32Div(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x61 => F32Neg(self.read_slot_id(), self.read_slot_id())
    0x62 => F32Eq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x63 => F32Ne(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x64 => F32Lt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x65 => F32Le(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x66 => F32Gt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x67 => F32Ge(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x68 => I64ToF32(self.read_slot_id(), self.read_slot_id())
    0x69 => F32ToI64(self.read_slot_id(), self.read_slot_id())
    0x6A => F32ToF64(self.read_slot_id(), self.read_slot_id())
    0x6B => F64ToF32(self.read_slot_id(), self.read_slot_id())
    0x6C => EraseF32(self.read_slot_id(), self.read_slot_id())
    0x6D => UneraseF32(self.read_slot_id(), self.read_slot_id())
    0x6E => F32ToString(self.read_slot_id(), self.read_slot_id())
    0x6F => F64ToString(self.read_slot_id(), self.read_slot_id())
    tag => self.invalid_tag(offset~, domain="instruction", tag~)
  }
}

///|
fn Decoder::read_terminator(
  self : Decoder,
) -> Terminator raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="terminator tag") {
    0x01 => Jump(self.read_edge())
    0x02 => BranchBool(self.read_slot_id(), self.read_edge(), self.read_edge())
    0x03 => {
      let tag_slot = self.read_slot_id()
      let case_count = self.read_count(minimum_size=8, table="switch case")
      let cases : Array[Edge] = []
      for _index in 0..<case_count {
        cases.push(self.read_edge())
      }
      SwitchTag(tag_slot, cases, self.read_edge())
    }
    0x04 => Return(self.read_optional_slot())
    0x05 =>
      TailCallDirect(
        self.read_function_id(),
        self.read_optional_slot(),
        self.read_slot_ids(),
        self.read_slot_ids(),
      )
    0x06 =>
      TailCallValue(
        self.read_slot_id(),
        self.read_slot_ids(),
        self.read_slot_ids(),
      )
    0x07 => Unreachable
    tag => self.invalid_tag(offset~, domain="terminator", tag~)
  }
}

///|
fn Decoder::read_edge(self : Decoder) -> Edge raise BytecodeDecodeError {
  { target: self.read_block_id(), arguments: self.read_slot_ids() }
}

///|
fn Decoder::read_layout_operand(
  self : Decoder,
) -> LayoutOperand raise BytecodeDecodeError {
  let offset = self.offset()
  match self.read_tag(expected="layout operand tag") {
    0x01 => Immediate(self.read_layout_id())
    0x02 => Witness(self.read_slot_id())
    tag => self.invalid_tag(offset~, domain="layout operand", tag~)
  }
}

///|
fn Decoder::read_projection_result(
  self : Decoder,
) -> ProjectionResult raise BytecodeDecodeError {
  {
    value_destination: self.read_slot_id(),
    witness_destination: self.read_optional_slot(),
  }
}

///|
fn Decoder::read_projection_selections(
  self : Decoder,
  what~ : String,
) -> Array[ProjectionSelection] raise BytecodeDecodeError {
  let count = self.read_count(minimum_size=12, table="selected \{what}")
  let selections : Array[ProjectionSelection] = []
  let mut previous = -1
  for _index in 0..<count {
    let offset = self.offset()
    let member_index = self.read_nonnegative_u32(expected="\{what} index")
    if member_index <= previous {
      self.fail_at(
        offset,
        "selected \{what} indices must be strictly increasing",
      )
    }
    previous = member_index
    selections.push({ member_index, result: self.read_projection_result() })
  }
  selections
}

///|
fn Decoder::read_slot_ids(
  self : Decoder,
) -> Array[SlotId] raise BytecodeDecodeError {
  let count = self.read_count(minimum_size=4, table="SlotId")
  let slots : Array[SlotId] = []
  for _index in 0..<count {
    slots.push(self.read_slot_id())
  }
  slots
}

///|
fn Decoder::read_optional_slot(
  self : Decoder,
) -> SlotId? raise BytecodeDecodeError {
  let value = self.read_nonnegative_u32(expected="optional SlotId")
  if value == 0 {
    None
  } else {
    Some({ value: value - 1 })
  }
}

///|
fn Decoder::read_function_id(
  self : Decoder,
) -> FunctionId raise BytecodeDecodeError {
  let offset = self.offset()
  let value = self.read_nonnegative_u32(expected="FunctionId")
  if value == 0 {
    self.fail_at(offset, "FunctionId zero is reserved")
  }
  { value, }
}

///|
fn Decoder::read_optional_function_id(
  self : Decoder,
) -> FunctionId? raise BytecodeDecodeError {
  let value = self.read_nonnegative_u32(expected="optional FunctionId")
  if value == 0 {
    None
  } else {
    Some({ value, })
  }
}

///|
fn Decoder::read_global_id(
  self : Decoder,
) -> GlobalId raise BytecodeDecodeError {
  { value: self.read_nonnegative_u32(expected="GlobalId") }
}

///|
fn Decoder::read_layout_id(
  self : Decoder,
) -> LayoutId raise BytecodeDecodeError {
  let offset = self.offset()
  let value = self.read_nonnegative_u32(expected="LayoutId")
  if value == 0 {
    self.fail_at(offset, "LayoutId zero is reserved")
  }
  { value, }
}

///|
fn Decoder::read_block_id(self : Decoder) -> BlockId raise BytecodeDecodeError {
  { value: self.read_nonnegative_u32(expected="BlockId") }
}

///|
fn Decoder::read_slot_id(self : Decoder) -> SlotId raise BytecodeDecodeError {
  { value: self.read_nonnegative_u32(expected="SlotId") }
}

///|
fn Decoder::read_constant_id(
  self : Decoder,
) -> ConstantId raise BytecodeDecodeError {
  { value: self.read_nonnegative_u32(expected="ConstantId") }
}

///|
fn Decoder::read_object_shape_id(
  self : Decoder,
) -> ObjectShapeId raise BytecodeDecodeError {
  { value: self.read_nonnegative_u32(expected="ObjectShapeId") }
}

///|
fn Decoder::read_count(
  self : Decoder,
  minimum_size~ : Int,
  table~ : String,
) -> Int raise BytecodeDecodeError {
  let offset = self.offset()
  let count = self.read_nonnegative_u32(expected="\{table} count")
  if minimum_size > 0 && count > self.remaining() / minimum_size {
    self.fail_at(offset, "\{table} count exceeds enclosing payload")
  }
  count
}

///|
fn Decoder::read_bytes(
  self : Decoder,
  expected~ : String,
) -> Bytes raise BytecodeDecodeError {
  let length_offset = self.offset()
  let length = self.read_nonnegative_u32(expected="\{expected} byte length")
  if length > self.remaining() {
    self.fail_at(length_offset, "\{expected} exceeds enclosing payload")
  }
  self.read_raw_bytes(length, expected~)
}

///|
fn Decoder::read_tag(
  self : Decoder,
  expected~ : String,
) -> Int raise BytecodeDecodeError {
  match self.view() {
    [u8be(value), .. rest] => self.consume(rest, value.reinterpret_as_int())
    _ => self.fail("expected \{expected}")
  }
}

///|
fn Decoder::read_bool(self : Decoder) -> Bool raise BytecodeDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => self.consume(rest, false)
    [u8be(1), .. rest] => self.consume(rest, true)
    [u8be(value), ..] =>
      self.fail_at(
        offset,
        "Bool byte must be zero or one, got \{value.reinterpret_as_int()}",
      )
    _ => self.fail("expected Bool")
  }
}

///|
fn Decoder::read_nonnegative_u32(
  self : Decoder,
  expected~ : String,
) -> Int raise BytecodeDecodeError {
  let offset = self.offset()
  let value = self.reader.read_u32_le() catch {
    _ => self.fail_at(offset, "expected \{expected}")
  }
  if value > 0x7FFFFFFFU {
    raise ResourceLimit(
      offset~,
      detail="\{expected} exceeds implementation limit",
    )
  }
  value.reinterpret_as_int()
}

///|
fn Decoder::read_i64(
  self : Decoder,
  expected~ : String,
) -> Int64 raise BytecodeDecodeError {
  let offset = self.offset()
  self.reader.read_i64_le() catch {
    _ => self.fail_at(offset, "expected \{expected}")
  }
}

///|
fn Decoder::read_i32(
  self : Decoder,
  expected~ : String,
) -> Int raise BytecodeDecodeError {
  let offset = self.offset()
  self.reader.read_i32_le() catch {
    _ => self.fail_at(offset, "expected \{expected}")
  }
}

///|
fn Decoder::read_raw_bytes(
  self : Decoder,
  length : Int,
  expected~ : String,
) -> Bytes raise BytecodeDecodeError {
  let offset = self.offset()
  self.reader.read_raw_bytes(length) catch {
    _ => self.fail_at(offset, "expected \{expected}")
  }
}

///|
fn Decoder::offset(self : Decoder) -> Int {
  self.reader.offset()
}

///|
fn Decoder::remaining(self : Decoder) -> Int {
  self.reader.remaining()
}

///|
fn Decoder::view(self : Decoder) -> BytesView {
  self.reader.view()
}

///|
fn[T] Decoder::consume(self : Decoder, rest : BytesView, value : T) -> T {
  self.consume_rest(rest)
  value
}

///|
fn Decoder::consume_rest(self : Decoder, rest : BytesView) -> Unit {
  self.reader.update_view(rest)
}

///|
fn Decoder::expect_end(
  self : Decoder,
  what~ : String,
) -> Unit raise BytecodeDecodeError {
  if self.remaining() != 0 {
    self.fail("\{what} contains \{self.remaining()} trailing bytes")
  }
}

///|
fn[T] Decoder::invalid_tag(
  self : Decoder,
  offset~ : Int,
  domain~ : String,
  tag~ : Int,
) -> T raise BytecodeDecodeError {
  self.fail_at(offset, "unknown \{domain} tag \{tag}")
}

///|
fn[T] Decoder::fail(
  self : Decoder,
  detail : String,
) -> T raise BytecodeDecodeError {
  self.fail_at(self.offset(), detail)
}

///|
fn[T] Decoder::fail_at(
  self : Decoder,
  offset : Int,
  detail : String,
) -> T raise BytecodeDecodeError {
  ignore(self)
  raise MalformedEncoding(offset~, detail~)
}

///|
fn validate_ascii_bytes(
  bytes : Bytes,
  offset~ : Int,
  what~ : String,
) -> Unit raise BytecodeDecodeError {
  for index, byte in bytes {
    if byte.to_int() > 0x7F {
      raise MalformedEncoding(
        offset=offset + index,
        detail="\{what} must contain ASCII bytes only",
      )
    }
  }
}

///|
fn validate_utf8_bytes(
  bytes : Bytes,
  offset~ : Int,
  what~ : String,
) -> Unit raise BytecodeDecodeError {
  ignore(
    @utf8.decode(bytes) catch {
      _ =>
        raise MalformedEncoding(
          offset~,
          detail="\{what} must contain valid UTF-8",
        )
    },
  )
}
