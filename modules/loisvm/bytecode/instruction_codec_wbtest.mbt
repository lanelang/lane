///|
fn raw_slot(value : Int) -> SlotId {
  { value, }
}

///|
fn raw_function(value : Int) -> FunctionId {
  { value, }
}

///|
fn raw_layout(value : Int) -> LayoutId {
  { value, }
}

///|
fn raw_shape(value : Int) -> ObjectShapeId {
  { value, }
}

///|
fn raw_constant(value : Int) -> ConstantId {
  { value, }
}

///|
fn roundtrip_raw_instruction(
  instruction : Instruction,
) -> Instruction raise BytecodeDecodeError {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_instruction(instruction)
  let decoder = Decoder::{
    reader: @bytecodec.ByteReader::from_bytes(writer.to_bytes()),
  }
  let decoded = decoder.read_instruction()
  decoder.expect_end(what="instruction")
  decoded
}

///|
test "every instruction constructor has a symmetric binary codec" {
  let zero = raw_slot(0)
  let one = raw_slot(1)
  let two = raw_slot(2)
  let projection : ProjectionResult = {
    value_destination: zero,
    witness_destination: Some(one),
  }
  let instructions : Array[Instruction] = [
    Copy(zero, one),
    Move(zero, one),
    RetainCopy(zero, one),
    Release(zero),
    ConstI64(zero, -42L),
    ConstI32(zero, -42),
    ConstChar(zero, 0x1F600),
    ConstF64(two, -1L),
    ConstF32(two, -1),
    ConstBool(zero, true),
    ConstLayout(zero, raw_layout(1)),
    ConstFunction(one, raw_function(1)),
    ConstString(zero, raw_constant(0)),
    CallDirect(raw_function(1), Some(zero), [zero], [one], None),
    CallValue(one, [zero], [one], Some(two)),
    MakeData(zero, raw_shape(0), Immediate(raw_layout(1)), [zero], [one]),
    LoadTag(zero, one),
    BorrowField(raw_shape(0), one, 0, projection),
    ConsumeFields(raw_shape(0), one, [{ member_index: 0, result: projection }]),
    MakeEnv(zero, raw_shape(1), Witness(zero), [zero], [one]),
    BorrowCapture(raw_shape(1), one, 0, projection),
    ConsumeCaptures(raw_shape(1), one, [{ member_index: 0, result: projection }]),
    MakeClosure(one, raw_function(1), zero),
    ByteToI64(one, zero),
    I64ToByte(zero, one),
    ByteSequenceMake(zero, one, zero),
    ByteSequenceLength(one, zero),
    ByteSequenceGet(zero, zero, one),
    ByteSequenceSet(zero, zero, one, zero),
    ByteSequenceEqual(zero, one, two),
    ByteSequenceConcat(zero, one, two),
    ByteSequenceSlice(zero, one, two, zero),
    ByteSequenceIsValidUtf8(zero, one),
    I32Add(zero, one, two),
    I32Sub(zero, one, two),
    I32Mul(zero, one, two),
    I32Neg(zero, one),
    I32Div(zero, one, two),
    I32Rem(zero, one, two),
    I32Eq(zero, one, two),
    I32Lt(zero, one, two),
    I32ToI64(one, zero),
    I64ToI32(zero, one),
    I64Add(zero, one, two),
    I64Sub(zero, one, two),
    I64Mul(zero, one, two),
    I64Neg(zero, one),
    I64Div(zero, one, two),
    I64Rem(zero, one, two),
    I64And(zero, one, two),
    I64Or(zero, one, two),
    I64Xor(zero, one, two),
    I64Not(zero, one),
    I64Shl(zero, one, two),
    I64ShrS(zero, one, two),
    I64Eq(zero, one, two),
    I64Ne(zero, one, two),
    I64Lt(zero, one, two),
    I64Le(zero, one, two),
    I64Gt(zero, one, two),
    I64Ge(zero, one, two),
    BoolNot(zero, one),
    BoolEq(zero, one, two),
    BoolNe(zero, one, two),
    F64Add(two, one, two),
    F64Sub(two, one, two),
    F64Mul(two, one, two),
    F64Div(two, one, two),
    F64Neg(two, one),
    F64Eq(zero, one, two),
    F64Ne(zero, one, two),
    F64Lt(zero, one, two),
    F64Le(zero, one, two),
    F64Gt(zero, one, two),
    F64Ge(zero, one, two),
    I64ToF64(two, zero),
    F64ToI64(zero, two),
    F32Add(two, one, two),
    F32Sub(two, one, two),
    F32Mul(two, one, two),
    F32Div(two, one, two),
    F32Neg(two, one),
    F32Eq(zero, one, two),
    F32Ne(zero, one, two),
    F32Lt(zero, one, two),
    F32Le(zero, one, two),
    F32Gt(zero, one, two),
    F32Ge(zero, one, two),
    I64ToF32(two, zero),
    F32ToI64(zero, two),
    F32ToF64(two, one),
    F64ToF32(two, one),
    F32ToString(zero, one),
    F64ToString(zero, one),
    EraseI32(one, zero),
    UneraseI32(zero, one),
    EraseI64(one, one),
    UneraseI64(one, one),
    EraseF64(one, two),
    UneraseF64(two, one),
    EraseF32(one, two),
    UneraseF32(two, one),
    EraseUnit(one),
    UneraseUnit(one),
    InitGlobal({ value: 0 }, zero),
    BorrowGlobal(zero, { value: 0 }),
    LoadObjectWitness(zero, raw_shape(0), one, 1),
  ]
  let decoded = []
  for instruction in instructions {
    decoded.push(roundtrip_raw_instruction(instruction))
  }
  assert_eq(decoded, instructions)
}
