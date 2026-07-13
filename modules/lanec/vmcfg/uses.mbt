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
    | StringLength(_, source)
    | IntNeg(_, source)
    | IntNot(_, source)
    | BoolNot(_, source)
    | DoubleNeg(_, source)
    | IntToDouble(_, source)
    | DoubleToInt(_, source)
    | EraseI32(_, source)
    | UneraseI32(_, source)
    | EraseI64(_, source)
    | UneraseI64(_, source)
    | EraseF64(_, source)
    | UneraseF64(_, source)
    | UneraseUnit(source) => [source]
    StringConcat(_, left, right)
    | StringEq(_, left, right)
    | IntAdd(_, left, right)
    | IntSub(_, left, right)
    | IntMul(_, left, right)
    | IntDiv(_, left, right)
    | IntRem(_, left, right)
    | IntAnd(_, left, right)
    | IntOr(_, left, right)
    | IntXor(_, left, right)
    | IntShl(_, left, right)
    | IntShrS(_, left, right)
    | IntEq(_, left, right)
    | IntNe(_, left, right)
    | IntLt(_, left, right)
    | IntLe(_, left, right)
    | IntGt(_, left, right)
    | IntGe(_, left, right)
    | BoolEq(_, left, right)
    | BoolNe(_, left, right)
    | DoubleAdd(_, left, right)
    | DoubleSub(_, left, right)
    | DoubleMul(_, left, right)
    | DoubleDiv(_, left, right)
    | DoubleEq(_, left, right)
    | DoubleNe(_, left, right)
    | DoubleLt(_, left, right)
    | DoubleLe(_, left, right)
    | DoubleGt(_, left, right)
    | DoubleGe(_, left, right) => [left, right]
    StringSlice(_, string, start, length) => [string, start, length]
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
    ConstInt(_, _)
    | ConstDouble(_, _)
    | ConstBool(_, _)
    | ConstLayout(_, _)
    | ConstFunction(_, _)
    | ConstString(_, _)
    | EraseUnit(_) => []
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
    TailCallValue(callable, witnesses, arguments) =>
      [callable] + witnesses + arguments
  }
}
