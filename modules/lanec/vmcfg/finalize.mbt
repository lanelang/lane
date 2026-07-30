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
  let image = devirtualize_image(image)
  let image = select_consuming_projections(image)
  let functions : Array[@bytecode.FunctionEntry] = []
  for entry in image.functions {
    match entry {
      Body(body) => functions.push(BytecodeBody(finalize_body(body)))
      RuntimeImport(import_) => functions.push(RuntimeImport(import_))
    }
  }
  {
    entry: image.entry,
    initializer: image.initializer,
    functions,
    globals: image.globals,
    layouts: image.layouts,
    object_shapes: image.object_shapes,
    constants: image.constants,
  }
}

///|
fn finalize_body(
  body : FunctionBody,
) -> @bytecode.FunctionBody raise FinalizeError {
  let body = simplify_body(body)
  let body = promote_cross_block_instruction_borrows(body)
  let body = thread_owned_block_values(body)
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
  if metadata.ownership is Borrowed && metadata.cleanup is OwnedErased {
    return {
      representation: metadata.representation,
      cleanup: OwnedErased,
      erased_companion: metadata.erased_companion.map(value_to_slot),
    }
  }
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
    ConstI64(destination, value) => ConstI64(value_to_slot(destination), value)
    ConstI32(destination, value) => ConstI32(value_to_slot(destination), value)
    ConstChar(destination, value) =>
      ConstChar(value_to_slot(destination), value)
    ConstF64(destination, bits) => ConstF64(value_to_slot(destination), bits)
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
    ByteToI64(destination, source) =>
      ByteToI64(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I64ToByte(destination, source) =>
      I64ToByte(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    ByteSequenceMake(destination, length, fill) =>
      ByteSequenceMake(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, length)),
        value_to_slot(borrow_value(remaining, fill)),
      )
    ByteSequenceLength(destination, source) =>
      ByteSequenceLength(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    ByteSequenceGet(destination, source, index) =>
      ByteSequenceGet(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
        value_to_slot(borrow_value(remaining, index)),
      )
    ByteSequenceSet(destination, source, index, value) =>
      ByteSequenceSet(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
        value_to_slot(borrow_value(remaining, index)),
        value_to_slot(borrow_value(remaining, value)),
      )
    ByteSequenceEqual(destination, left, right) =>
      ByteSequenceEqual(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    ByteSequenceConcat(destination, left, right) =>
      ByteSequenceConcat(
        value_to_slot(destination),
        value_to_slot(consume_value(body, block, live, remaining, prefix, left)),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, right),
        ),
      )
    ByteSequenceSlice(destination, source, start, length) =>
      ByteSequenceSlice(
        value_to_slot(destination),
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
        value_to_slot(borrow_value(remaining, start)),
        value_to_slot(borrow_value(remaining, length)),
      )
    ByteSequenceIsValidUtf8(destination, source) =>
      ByteSequenceIsValidUtf8(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I32Add(destination, left, right) =>
      I32Add(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32Sub(destination, left, right) =>
      I32Sub(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32Mul(destination, left, right) =>
      I32Mul(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32Neg(destination, source) =>
      I32Neg(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I32Div(destination, left, right) =>
      I32Div(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32Rem(destination, left, right) =>
      I32Rem(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32Eq(destination, left, right) =>
      I32Eq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32Lt(destination, left, right) =>
      I32Lt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I32ToI64(destination, source) =>
      I32ToI64(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I64ToI32(destination, source) =>
      I64ToI32(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I64Add(destination, left, right) =>
      I64Add(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Sub(destination, left, right) =>
      I64Sub(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Mul(destination, left, right) =>
      I64Mul(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Neg(destination, source) =>
      I64Neg(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I64Div(destination, left, right) =>
      I64Div(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Rem(destination, left, right) =>
      I64Rem(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64And(destination, left, right) =>
      I64And(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Or(destination, left, right) =>
      I64Or(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Xor(destination, left, right) =>
      I64Xor(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Not(destination, source) =>
      I64Not(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    I64Shl(destination, left, right) =>
      I64Shl(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64ShrS(destination, left, right) =>
      I64ShrS(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Eq(destination, left, right) =>
      I64Eq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Ne(destination, left, right) =>
      I64Ne(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Lt(destination, left, right) =>
      I64Lt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Le(destination, left, right) =>
      I64Le(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Gt(destination, left, right) =>
      I64Gt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64Ge(destination, left, right) =>
      I64Ge(
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
    F64Add(destination, left, right) =>
      F64Add(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Sub(destination, left, right) =>
      F64Sub(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Mul(destination, left, right) =>
      F64Mul(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Div(destination, left, right) =>
      F64Div(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Neg(destination, source) =>
      F64Neg(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    F64Eq(destination, left, right) =>
      F64Eq(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Ne(destination, left, right) =>
      F64Ne(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Lt(destination, left, right) =>
      F64Lt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Le(destination, left, right) =>
      F64Le(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Gt(destination, left, right) =>
      F64Gt(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    F64Ge(destination, left, right) =>
      F64Ge(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, left)),
        value_to_slot(borrow_value(remaining, right)),
      )
    I64ToF64(destination, source) =>
      I64ToF64(
        value_to_slot(destination),
        value_to_slot(borrow_value(remaining, source)),
      )
    F64ToI64(destination, source) =>
      F64ToI64(
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
    InitGlobal(global, source) =>
      InitGlobal(
        global,
        value_to_slot(
          consume_value(body, block, live, remaining, prefix, source),
        ),
      )
    BorrowGlobal(destination, global) =>
      BorrowGlobal(value_to_slot(destination), global)
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
    | ConstI64(destination, _)
    | ConstI32(destination, _)
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
    | EraseF64(destination, _)
    | UneraseF64(destination, _)
    | EraseUnit(destination)
    | BorrowGlobal(destination, _) => [destination]
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
    Release(_) | UneraseUnit(_) | InitGlobal(_, _) => []
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
