///|
fn block_use_counts(value_count : Int, block : Block) -> Array[Int] {
  let counts = Array::make(value_count, 0)
  for instruction in block.instructions {
    for value in instruction_uses(instruction) {
      counts[value.value] += 1
    }
  }
  for value in terminator_uses(block.terminator) {
    counts[value.value] += 1
  }
  counts
}

///|
fn instruction_uses(instruction : Instruction) -> Array[ValueId] {
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
fn terminator_uses(terminator : Terminator) -> Array[ValueId] {
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
    TailCallDirect(_, environment, witnesses, arguments)
    | CallNeverDirect(_, environment, witnesses, arguments) => {
      let uses = []
      if environment is Some(value) {
        uses.push(value)
      }
      uses.append(witnesses)
      uses.append(arguments)
      uses
    }
    TailCallValue(callable, witnesses, arguments)
    | CallNeverValue(callable, witnesses, arguments) =>
      [callable] + witnesses + arguments
  }
}
