///|
fn instruction_operand_values(instruction : Instruction) -> Array[ValueId] {
  match instruction {
    Copy(_, source)
    | Move(_, source)
    | RetainCopy(_, source)
    | Release(source)
    | LoadTag(_, source)
    | LoadObjectWitness(_, _, source, _)
    | ByteToI64(_, source)
    | I64ToByte(_, source)
    | ByteSequenceLength(_, source)
    | ByteSequenceIsValidUtf8(_, source)
    | I32Neg(_, source)
    | I32ToI64(_, source)
    | I64ToI32(_, source)
    | I64Neg(_, source)
    | I64Not(_, source)
    | BoolNot(_, source)
    | F32Neg(_, source)
    | I64ToF32(_, source)
    | F32ToI64(_, source)
    | F32ToF64(_, source)
    | F64ToF32(_, source)
    | F32ToString(_, source)
    | F64ToString(_, source)
    | F64Neg(_, source)
    | I64ToF64(_, source)
    | F64ToI64(_, source)
    | EraseI32(_, source)
    | UneraseI32(_, source)
    | EraseI64(_, source)
    | UneraseI64(_, source)
    | EraseF32(_, source)
    | UneraseF32(_, source)
    | EraseF64(_, source)
    | UneraseF64(_, source)
    | UneraseUnit(source)
    | InitGlobal(_, source) => [source]
    WasiFdWrite(_, fd, bytes) => [fd, bytes]
    ByteSequenceConcat(_, left, right)
    | ByteSequenceEqual(_, left, right)
    | ByteSequenceMake(_, left, right)
    | ByteSequenceGet(_, left, right)
    | I32Add(_, left, right)
    | I32Sub(_, left, right)
    | I32Mul(_, left, right)
    | I32Div(_, left, right)
    | I32Rem(_, left, right)
    | I32Eq(_, left, right)
    | I32Lt(_, left, right)
    | I64Add(_, left, right)
    | I64Sub(_, left, right)
    | I64Mul(_, left, right)
    | I64Div(_, left, right)
    | I64Rem(_, left, right)
    | I64And(_, left, right)
    | I64Or(_, left, right)
    | I64Xor(_, left, right)
    | I64Shl(_, left, right)
    | I64ShrS(_, left, right)
    | I64Eq(_, left, right)
    | I64Ne(_, left, right)
    | I64Lt(_, left, right)
    | I64Le(_, left, right)
    | I64Gt(_, left, right)
    | I64Ge(_, left, right)
    | BoolEq(_, left, right)
    | BoolNe(_, left, right)
    | F32Add(_, left, right)
    | F32Sub(_, left, right)
    | F32Mul(_, left, right)
    | F32Div(_, left, right)
    | F32Eq(_, left, right)
    | F32Ne(_, left, right)
    | F32Lt(_, left, right)
    | F32Le(_, left, right)
    | F32Gt(_, left, right)
    | F32Ge(_, left, right)
    | F64Add(_, left, right)
    | F64Sub(_, left, right)
    | F64Mul(_, left, right)
    | F64Div(_, left, right)
    | F64Eq(_, left, right)
    | F64Ne(_, left, right)
    | F64Lt(_, left, right)
    | F64Le(_, left, right)
    | F64Gt(_, left, right)
    | F64Ge(_, left, right) => [left, right]
    ByteSequenceSlice(_, string, start, length)
    | ByteSequenceSet(_, string, start, length) => [string, start, length]
    CallDirect(_, environment, witnesses, arguments, _) => {
      let uses = []
      if environment is Some(value) {
        uses.push(value)
      }
      uses.append(witnesses)
      uses.append(arguments)
      uses
    }
    CallPackedDirect(_, callable, witnesses, arguments, _) =>
      [callable] + witnesses + arguments
    CallValue(callable, witnesses, arguments, _) =>
      [callable] + witnesses + arguments
    MakeData(_, _, layout, witnesses, fields)
    | MakeEnv(_, _, layout, witnesses, fields) => {
      let uses = layout_uses(layout)
      uses.append(witnesses)
      uses.append(fields)
      uses
    }
    BorrowField(_, source, _, _)
    | ConsumeFields(_, source, _)
    | BorrowCapture(_, source, _, _)
    | ConsumeCaptures(_, source, _)
    | MakeClosure(_, _, source) => [source]
    ConstI64(_, _)
    | ConstI32(_, _)
    | ConstF32(_, _)
    | ConstChar(_, _)
    | ConstF64(_, _)
    | ConstBool(_, _)
    | ConstLayout(_, _)
    | ConstFunction(_, _)
    | ConstString(_, _)
    | EraseUnit(_)
    | BorrowGlobal(_, _) => []
  }
}

///|
fn layout_uses(layout : LayoutOperand) -> Array[ValueId] {
  match layout {
    Immediate(_) => []
    Witness(value) => [value]
  }
}

///|
fn terminator_operand_values(terminator : Terminator) -> Array[ValueId] {
  match terminator {
    Return(Some(value)) => [value]
    Return(None) | Unreachable => []
    Fatal(message) => [message]
    Jump(edge) => edge.arguments
    BranchBool(condition, if_true, if_false) =>
      [condition] + if_true.arguments + if_false.arguments
    SwitchTag(tag, cases, default) => {
      let uses = [tag]
      for edge in cases {
        uses.append(edge.arguments)
      }
      uses.append(default.arguments)
      uses
    }
    TailCallDirect(_, environment, witnesses, arguments) => {
      let uses = []
      if environment is Some(value) {
        uses.push(value)
      }
      uses.append(witnesses)
      uses.append(arguments)
      uses
    }
    TailCallPackedDirect(_, callable, witnesses, arguments) =>
      [callable] + witnesses + arguments
    TailCallValue(callable, witnesses, arguments) =>
      [callable] + witnesses + arguments
  }
}

