///|
pub fn finalize(
  image : Image,
) -> Result[@bytecode.BytecodeImage, FinalizeError] {
  Ok(finalize_or_raise(image)) catch {
    error => Err(error)
  }
}

///|
fn finalize_or_raise(
  image : Image,
) -> @bytecode.BytecodeImage raise FinalizeError {
  let functions : Array[@bytecode.FunctionEntry] = []
  for entry in image.functions {
    match entry {
      Body(body) => functions.push(BytecodeBody(finalize_body(body)))
      RuntimeImport(import_) => functions.push(RuntimeImport(import_))
    }
  }
  {
    entry: image.entry,
    initializer: None,
    functions,
    globals: [],
    layouts: image.layouts,
    object_shapes: image.object_shapes,
    constants: image.constants,
  }
}

///|
fn finalize_body(
  body : FunctionBody,
) -> @bytecode.FunctionBody raise FinalizeError {
  for index, metadata in body.values {
    validate_metadata({ value: index }, metadata)
  }
  let blocks : Array[@bytecode.Block] = []
  let edge_blocks : Array[@bytecode.Block] = []
  let original_block_count = body.blocks.length()
  for index, block in body.blocks {
    blocks.push(
      finalize_block(body, index, block, original_block_count, edge_blocks),
    )
  }
  blocks.append(edge_blocks)
  {
    slots: body.values.map(value_metadata_to_slot),
    inputs: {
      environment: body.inputs.environment.map(value_to_slot),
      witnesses: body.inputs.witnesses.map(value_to_slot),
      user_parameters: body.inputs.user_parameters.map(value_to_slot),
    },
    result: body.result,
    blocks,
  }
}

///|
fn validate_metadata(
  value : ValueId,
  metadata : ValueMetadata,
) -> Unit raise FinalizeError {
  let valid = match (metadata.ownership, metadata.cleanup) {
    (Trivial, Trivial) => true
    (Owned, OwnedRef | OwnedCallable | OwnedErased) => true
    (Borrowed, OwnedRef | OwnedCallable | OwnedErased) => true
    _ => false
  }
  if !valid {
    raise IllegalValueMetadata(value~)
  }
}

///|
fn value_metadata_to_slot(metadata : ValueMetadata) -> @bytecode.SlotMetadata {
  {
    representation: metadata.representation,
    cleanup: match metadata.ownership {
      Trivial | Borrowed => Trivial
      Owned => metadata.cleanup
    },
    erased_companion: match metadata.ownership {
      Owned if metadata.cleanup is OwnedErased =>
        metadata.erased_companion.map(value_to_slot)
      _ => None
    },
  }
}

///|
fn value_to_slot(value : ValueId) -> @bytecode.SlotId {
  { value: value.value }
}

///|
fn finalize_block(
  body : FunctionBody,
  block_index : Int,
  block : Block,
  original_block_count : Int,
  edge_blocks : Array[@bytecode.Block],
) -> @bytecode.Block raise FinalizeError {
  let remaining = block_use_counts(body.values.length(), block)
  let live = Array::make(body.values.length(), false)
  if block_index == 0 {
    if body.inputs.environment is Some(value) {
      mark_live(body, live, value)
    }
    for value in body.inputs.witnesses {
      mark_live(body, live, value)
    }
    for value in body.inputs.user_parameters {
      mark_live(body, live, value)
    }
  }
  for value in block.parameters {
    mark_live(body, live, value)
  }
  let instructions : Array[@bytecode.Instruction] = []
  for instruction in block.instructions {
    instructions.push(
      finalize_instruction(
        body, block_index, live, remaining, instructions, instruction,
      ),
    )
  }
  let terminator = finalize_terminator(
    body,
    block_index,
    live,
    remaining,
    instructions,
    block.terminator,
    original_block_count,
    edge_blocks,
  )
  for index, is_live in live {
    if is_live {
      instructions.push(Release({ value: index }))
    }
  }
  { parameters: block.parameters.map(value_to_slot), instructions, terminator }
}

