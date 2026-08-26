///|
fn emit_block(
  result : @physical.ResultAbi,
  slots : PhysicalSlotPlan,
  callable_abis : CallableAbiInterner,
  block : Block,
) -> @physical.Block raise FinalizeError {
  {
    parameters: block.parameters.map(value => slots.slot(value)),
    instructions: block.instructions.map(instruction => {
      emit_instruction(slots, callable_abis, instruction)
    }),
    terminator: emit_terminator(result, slots, callable_abis, block.terminator),
  }
}

///|
fn finalized_slot_metadata(
  metadata : Array[@physical.SlotMetadata],
  slots : Array[@physical.SlotId],
) -> Array[@physical.SlotMetadata] {
  slots.map(slot => metadata[slot.value])
}

///|
fn emit_instruction(
  slots : PhysicalSlotPlan,
  callable_abis : CallableAbiInterner,
  instruction : Instruction,
) -> @physical.Instruction raise FinalizeError {
  let slot = value => slots.slot(value)
  match instruction {
    Copy(destination, source) => Copy(slot(destination), slot(source))
    Move(destination, source) => Move(slot(destination), slot(source))
    RetainCopy(destination, source) =>
      RetainCopy(slot(destination), slot(source))
    Release(source) => Release(slot(source))
    ConstI64(destination, value) => ConstI64(slot(destination), value)
    ConstI32(destination, value) => ConstI32(slot(destination), value)
    ConstF32(destination, bits) => ConstF32(slot(destination), bits)
    ConstChar(destination, value) => ConstChar(slot(destination), value)
    ConstF64(destination, bits) => ConstF64(slot(destination), bits)
    ConstBool(destination, value) => ConstBool(slot(destination), value)
    ConstLayout(destination, layout) => ConstLayout(slot(destination), layout)
    ConstFunction(destination, function) =>
      ConstFunction(slot(destination), function)
    ConstString(destination, constant) =>
      ConstString(slot(destination), constant)
    CallDirect(target, environment, witnesses, arguments, destination) => {
      let lowered_environment = match environment {
        Some(value) => Some(slot(value))
        None => None
      }
      let lowered_witnesses = witnesses.map(value => slot(value))
      let lowered_arguments = arguments.map(value => slot(value))
      CallDirect(
        target,
        lowered_environment,
        lowered_witnesses,
        lowered_arguments,
        destination.map(value => slot(value)),
      )
    }
    CallValue(callable, witnesses, arguments, destination) => {
      let lowered_callable = slot(callable)
      let lowered_witnesses = witnesses.map(value => slot(value))
      let lowered_arguments = arguments.map(value => slot(value))
      let result = match destination {
        Some(value) => slots.metadata(value).result_abi()
        None => Unit
      }
      let abi = callable_abis.intern(
        @physical.CallableAbi::from_slot_metadata(
          finalized_slot_metadata(slots.slots, lowered_witnesses),
          finalized_slot_metadata(slots.slots, lowered_arguments),
          result,
        ),
      )
      CallValue(
        lowered_callable,
        abi,
        lowered_witnesses,
        lowered_arguments,
        destination.map(value => slot(value)),
      )
    }
    MakeData(destination, shape, layout, witnesses, fields) =>
      MakeData(
        slot(destination),
        shape,
        emit_layout_operand(slots, layout),
        witnesses.map(value => slot(value)),
        fields.map(value => slot(value)),
      )
    LoadTag(destination, source) => LoadTag(slot(destination), slot(source))
    LoadObjectWitness(destination, shape, source, ordinal) =>
      LoadObjectWitness(slot(destination), shape, slot(source), ordinal)
    BorrowField(shape, source, index, projection) =>
      BorrowField(
        shape,
        slot(source),
        index,
        projection_result_to_physical(slots, projection),
      )
    ConsumeFields(shape, source, selections) =>
      ConsumeFields(
        shape,
        slot(source),
        selections.map(selection => {
          projection_selection_to_physical(slots, selection)
        }),
      )
    MakeEnv(destination, shape, layout, witnesses, captures) =>
      MakeEnv(
        slot(destination),
        shape,
        emit_layout_operand(slots, layout),
        witnesses.map(value => slot(value)),
        captures.map(value => slot(value)),
      )
    BorrowCapture(shape, source, index, projection) =>
      BorrowCapture(
        shape,
        slot(source),
        index,
        projection_result_to_physical(slots, projection),
      )
    ConsumeCaptures(shape, source, selections) =>
      ConsumeCaptures(
        shape,
        slot(source),
        selections.map(selection => {
          projection_selection_to_physical(slots, selection)
        }),
      )
    MakeClosure(destination, function, environment) =>
      MakeClosure(slot(destination), function, slot(environment))
    ByteToI64(destination, source) => ByteToI64(slot(destination), slot(source))
    I64ToByte(destination, source) => I64ToByte(slot(destination), slot(source))
    ByteSequenceMake(destination, length, fill) =>
      ByteSequenceMake(slot(destination), slot(length), slot(fill))
    ByteSequenceLength(destination, source) =>
      ByteSequenceLength(slot(destination), slot(source))
    ByteSequenceGet(destination, source, index) =>
      ByteSequenceGet(slot(destination), slot(source), slot(index))
    ByteSequenceSet(destination, source, index, value) =>
      ByteSequenceSet(slot(destination), slot(source), slot(index), slot(value))
    ByteSequenceEqual(destination, left, right) =>
      ByteSequenceEqual(slot(destination), slot(left), slot(right))
    ByteSequenceConcat(destination, left, right) =>
      ByteSequenceConcat(slot(destination), slot(left), slot(right))
    ByteSequenceSlice(destination, source, start, length) =>
      ByteSequenceSlice(
        slot(destination),
        slot(source),
        slot(start),
        slot(length),
      )
    ByteSequenceIsValidUtf8(destination, source) =>
      ByteSequenceIsValidUtf8(slot(destination), slot(source))
    I32Add(destination, left, right) =>
      I32Add(slot(destination), slot(left), slot(right))
    I32Sub(destination, left, right) =>
      I32Sub(slot(destination), slot(left), slot(right))
    I32Mul(destination, left, right) =>
      I32Mul(slot(destination), slot(left), slot(right))
    I32Neg(destination, source) => I32Neg(slot(destination), slot(source))
    I32Div(destination, left, right) =>
      I32Div(slot(destination), slot(left), slot(right))
    I32Rem(destination, left, right) =>
      I32Rem(slot(destination), slot(left), slot(right))
    I32Eq(destination, left, right) =>
      I32Eq(slot(destination), slot(left), slot(right))
    I32Lt(destination, left, right) =>
      I32Lt(slot(destination), slot(left), slot(right))
    I32ToI64(destination, source) => I32ToI64(slot(destination), slot(source))
    I64ToI32(destination, source) => I64ToI32(slot(destination), slot(source))
    I64Add(destination, left, right) =>
      I64Add(slot(destination), slot(left), slot(right))
    I64Sub(destination, left, right) =>
      I64Sub(slot(destination), slot(left), slot(right))
    I64Mul(destination, left, right) =>
      I64Mul(slot(destination), slot(left), slot(right))
    I64Neg(destination, source) => I64Neg(slot(destination), slot(source))
    I64Div(destination, left, right) =>
      I64Div(slot(destination), slot(left), slot(right))
    I64Rem(destination, left, right) =>
      I64Rem(slot(destination), slot(left), slot(right))
    I64And(destination, left, right) =>
      I64And(slot(destination), slot(left), slot(right))
    I64Or(destination, left, right) =>
      I64Or(slot(destination), slot(left), slot(right))
    I64Xor(destination, left, right) =>
      I64Xor(slot(destination), slot(left), slot(right))
    I64Not(destination, source) => I64Not(slot(destination), slot(source))
    I64Shl(destination, left, right) =>
      I64Shl(slot(destination), slot(left), slot(right))
    I64ShrS(destination, left, right) =>
      I64ShrS(slot(destination), slot(left), slot(right))
    I64Eq(destination, left, right) =>
      I64Eq(slot(destination), slot(left), slot(right))
    I64Ne(destination, left, right) =>
      I64Ne(slot(destination), slot(left), slot(right))
    I64Lt(destination, left, right) =>
      I64Lt(slot(destination), slot(left), slot(right))
    I64Le(destination, left, right) =>
      I64Le(slot(destination), slot(left), slot(right))
    I64Gt(destination, left, right) =>
      I64Gt(slot(destination), slot(left), slot(right))
    I64Ge(destination, left, right) =>
      I64Ge(slot(destination), slot(left), slot(right))
    BoolNot(destination, source) => BoolNot(slot(destination), slot(source))
    BoolEq(destination, left, right) =>
      BoolEq(slot(destination), slot(left), slot(right))
    BoolNe(destination, left, right) =>
      BoolNe(slot(destination), slot(left), slot(right))
    F32Add(destination, left, right) =>
      F32Add(slot(destination), slot(left), slot(right))
    F32Sub(destination, left, right) =>
      F32Sub(slot(destination), slot(left), slot(right))
    F32Mul(destination, left, right) =>
      F32Mul(slot(destination), slot(left), slot(right))
    F32Div(destination, left, right) =>
      F32Div(slot(destination), slot(left), slot(right))
    F32Neg(destination, source) => F32Neg(slot(destination), slot(source))
    F32Eq(destination, left, right) =>
      F32Eq(slot(destination), slot(left), slot(right))
    F32Ne(destination, left, right) =>
      F32Ne(slot(destination), slot(left), slot(right))
    F32Lt(destination, left, right) =>
      F32Lt(slot(destination), slot(left), slot(right))
    F32Le(destination, left, right) =>
      F32Le(slot(destination), slot(left), slot(right))
    F32Gt(destination, left, right) =>
      F32Gt(slot(destination), slot(left), slot(right))
    F32Ge(destination, left, right) =>
      F32Ge(slot(destination), slot(left), slot(right))
    I64ToF32(destination, source) => I64ToF32(slot(destination), slot(source))
    F32ToI64(destination, source) => F32ToI64(slot(destination), slot(source))
    F32ToF64(destination, source) => F32ToF64(slot(destination), slot(source))
    F64ToF32(destination, source) => F64ToF32(slot(destination), slot(source))
    F32ToString(destination, source) =>
      F32ToString(slot(destination), slot(source))
    F64ToString(destination, source) =>
      F64ToString(slot(destination), slot(source))
    F64Add(destination, left, right) =>
      F64Add(slot(destination), slot(left), slot(right))
    F64Sub(destination, left, right) =>
      F64Sub(slot(destination), slot(left), slot(right))
    F64Mul(destination, left, right) =>
      F64Mul(slot(destination), slot(left), slot(right))
    F64Div(destination, left, right) =>
      F64Div(slot(destination), slot(left), slot(right))
    F64Neg(destination, source) => F64Neg(slot(destination), slot(source))
    F64Eq(destination, left, right) =>
      F64Eq(slot(destination), slot(left), slot(right))
    F64Ne(destination, left, right) =>
      F64Ne(slot(destination), slot(left), slot(right))
    F64Lt(destination, left, right) =>
      F64Lt(slot(destination), slot(left), slot(right))
    F64Le(destination, left, right) =>
      F64Le(slot(destination), slot(left), slot(right))
    F64Gt(destination, left, right) =>
      F64Gt(slot(destination), slot(left), slot(right))
    F64Ge(destination, left, right) =>
      F64Ge(slot(destination), slot(left), slot(right))
    I64ToF64(destination, source) => I64ToF64(slot(destination), slot(source))
    F64ToI64(destination, source) => F64ToI64(slot(destination), slot(source))
    EraseI32(destination, source) => EraseI32(slot(destination), slot(source))
    UneraseI32(destination, source) =>
      UneraseI32(slot(destination), slot(source))
    EraseI64(destination, source) => EraseI64(slot(destination), slot(source))
    UneraseI64(destination, source) =>
      UneraseI64(slot(destination), slot(source))
    EraseF32(destination, source) => EraseF32(slot(destination), slot(source))
    UneraseF32(destination, source) =>
      UneraseF32(slot(destination), slot(source))
    EraseF64(destination, source) => EraseF64(slot(destination), slot(source))
    UneraseF64(destination, source) =>
      UneraseF64(slot(destination), slot(source))
    EraseUnit(destination) => EraseUnit(slot(destination))
    UneraseUnit(source) => UneraseUnit(slot(source))
    InitGlobal(global, source) => InitGlobal(global, slot(source))
    BorrowGlobal(destination, global) => BorrowGlobal(slot(destination), global)
  }
}