///|
fn projection_destinations(result : ProjectionResult) -> Array[ValueId] {
  let destinations = [result.value_destination]
  if result.witness_destination is Some(value) {
    destinations.push(value)
  }
  destinations
}

///|
fn instruction_destinations(instruction : Instruction) -> Array[ValueId] {
  match instruction {
    Copy(destination, _)
    | Move(destination, _)
    | RetainCopy(destination, _)
    | ConstI64(destination, _)
    | ConstI32(destination, _)
    | ConstF32(destination, _)
    | ConstChar(destination, _)
    | ConstF64(destination, _)
    | ConstBool(destination, _)
    | ConstLayout(destination, _)
    | ConstFunction(destination, _)
    | ConstString(destination, _)
    | MakeData(destination, _, _, _, _)
    | LoadTag(destination, _)
    | LoadObjectWitness(destination, _, _, _)
    | MakeEnv(destination, _, _, _, _)
    | MakeClosure(destination, _, _)
    | ByteToI64(destination, _)
    | I64ToByte(destination, _)
    | ByteSequenceMake(destination, _, _)
    | ByteSequenceLength(destination, _)
    | ByteSequenceGet(destination, _, _)
    | ByteSequenceSet(destination, _, _, _)
    | ByteSequenceEqual(destination, _, _)
    | ByteSequenceConcat(destination, _, _)
    | ByteSequenceSlice(destination, _, _, _)
    | ByteSequenceIsValidUtf8(destination, _)
    | I32Add(destination, _, _)
    | I32Sub(destination, _, _)
    | I32Mul(destination, _, _)
    | I32Neg(destination, _)
    | I32Div(destination, _, _)
    | I32Rem(destination, _, _)
    | I32Eq(destination, _, _)
    | I32Lt(destination, _, _)
    | I32ToI64(destination, _)
    | I64ToI32(destination, _)
    | I64Add(destination, _, _)
    | I64Sub(destination, _, _)
    | I64Mul(destination, _, _)
    | I64Neg(destination, _)
    | I64Div(destination, _, _)
    | I64Rem(destination, _, _)
    | I64And(destination, _, _)
    | I64Or(destination, _, _)
    | I64Xor(destination, _, _)
    | I64Not(destination, _)
    | I64Shl(destination, _, _)
    | I64ShrS(destination, _, _)
    | I64Eq(destination, _, _)
    | I64Ne(destination, _, _)
    | I64Lt(destination, _, _)
    | I64Le(destination, _, _)
    | I64Gt(destination, _, _)
    | I64Ge(destination, _, _)
    | BoolNot(destination, _)
    | BoolEq(destination, _, _)
    | BoolNe(destination, _, _)
    | F32Add(destination, _, _)
    | F32Sub(destination, _, _)
    | F32Mul(destination, _, _)
    | F32Div(destination, _, _)
    | F32Neg(destination, _)
    | F32Eq(destination, _, _)
    | F32Ne(destination, _, _)
    | F32Lt(destination, _, _)
    | F32Le(destination, _, _)
    | F32Gt(destination, _, _)
    | F32Ge(destination, _, _)
    | I64ToF32(destination, _)
    | F32ToI64(destination, _)
    | F32ToF64(destination, _)
    | F64ToF32(destination, _)
    | F32ToString(destination, _)
    | F64ToString(destination, _)
    | F64Add(destination, _, _)
    | F64Sub(destination, _, _)
    | F64Mul(destination, _, _)
    | F64Div(destination, _, _)
    | F64Neg(destination, _)
    | F64Eq(destination, _, _)
    | F64Ne(destination, _, _)
    | F64Lt(destination, _, _)
    | F64Le(destination, _, _)
    | F64Gt(destination, _, _)
    | F64Ge(destination, _, _)
    | I64ToF64(destination, _)
    | F64ToI64(destination, _)
    | EraseI32(destination, _)
    | UneraseI32(destination, _)
    | EraseI64(destination, _)
    | UneraseI64(destination, _)
    | EraseF32(destination, _)
    | UneraseF32(destination, _)
    | EraseF64(destination, _)
    | UneraseF64(destination, _)
    | EraseUnit(destination)
    | BorrowGlobal(destination, _) => [destination]
    WasiFdWrite(destination, _, _) => [destination]
    CallDirect(_, _, _, _, destination)
    | CallPackedDirect(_, _, _, _, destination)
    | CallValue(_, _, _, destination) =>
      destination.map(value => [value]).unwrap_or([])
    BorrowField(_, _, _, result) | BorrowCapture(_, _, _, result) =>
      projection_destinations(result)
    ConsumeFields(_, _, selections) | ConsumeCaptures(_, _, selections) => {
      let destinations = []
      for selection in selections {
        destinations.append(projection_destinations(selection.result))
      }
      destinations
    }
    Release(_) | UneraseUnit(_) | InitGlobal(_, _) => []
  }
}