///|
fn mark_live(body : FunctionBody, live : Array[Bool], value : ValueId) -> Unit {
  if body.values[value.value].ownership is Owned {
    live[value.value] = true
  }
}

///|
fn consume_value(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[@bytecode.Instruction],
  value : ValueId,
) -> ValueId raise FinalizeError {
  remaining[value.value] -= 1
  match body.values[value.value].ownership {
    Trivial => value
    Borrowed => {
      let promoted = append_owned_value(body, value)
      prefix.push(RetainCopy(value_to_slot(promoted), value_to_slot(value)))
      promoted
    }
    Owned => {
      if !live[value.value] {
        raise UseBeforeOwnership(value~, block~)
      }
      if remaining[value.value] > 0 {
        let retained = append_owned_value(body, value)
        prefix.push(RetainCopy(value_to_slot(retained), value_to_slot(value)))
        retained
      } else {
        live[value.value] = false
        value
      }
    }
  }
}

///|
fn borrow_value(remaining : Array[Int], value : ValueId) -> ValueId {
  remaining[value.value] -= 1
  value
}

///|
fn append_owned_value(body : FunctionBody, source : ValueId) -> ValueId {
  let metadata = body.values[source.value]
  let value : ValueId = { value: body.values.length() }
  body.values.push({ ..metadata, ownership: Owned })
  value
}

///|
fn mark_destination(
  body : FunctionBody,
  live : Array[Bool],
  destination : ValueId,
) -> Unit {
  while live.length() < body.values.length() {
    live.push(false)
  }
  mark_live(body, live, destination)
}