///|
fn emit_layout_operand(
  slots : PhysicalSlotPlan,
  layout : LayoutOperand,
) -> @physical.LayoutOperand raise FinalizeError {
  match layout {
    Immediate(layout) => Immediate(layout)
    Witness(value) => Witness(slots.slot(value))
  }
}

///|
fn projection_result_to_physical(
  slots : PhysicalSlotPlan,
  result : ProjectionResult,
) -> @physical.ProjectionResult raise FinalizeError {
  {
    value_destination: slots.slot(result.value_destination),
    witness_destination: result.witness_destination.map(value => {
      slots.slot(value)
    }),
  }
}

///|
fn projection_selection_to_physical(
  slots : PhysicalSlotPlan,
  selection : ProjectionSelection,
) -> @physical.ProjectionSelection raise FinalizeError {
  {
    member_index: selection.member_index,
    result: projection_result_to_physical(slots, selection.result),
  }
}

///|
fn emit_terminator(
  result : @physical.ResultAbi,
  slots : PhysicalSlotPlan,
  callable_abis : CallableAbiInterner,
  terminator : Terminator,
) -> @physical.Terminator raise FinalizeError {
  let slot = value => slots.slot(value)
  match terminator {
    Return(source) => Return(source.map(slot))
    Jump(edge) => Jump(emit_edge(slots, edge))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(
        slot(condition),
        emit_edge(slots, if_true),
        emit_edge(slots, if_false),
      )
    SwitchTag(tag, cases, default) =>
      SwitchTag(
        slot(tag),
        cases.map(edge => emit_edge(slots, edge)),
        emit_edge(slots, default),
      )
    TailCallDirect(target, environment, witnesses, arguments) =>
      TailCallDirect(
        target,
        environment.map(slot),
        witnesses.map(slot),
        arguments.map(slot),
      )
    TailCallValue(callable, witnesses, arguments) => {
      let lowered_witnesses = witnesses.map(slot)
      let lowered_arguments = arguments.map(slot)
      let abi = callable_abis.intern(
        @physical.CallableAbi::from_slot_metadata(
          finalized_slot_metadata(slots.slots, lowered_witnesses),
          finalized_slot_metadata(slots.slots, lowered_arguments),
          result,
        ),
      )
      TailCallValue(slot(callable), abi, lowered_witnesses, lowered_arguments)
    }
    Fatal(message) => Fatal(slot(message))
    Unreachable => Unreachable
  }
}

///|
fn emit_edge(
  slots : PhysicalSlotPlan,
  edge : Edge,
) -> @physical.Edge raise FinalizeError {
  {
    target: edge.target,
    arguments: edge.arguments.map(value => slots.slot(value)),
  }
}
