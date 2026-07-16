///|
pub(all) suberror BytecodeDecodeError {
  MalformedEncoding(offset~ : Int, detail~ : String)
  ResourceLimit(offset~ : Int, detail~ : String)
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
    validate_ascii_bytes(constant, offset=offset + 4, what="String constant")
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
  validate_local_metadata(image)
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
  let user_arity = self.read_nonnegative_u32(
    expected="runtime import user arity",
  )
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
  { abi_major, user_arity, symbol }
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
    0x03 => Int
    0x04 => Double
    0x05 => Callable
    0x06 => String
    0x07 => Data(self.read_object_shape_id())
    0x08 => Environment(self.read_object_shape_id())
    0x09 => Reference
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
      ConstInt(self.read_slot_id(), self.read_i64(expected="Int constant"))
    0x06 =>
      ConstDouble(self.read_slot_id(), self.read_i64(expected="Double bits"))
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
    0x15 => StringLength(self.read_slot_id(), self.read_slot_id())
    0x16 =>
      StringConcat(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x17 =>
      StringSlice(
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
        self.read_slot_id(),
      )
    0x18 =>
      StringEq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x19 =>
      IntAdd(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1A =>
      IntSub(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1B =>
      IntMul(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1C => IntNeg(self.read_slot_id(), self.read_slot_id())
    0x1D =>
      IntDiv(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1E =>
      IntRem(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x1F =>
      IntAnd(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x20 => IntOr(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x21 =>
      IntXor(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x22 => IntNot(self.read_slot_id(), self.read_slot_id())
    0x23 =>
      IntShl(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x24 =>
      IntShrS(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x25 => IntEq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x26 => IntNe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x27 => IntLt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x28 => IntLe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x29 => IntGt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2A => IntGe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2B => BoolNot(self.read_slot_id(), self.read_slot_id())
    0x2C =>
      BoolEq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2D =>
      BoolNe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2E =>
      DoubleAdd(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x2F =>
      DoubleSub(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x30 =>
      DoubleMul(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x31 =>
      DoubleDiv(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x32 => DoubleNeg(self.read_slot_id(), self.read_slot_id())
    0x33 =>
      DoubleEq(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x34 =>
      DoubleNe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x35 =>
      DoubleLt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x36 =>
      DoubleLe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x37 =>
      DoubleGt(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x38 =>
      DoubleGe(self.read_slot_id(), self.read_slot_id(), self.read_slot_id())
    0x39 => IntToDouble(self.read_slot_id(), self.read_slot_id())
    0x3A => DoubleToInt(self.read_slot_id(), self.read_slot_id())
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
fn validate_local_metadata(
  image : BytecodeImage,
) -> Unit raise BytecodeDecodeError {
  validate_root_function(
    image.functions,
    image.entry,
    offset=0,
    what="selected entry",
  )
  match image.initializer {
    Some(initializer) =>
      validate_root_function(
        image.functions,
        initializer,
        offset=4,
        what="instance initializer",
      )
    None =>
      if !image.globals.is_empty() {
        raise MalformedEncoding(
          offset=4,
          detail="nonempty instance global table requires an initializer",
        )
      }
  }
  validate_global_metadata(image.globals)
  for entry in image.functions {
    if entry is BytecodeBody(body) {
      validate_function_body_metadata(body)
    }
  }
  for layout in image.layouts {
    match layout {
      Data(shape) =>
        validate_shape_reference(image.object_shapes, shape, data=true)
      Environment(shape) =>
        validate_shape_reference(image.object_shapes, shape, data=false)
      _ => ()
    }
  }
  for shape in image.object_shapes {
    match shape {
      Data(data) =>
        validate_member_schemas(data.members, data.stored_witness_count)
      Environment(environment) =>
        validate_member_schemas(
          environment.members,
          environment.stored_witness_count,
        )
    }
  }
}

///|
fn validate_root_function(
  functions : Array[FunctionEntry],
  function : FunctionId,
  offset~ : Int,
  what~ : String,
) -> Unit raise BytecodeDecodeError {
  if function.value <= 0 || function.value > functions.length() {
    raise MalformedEncoding(
      offset~,
      detail="\{what} FunctionId is out of range",
    )
  }
  match functions[function.value - 1] {
    BytecodeBody(body) =>
      if body.inputs.environment is Some(_) ||
        !body.inputs.witnesses.is_empty() ||
        !body.inputs.user_parameters.is_empty() ||
        body.result != Unit {
        raise MalformedEncoding(
          offset~,
          detail="\{what} must be a no-context, zero-argument Unit bytecode body",
        )
      }
    RuntimeImport(_) =>
      raise MalformedEncoding(offset~, detail="\{what} must be a bytecode body")
  }
}

///|
fn validate_global_metadata(
  globals : Array[GlobalMetadata],
) -> Unit raise BytecodeDecodeError {
  for index, global in globals {
    let legal = match (global.representation, global.cleanup) {
      (I32, Trivial | OwnedRef) => true
      (I64, Trivial | OwnedCallable | OwnedErased) => true
      (F64, Trivial) => true
      _ => false
    }
    if !legal {
      raise MalformedEncoding(
        offset=0,
        detail="illegal global representation and cleanup combination",
      )
    }
    match (global.cleanup, global.erased_companion) {
      (OwnedErased, Some(companion)) => {
        if index == 0 || companion.value != index - 1 {
          raise MalformedEncoding(
            offset=0,
            detail="OwnedErased global companion must immediately precede its owner",
          )
        }
        let companion_global = globals[companion.value]
        if companion_global.representation != I32 ||
          companion_global.cleanup != Trivial ||
          companion_global.erased_companion is Some(_) {
          raise MalformedEncoding(
            offset=0,
            detail="erased global companion must be an I32 Trivial global",
          )
        }
      }
      (OwnedErased, None) =>
        raise MalformedEncoding(
          offset=0,
          detail="OwnedErased global requires a companion",
        )
      (_, Some(_)) =>
        raise MalformedEncoding(
          offset=0,
          detail="only OwnedErased globals have companions",
        )
      _ => ()
    }
  }
}

///|
fn validate_function_body_metadata(
  body : FunctionBody,
) -> Unit raise BytecodeDecodeError {
  if !body.blocks[0].parameters.is_empty() {
    raise MalformedEncoding(
      offset=0,
      detail="entry block must have no parameters",
    )
  }
  for slot in body.slots {
    let legal = match (slot.representation, slot.cleanup) {
      (I32, Trivial | OwnedRef) => true
      (I64, Trivial | OwnedCallable | OwnedErased) => true
      (F64, Trivial) => true
      _ => false
    }
    if !legal {
      raise MalformedEncoding(
        offset=0,
        detail="illegal slot representation and cleanup combination",
      )
    }
    match (slot.cleanup, slot.erased_companion) {
      (OwnedErased, Some(companion)) => {
        if companion.value < 0 || companion.value >= body.slots.length() {
          raise MalformedEncoding(
            offset=0,
            detail="erased companion SlotId is out of range",
          )
        }
        let companion_slot = body.slots[companion.value]
        if companion_slot.representation != I32 ||
          companion_slot.cleanup != Trivial {
          raise MalformedEncoding(
            offset=0,
            detail="erased companion must name an I32 Trivial slot",
          )
        }
      }
      (OwnedErased, None) =>
        raise MalformedEncoding(
          offset=0,
          detail="OwnedErased slot requires a companion",
        )
      (_, Some(_)) =>
        raise MalformedEncoding(
          offset=0,
          detail="only OwnedErased slots have companions",
        )
      _ => ()
    }
  }
}

///|
fn validate_shape_reference(
  shapes : Array[ObjectShape],
  id : ObjectShapeId,
  data~ : Bool,
) -> Unit raise BytecodeDecodeError {
  if id.value < 0 || id.value >= shapes.length() {
    raise MalformedEncoding(
      offset=0,
      detail="layout recipe ObjectShapeId is out of range",
    )
  }
  match (data, shapes[id.value]) {
    (true, Data(_)) | (false, Environment(_)) => ()
    _ =>
      raise MalformedEncoding(
        offset=0,
        detail="layout recipe references the wrong object shape variant",
      )
  }
}

///|
fn validate_member_schemas(
  schemas : Array[MemberSchema],
  stored_witness_count : Int,
) -> Unit raise BytecodeDecodeError {
  for schema in schemas {
    let legal = match (schema.representation, schema.cleanup) {
      (I32 | I64 | F64, Trivial) => schema.witness_ordinal is None
      (I32, OwnedRef) => schema.witness_ordinal is None
      (I64, OwnedCallable) => schema.witness_ordinal is None
      (I64, OwnedErased) =>
        match schema.witness_ordinal {
          Some(ordinal) => ordinal >= 0 && ordinal < stored_witness_count
          None => false
        }
      _ => false
    }
    if !legal {
      raise MalformedEncoding(offset=0, detail="illegal object member schema")
    }
  }
}