///|
fn finalize_instruction(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[@bytecode.Instruction],
  instruction : Instruction,
) -> @bytecode.Instruction raise FinalizeError {
  let result : @bytecode.Instruction = match instruction {
    Copy(destination, source) =>
      Copy(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    Move(destination, source) => {
      let consumed = consume_value(body, block, live, remaining, prefix, source)
      Move(value_to_slot(destination), value_to_slot(consumed))
    }
    RetainCopy(destination, source) =>
      RetainCopy(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    Release(source) => {
      let consumed = consume_value(body, block, live, remaining, prefix, source)
      Release(value_to_slot(consumed))
    }
    ConstInt(destination, value) => ConstInt(value_to_slot(destination), value)
    ConstDouble(destination, bits) =>
      ConstDouble(value_to_slot(destination), bits)
    ConstBool(destination, value) =>
      ConstBool(value_to_slot(destination), value)
    ConstLayout(destination, layout) =>
      ConstLayout(value_to_slot(destination), layout)
    ConstFunction(destination, function) =>
      ConstFunction(value_to_slot(destination), function)
    ConstString(destination, constant) =>
      ConstString(value_to_slot(destination), constant)
    CallDirect(target, environment, witnesses, arguments, destination) => {
      let lowered_environment = match environment {
        Some(value) =>
          Some(
            value_to_slot(
              consume_value(body, block, live, remaining, prefix, value),
            ),
          )
        None => None
      }
      let lowered_witnesses = witnesses.map(value => {
        value_to_slot(borrow_value(remaining, value))
      })
      let lowered_arguments = arguments.map(value => {
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, value),
        )
      })
      CallDirect(
        target,
        lowered_environment,
        lowered_witnesses,
        lowered_arguments,
        destination.map(value_to_slot),
      )
    }
    CallValue(callable, witnesses, arguments, destination) =>
      CallValue(
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, callable),
        ),
        witnesses.map(value => value_to_slot(borrow_value(remaining, value))),
        arguments.map(value => {
          value_to_slot(
            consume_value(body, block, live, remaining, prefix, value),
          )
        }),
        destination.map(value_to_slot),
      )
    MakeData(destination, shape, layout, witnesses, fields) =>
      MakeData(
        value_to_slot(destination),
        shape,
        finalize_layout_operand(remaining, layout),
        witnesses.map(value => value_to_slot(borrow_value(remaining, value))),
        fields.map(value => {
          value_to_slot(
            consume_value(body, block, live, remaining, prefix, value),
          )
        }),
      )
    LoadTag(destination, source) =>
      LoadTag(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    LoadObjectWitness(destination, shape, source, ordinal) =>
      LoadObjectWitness(
        value_to_slot(destination),
        shape,
        value_to_slot(borrow_value(remaining, source)),
        ordinal,
      )
    BorrowField(shape, source, index, projection) =>
      BorrowField(
        shape,
        value_to_slot(borrow_value(remaining, source)),
        index,
        projection_result_to_bytecode(projection),
      )
    ConsumeFields(shape, source, selections) =>
      ConsumeFields(
        shape,
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
        selections.map(projection_selection_to_bytecode),
      )
    MakeEnv(destination, shape, layout, witnesses, captures) =>
      MakeEnv(
        value_to_slot(destination),
        shape,
        finalize_layout_operand(remaining, layout),
        witnesses.map(value => value_to_slot(borrow_value(remaining, value))),
        captures.map(value => {
          value_to_slot(
            consume_value(body, block, live, remaining, prefix, value),
          )
        }),
      )
    BorrowCapture(shape, source, index, projection) =>
      BorrowCapture(
        shape,
        value_to_slot(borrow_value(remaining, source)),
        index,
        projection_result_to_bytecode(projection),
      )
    ConsumeCaptures(shape, source, selections) =>
      ConsumeCaptures(
        shape,
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
        selections.map(projection_selection_to_bytecode),
      )
    MakeClosure(destination, function, environment) =>
      MakeClosure(
        value_to_slot(destination),
        function,
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, environment),
        ),
      )
    StringLength(destination, string) =>
      StringLength(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, string)),
      )
    StringConcat(destination, left, right) =>
      StringConcat(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    StringSlice(destination, string, start, length) =>
      StringSlice(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, string)),
        value_to_slot(borrow_value(remaining, start)),
        value_to_slot(borrow_value(remaining, length)),
      )
    StringEq(destination, left, right) =>
      StringEq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntAdd(destination, left, right) =>
      IntAdd(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntSub(destination, left, right) =>
      IntSub(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntMul(destination, left, right) =>
      IntMul(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntNeg(destination, source) =>
      IntNeg(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    IntDiv(destination, left, right) =>
      IntDiv(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntRem(destination, left, right) =>
      IntRem(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntAnd(destination, left, right) =>
      IntAnd(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntOr(destination, left, right) =>
      IntOr(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntXor(destination, left, right) =>
      IntXor(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntNot(destination, source) =>
      IntNot(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    IntShl(destination, left, right) =>
      IntShl(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntShrS(destination, left, right) =>
      IntShrS(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntEq(destination, left, right) =>
      IntEq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntNe(destination, left, right) =>
      IntNe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntLt(destination, left, right) =>
      IntLt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntLe(destination, left, right) =>
      IntLe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntGt(destination, left, right) =>
      IntGt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntGe(destination, left, right) =>
      IntGe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    BoolNot(destination, source) =>
      BoolNot(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    BoolEq(destination, left, right) =>
      BoolEq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    BoolNe(destination, left, right) =>
      BoolNe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleAdd(destination, left, right) =>
      DoubleAdd(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleSub(destination, left, right) =>
      DoubleSub(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleMul(destination, left, right) =>
      DoubleMul(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleDiv(destination, left, right) =>
      DoubleDiv(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleNeg(destination, source) =>
      DoubleNeg(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    DoubleEq(destination, left, right) =>
      DoubleEq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleNe(destination, left, right) =>
      DoubleNe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleLt(destination, left, right) =>
      DoubleLt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleLe(destination, left, right) =>
      DoubleLe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleGt(destination, left, right) =>
      DoubleGt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    DoubleGe(destination, left, right) =>
      DoubleGe(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    IntToDouble(destination, source) =>
      IntToDouble(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    DoubleToInt(destination, source) =>
      DoubleToInt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    EraseI32(destination, source) =>
      EraseI32(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    UneraseI32(destination, source) =>
      UneraseI32(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    EraseI64(destination, source) =>
      EraseI64(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    UneraseI64(destination, source) =>
      UneraseI64(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    EraseF64(destination, source) =>
      EraseF64(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    UneraseF64(destination, source) =>
      UneraseF64(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    EraseUnit(destination) => EraseUnit(value_to_slot(destination))
    UneraseUnit(source) =>
      UneraseUnit(
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
  }
  for destination in instruction_destinations(instruction) {
    mark_destination(body, live, destination)
  }
  result
}

///|
fn finalize_layout_operand(
  remaining : Array[Int],
  layout : LayoutOperand,
) -> @bytecode.LayoutOperand {
  match layout {
    Immediate(layout) => Immediate(layout)
    Witness(value) => Witness(value_to_slot(borrow_value(remaining, value)))
  }
}

///|
fn projection_result_to_bytecode(
  result : ProjectionResult,
) -> @bytecode.ProjectionResult {
  {
    value_destination: value_to_slot(result.value_destination),
    witness_destination: result.witness_destination.map(value_to_slot),
  }
}

///|
fn projection_selection_to_bytecode(
  selection : ProjectionSelection,
) -> @bytecode.ProjectionSelection {
  {
    member_index: selection.member_index,
    result: projection_result_to_bytecode(selection.result),
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
    | ConstInt(destination, _)
    | ConstDouble(destination, _)
    | ConstBool(destination, _)
    | ConstLayout(destination, _)
    | ConstFunction(destination, _)
    | ConstString(destination, _)
    | MakeData(destination, _, _, _, _)
    | LoadTag(destination, _)
    | LoadObjectWitness(destination, _, _, _)
    | MakeEnv(destination, _, _, _, _)
    | MakeClosure(destination, _, _)
    | StringLength(destination, _)
    | StringConcat(destination, _, _)
    | StringSlice(destination, _, _, _)
    | StringEq(destination, _, _)
    | IntAdd(destination, _, _)
    | IntSub(destination, _, _)
    | IntMul(destination, _, _)
    | IntNeg(destination, _)
    | IntDiv(destination, _, _)
    | IntRem(destination, _, _)
    | IntAnd(destination, _, _)
    | IntOr(destination, _, _)
    | IntXor(destination, _, _)
    | IntNot(destination, _)
    | IntShl(destination, _, _)
    | IntShrS(destination, _, _)
    | IntEq(destination, _, _)
    | IntNe(destination, _, _)
    | IntLt(destination, _, _)
    | IntLe(destination, _, _)
    | IntGt(destination, _, _)
    | IntGe(destination, _, _)
    | BoolNot(destination, _)
    | BoolEq(destination, _, _)
    | BoolNe(destination, _, _)
    | DoubleAdd(destination, _, _)
    | DoubleSub(destination, _, _)
    | DoubleMul(destination, _, _)
    | DoubleDiv(destination, _, _)
    | DoubleNeg(destination, _)
    | DoubleEq(destination, _, _)
    | DoubleNe(destination, _, _)
    | DoubleLt(destination, _, _)
    | DoubleLe(destination, _, _)
    | DoubleGt(destination, _, _)
    | DoubleGe(destination, _, _)
    | IntToDouble(destination, _)
    | DoubleToInt(destination, _)
    | EraseI32(destination, _)
    | UneraseI32(destination, _)
    | EraseI64(destination, _)
    | UneraseI64(destination, _)
    | EraseF64(destination, _)
    | UneraseF64(destination, _)
    | EraseUnit(destination) => [destination]
    CallDirect(_, _, _, _, destination) | CallValue(_, _, _, destination) =>
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
    Release(_) | UneraseUnit(_) => []
  }
}

///|
fn finalize_terminator(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[@bytecode.Instruction],
  terminator : Terminator,
  original_block_count : Int,
  edge_blocks : Array[@bytecode.Block],
) -> @bytecode.Terminator raise FinalizeError {
  match terminator {
    Return(source) =>
      Return(
        source.map(value => {
          value_to_slot(
            consume_value(body, block, live, remaining, prefix, value),
          )
        }),
      )
    Jump(edge) =>
      Jump(finalize_edge(body, block, live, remaining, prefix, edge))
    BranchBool(condition, if_true, if_false) => {
      ignore(borrow_value(remaining, condition))
      let true_remaining = remaining.copy()
      subtract_edge_uses(true_remaining, if_false)
      let false_remaining = remaining.copy()
      subtract_edge_uses(false_remaining, if_true)
      let lowered_true = finalize_branch_edge(
        body, block, live, true_remaining, if_true, original_block_count, edge_blocks,
      )
      let lowered_false = finalize_branch_edge(
        body, block, live, false_remaining, if_false, original_block_count, edge_blocks,
      )
      for index in 0..<live.length() {
        live[index] = false
      }
      BranchBool(value_to_slot(condition), lowered_true, lowered_false)
    }
    SwitchTag(tag, cases, default) => {
      ignore(borrow_value(remaining, tag))
      let all_edges = cases.copy()
      all_edges.push(default)
      let lowered_edges = []
      for selected, edge in all_edges {
        let path_remaining = remaining.copy()
        for index, other in all_edges {
          if index != selected {
            subtract_edge_uses(path_remaining, other)
          }
        }
        lowered_edges.push(
          finalize_branch_edge(
            body, block, live, path_remaining, edge, original_block_count, edge_blocks,
          ),
        )
      }
      clear_live(live)
      let lowered_default = lowered_edges.pop().unwrap()
      SwitchTag(value_to_slot(tag), lowered_edges, lowered_default)
    }
    TailCallDirect(target, environment, witnesses, arguments) => {
      let lowered_environment = match environment {
        Some(value) =>
          Some(
            value_to_slot(
              consume_value(body, block, live, remaining, prefix, value),
            ),
          )
        None => None
      }
      TailCallDirect(
        target,
        lowered_environment,
        witnesses.map(value => value_to_slot(borrow_value(remaining, value))),
        arguments.map(value => {
          value_to_slot(
            consume_value(body, block, live, remaining, prefix, value),
          )
        }),
      )
    }
    TailCallValue(callable, witnesses, arguments) =>
      TailCallValue(
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, callable),
        ),
        witnesses.map(value => value_to_slot(borrow_value(remaining, value))),
        arguments.map(value => {
          value_to_slot(
            consume_value(body, block, live, remaining, prefix, value),
          )
        }),
      )
    Unreachable => Unreachable
  }
}

///|
fn clear_live(live : Array[Bool]) -> Unit {
  for index in 0..<live.length() {
    live[index] = false
  }
}

///|
fn subtract_edge_uses(remaining : Array[Int], edge : Edge) -> Unit {
  for value in edge.arguments {
    remaining[value.value] -= 1
  }
}

///|
fn finalize_branch_edge(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  edge : Edge,
  original_block_count : Int,
  edge_blocks : Array[@bytecode.Block],
) -> @bytecode.Edge raise FinalizeError {
  let edge_live = live.copy()
  let instructions : Array[@bytecode.Instruction] = []
  let lowered = finalize_edge(
    body, block, edge_live, remaining, instructions, edge,
  )
  for index, is_live in edge_live {
    if is_live {
      instructions.push(Release({ value: index }))
    }
  }
  if instructions.is_empty() {
    lowered
  } else {
    let trampoline : @bytecode.BlockId = {
      value: original_block_count + edge_blocks.length(),
    }
    edge_blocks.push({ parameters: [], instructions, terminator: Jump(lowered) })
    { target: trampoline, arguments: [] }
  }
}

///|
fn finalize_edge(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[@bytecode.Instruction],
  edge : Edge,
) -> @bytecode.Edge raise FinalizeError {
  {
    target: edge.target,
    arguments: edge.arguments.map(value => {
      value_to_slot(consume_value(body, block, live, remaining, prefix, value))
    }),
  }
}
