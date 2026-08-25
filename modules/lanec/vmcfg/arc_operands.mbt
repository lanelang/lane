///|
priv enum ArcOperandMode {
  Borrow
  Consume
}

///|
priv struct ArcInstructionPlan {
  operands : Array[(ValueId, ArcOperandMode)]
  materialize : (Array[ValueId]) -> Instruction
}

///|
fn arc_instruction_plan(instruction : Instruction) -> ArcInstructionPlan {
  let consume = fn(values : Array[ValueId]) {
    values.map(value => (value, ArcOperandMode::Consume))
  }
  match instruction {
    Move(destination, source) =>
      {
        operands: [(source, Consume)],
        materialize: values => Move(destination, values[0]),
      }
    Release(source) =>
      {
        operands: [(source, Consume)],
        materialize: values => Release(values[0]),
      }
    CallDirect(target, environment, witnesses, arguments, destination) => {
      let operands = []
      if environment is Some(value) {
        operands.push((value, Consume))
      }
      operands.append(consume(witnesses))
      operands.append(consume(arguments))
      {
        operands,
        materialize: values => {
          let mut cursor = 0
          let lowered_environment = environment.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_witnesses = witnesses.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_arguments = arguments.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          CallDirect(
            target, lowered_environment, lowered_witnesses, lowered_arguments, destination,
          )
        },
      }
    }
    CallValue(callable, witnesses, arguments, destination) => {
      let operands = [(callable, ArcOperandMode::Consume)]
      operands.append(consume(witnesses))
      operands.append(consume(arguments))
      {
        operands,
        materialize: values => {
          let mut cursor = 1
          let lowered_witnesses = witnesses.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_arguments = arguments.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          CallValue(
            values[0],
            lowered_witnesses,
            lowered_arguments,
            destination,
          )
        },
      }
    }
    MakeData(destination, shape, layout, witnesses, fields) => {
      let operands = layout_uses(layout).map(value => (value, Borrow))
      operands.append(consume(witnesses))
      operands.append(consume(fields))
      {
        operands,
        materialize: values => {
          let mut cursor = layout_uses(layout).length()
          let lowered_witnesses = witnesses.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_fields = fields.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          MakeData(
            destination, shape, layout, lowered_witnesses, lowered_fields,
          )
        },
      }
    }
    MakeEnv(destination, shape, layout, witnesses, captures) => {
      let operands = layout_uses(layout).map(value => (value, Borrow))
      operands.append(witnesses.map(value => (value, Borrow)))
      operands.append(consume(captures))
      {
        operands,
        materialize: values => {
          let mut cursor = layout_uses(layout).length() + witnesses.length()
          let lowered_captures = captures.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          MakeEnv(destination, shape, layout, witnesses, lowered_captures)
        },
      }
    }
    ConsumeFields(shape, source, selections) =>
      {
        operands: [(source, Consume)],
        materialize: values => ConsumeFields(shape, values[0], selections),
      }
    ConsumeCaptures(shape, source, selections) =>
      {
        operands: [(source, Consume)],
        materialize: values => ConsumeCaptures(shape, values[0], selections),
      }
    MakeClosure(destination, function, environment) =>
      {
        operands: [(environment, Consume)],
        materialize: values => MakeClosure(destination, function, values[0]),
      }
    ByteSequenceSet(destination, source, index, value) =>
      {
        operands: [(source, Consume), (index, Borrow), (value, Borrow)],
        materialize: values => {
          ByteSequenceSet(destination, values[0], values[1], values[2])
        },
      }
    ByteSequenceConcat(destination, left, right) =>
      {
        operands: [(left, Consume), (right, Consume)],
        materialize: values => {
          ByteSequenceConcat(destination, values[0], values[1])
        },
      }
    ByteSequenceSlice(destination, source, start, length) =>
      {
        operands: [(source, Consume), (start, Borrow), (length, Borrow)],
        materialize: values => {
          ByteSequenceSlice(destination, values[0], values[1], values[2])
        },
      }
    EraseI32(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        EraseI32(destination, value)
      })
    UneraseI32(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        UneraseI32(destination, value)
      })
    EraseI64(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        EraseI64(destination, value)
      })
    UneraseI64(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        UneraseI64(destination, value)
      })
    EraseF32(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        EraseF32(destination, value)
      })
    UneraseF32(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        UneraseF32(destination, value)
      })
    EraseF64(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        EraseF64(destination, value)
      })
    UneraseF64(destination, source) =>
      consuming_unary_instruction_plan(source, value => {
        UneraseF64(destination, value)
      })
    UneraseUnit(source) =>
      consuming_unary_instruction_plan(source, value => UneraseUnit(value))
    InitGlobal(global, source) =>
      consuming_unary_instruction_plan(source, value => {
        InitGlobal(global, value)
      })
    Copy(_, _)
    | RetainCopy(_, _)
    | ConstI64(_, _)
    | ConstI32(_, _)
    | ConstChar(_, _)
    | ConstF64(_, _)
    | ConstF32(_, _)
    | ConstBool(_, _)
    | ConstLayout(_, _)
    | ConstFunction(_, _)
    | ConstString(_, _)
    | LoadTag(_, _)
    | LoadObjectWitness(_, _, _, _)
    | BorrowField(_, _, _, _)
    | BorrowCapture(_, _, _, _)
    | ByteToI64(_, _)
    | I64ToByte(_, _)
    | ByteSequenceMake(_, _, _)
    | ByteSequenceLength(_, _)
    | ByteSequenceGet(_, _, _)
    | ByteSequenceEqual(_, _, _)
    | ByteSequenceIsValidUtf8(_, _)
    | I32Add(_, _, _)
    | I32Sub(_, _, _)
    | I32Mul(_, _, _)
    | I32Neg(_, _)
    | I32Div(_, _, _)
    | I32Rem(_, _, _)
    | I32Eq(_, _, _)
    | I32Lt(_, _, _)
    | I32ToI64(_, _)
    | I64ToI32(_, _)
    | I64Add(_, _, _)
    | I64Sub(_, _, _)
    | I64Mul(_, _, _)
    | I64Neg(_, _)
    | I64Div(_, _, _)
    | I64Rem(_, _, _)
    | I64And(_, _, _)
    | I64Or(_, _, _)
    | I64Xor(_, _, _)
    | I64Not(_, _)
    | I64Shl(_, _, _)
    | I64ShrS(_, _, _)
    | I64Eq(_, _, _)
    | I64Ne(_, _, _)
    | I64Lt(_, _, _)
    | I64Le(_, _, _)
    | I64Gt(_, _, _)
    | I64Ge(_, _, _)
    | BoolNot(_, _)
    | BoolEq(_, _, _)
    | BoolNe(_, _, _)
    | F64Add(_, _, _)
    | F64Sub(_, _, _)
    | F64Mul(_, _, _)
    | F64Div(_, _, _)
    | F64Neg(_, _)
    | F64Eq(_, _, _)
    | F64Ne(_, _, _)
    | F64Lt(_, _, _)
    | F64Le(_, _, _)
    | F64Gt(_, _, _)
    | F64Ge(_, _, _)
    | I64ToF64(_, _)
    | F64ToI64(_, _)
    | F32Add(_, _, _)
    | F32Sub(_, _, _)
    | F32Mul(_, _, _)
    | F32Div(_, _, _)
    | F32Neg(_, _)
    | F32Eq(_, _, _)
    | F32Ne(_, _, _)
    | F32Lt(_, _, _)
    | F32Le(_, _, _)
    | F32Gt(_, _, _)
    | F32Ge(_, _, _)
    | I64ToF32(_, _)
    | F32ToI64(_, _)
    | F32ToF64(_, _)
    | F64ToF32(_, _)
    | F32ToString(_, _)
    | F64ToString(_, _)
    | EraseUnit(_)
    | BorrowGlobal(_, _) =>
      {
        operands: instruction_operand_values(instruction).map(value => {
          (value, Borrow)
        }),
        materialize: _ => instruction,
      }
  }
}

///|
fn consuming_unary_instruction_plan(
  source : ValueId,
  materialize : (ValueId) -> Instruction,
) -> ArcInstructionPlan {
  {
    operands: [(source, Consume)],
    materialize: values => materialize(values[0]),
  }
}

///|
fn instruction_arc_operands(
  instruction : Instruction,
) -> Array[(ValueId, ArcOperandMode)] {
  arc_instruction_plan(instruction).operands
}

///|
priv struct ArcTerminalPlan {
  operands : Array[(ValueId, ArcOperandMode)]
  materialize : (Array[ValueId]) -> Terminator
}

///|
fn arc_terminal_plan(terminator : Terminator) -> ArcTerminalPlan? {
  match terminator {
    Return(value) =>
      Some({
        operands: value
        .map(value => [(value, ArcOperandMode::Consume)])
        .unwrap_or([]),
        materialize: values => {
          Return(if values.is_empty() { None } else { Some(values[0]) })
        },
      })
    TailCallDirect(target, environment, witnesses, arguments) => {
      let operands = []
      if environment is Some(value) {
        operands.push((value, Consume))
      }
      operands.append(witnesses.map(value => (value, Consume)))
      operands.append(arguments.map(value => (value, Consume)))
      Some({
        operands,
        materialize: values => {
          let mut cursor = 0
          let lowered_environment = environment.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_witnesses = witnesses.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_arguments = arguments.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          TailCallDirect(
            target, lowered_environment, lowered_witnesses, lowered_arguments,
          )
        },
      })
    }
    TailCallValue(callable, witnesses, arguments) => {
      let operands = [(callable, ArcOperandMode::Consume)]
      operands.append(witnesses.map(value => (value, Consume)))
      operands.append(arguments.map(value => (value, Consume)))
      Some({
        operands,
        materialize: values => {
          let mut cursor = 1
          let lowered_witnesses = witnesses.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          let lowered_arguments = arguments.map(fn(_) {
            let value = values[cursor]
            cursor += 1
            value
          })
          TailCallValue(values[0], lowered_witnesses, lowered_arguments)
        },
      })
    }
    Fatal(message) =>
      Some({
        operands: [(message, Consume)],
        materialize: values => Fatal(values[0]),
      })
    Unreachable => Some({ operands: [], materialize: _ => Unreachable, })
    Jump(_) | BranchBool(_, _, _) | SwitchTag(_, _, _) => None
  }
}
