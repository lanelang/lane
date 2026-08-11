///|
fn allocate_finalized_slots(
  body : @bytecode.FunctionBody,
) -> @bytecode.FunctionBody {
  let slot_count = body.slots.length()
  if slot_count < 2 {
    return body
  }
  let active = Array::make(slot_count, false)
  let definitions = body.blocks.map(_ => Array::make(slot_count, false))
  let upward_uses = body.blocks.map(_ => Array::make(slot_count, false))
  for block_index, block in body.blocks {
    let defined = Array::make(slot_count, false)
    if block_index == 0 {
      for input in finalized_input_slots(body.inputs) {
        active[input.value] = true
        defined[input.value] = true
        definitions[block_index][input.value] = true
      }
    }
    for parameter in block.parameters {
      active[parameter.value] = true
      defined[parameter.value] = true
      definitions[block_index][parameter.value] = true
    }
    for instruction in block.instructions {
      for source in finalized_instruction_sources(instruction) {
        active[source.value] = true
        if !defined[source.value] {
          upward_uses[block_index][source.value] = true
        }
      }
      for destination in finalized_instruction_destinations(instruction) {
        active[destination.value] = true
        defined[destination.value] = true
        definitions[block_index][destination.value] = true
      }
    }
    for source in finalized_terminator_sources(block.terminator) {
      active[source.value] = true
      if !defined[source.value] {
        upward_uses[block_index][source.value] = true
      }
    }
  }
  for index, metadata in body.slots {
    if active[index] && metadata.erased_companion is Some(companion) {
      active[companion.value] = true
    }
  }
  let live_in = body.blocks.map(_ => Array::make(slot_count, false))
  let live_out = body.blocks.map(_ => Array::make(slot_count, false))
  let mut changed = true
  while changed {
    changed = false
    let mut block_index = body.blocks.length() - 1
    while block_index >= 0 {
      let next_out = Array::make(slot_count, false)
      for successor in finalized_successors(body.blocks[block_index].terminator) {
        for slot_index in 0..<slot_count {
          next_out[slot_index] = next_out[slot_index] ||
            live_in[successor][slot_index]
        }
      }
      let next_in = upward_uses[block_index].copy()
      for slot_index in 0..<slot_count {
        if next_out[slot_index] && !definitions[block_index][slot_index] {
          next_in[slot_index] = true
        }
      }
      if next_in != live_in[block_index] || next_out != live_out[block_index] {
        live_in[block_index] = next_in
        live_out[block_index] = next_out
        changed = true
      }
      block_index -= 1
    }
  }
  let interference = body.slots.map(_ => Array::make(slot_count, false))
  for block_index, block in body.blocks {
    let live = live_out[block_index].copy()
    for source in finalized_terminator_sources(block.terminator) {
      live[source.value] = true
    }
    let mut instruction_index = block.instructions.length() - 1
    while instruction_index >= 0 {
      let instruction = block.instructions[instruction_index]
      let destinations = finalized_instruction_destinations(instruction)
      let sources = finalized_instruction_sources(instruction)
      for destination in destinations {
        record_finalized_interference(interference, destination.value, live)
        for source in sources {
          if destination != source {
            interference[destination.value][source.value] = true
            interference[source.value][destination.value] = true
          }
        }
      }
      for destination in destinations {
        live[destination.value] = false
      }
      for source in sources {
        live[source.value] = true
      }
      instruction_index -= 1
    }
    let entry_definitions = if block_index == 0 {
      block.parameters + finalized_input_slots(body.inputs)
    } else {
      block.parameters
    }
    for definition in entry_definitions {
      record_finalized_interference(interference, definition.value, live)
    }
    record_finalized_simultaneous_definitions(interference, entry_definitions)
  }
  for owner, metadata in body.slots {
    if active[owner] && metadata.erased_companion is Some(companion) {
      for other in 0..<slot_count {
        if interference[owner][other] {
          interference[companion.value][other] = true
          interference[other][companion.value] = true
        }
      }
    }
  }
  let remap = Array::make(slot_count, -1)
  let allocated : Array[@bytecode.SlotMetadata] = []
  let allocated_values : Array[Array[Int]] = []
  for logical_index in 0..<slot_count {
    if !active[logical_index] {
      continue
    }
    let metadata = body.slots[logical_index]
    let reusable = !(metadata.cleanup is OwnedErased) &&
      metadata.erased_companion is None
    let mut physical_index = -1
    if reusable {
      for candidate, candidate_metadata in allocated {
        if candidate_metadata == metadata &&
          allocated_values[candidate].all(fn(other) {
            !interference[logical_index][other]
          }) {
          physical_index = candidate
          break
        }
      }
    }
    if physical_index < 0 {
      physical_index = allocated.length()
      allocated.push(metadata)
      allocated_values.push([])
    }
    allocated_values[physical_index].push(logical_index)
    remap[logical_index] = physical_index
  }
  if allocated.length() == slot_count {
    return body
  }
  let remap_slot = fn(slot : @bytecode.SlotId) -> @bytecode.SlotId {
    { value: remap[slot.value] }
  }
  {
    slots: allocated.map(fn(metadata) {
      {
        ..metadata,
        erased_companion: metadata.erased_companion.map(remap_slot),
      }
    }),
    inputs: {
      environment: body.inputs.environment.map(remap_slot),
      witnesses: body.inputs.witnesses.map(remap_slot),
      user_parameters: body.inputs.user_parameters.map(remap_slot),
    },
    result: body.result,
    blocks: body.blocks.map(fn(block) {
      {
        parameters: block.parameters.map(remap_slot),
        instructions: block.instructions.map(fn(instruction) {
          map_finalized_instruction_slots(instruction, remap_slot, remap_slot)
        }),
        terminator: map_finalized_terminator_slots(block.terminator, remap_slot),
      }
    }),
  }
}

///|
fn finalized_input_slots(
  inputs : @bytecode.FunctionInputs,
) -> Array[@bytecode.SlotId] {
  let slots : Array[@bytecode.SlotId] = []
  if inputs.environment is Some(environment) {
    slots.push(environment)
  }
  slots.append(inputs.witnesses)
  slots.append(inputs.user_parameters)
  slots
}

///|
fn finalized_instruction_destinations(
  instruction : @bytecode.Instruction,
) -> Array[@bytecode.SlotId] {
  let destinations : Array[@bytecode.SlotId] = []
  ignore(
    map_finalized_instruction_slots(
      instruction,
      fn(slot) {
        destinations.push(slot)
        slot
      },
      fn(slot) { slot },
    ),
  )
  destinations
}

///|
fn finalized_instruction_sources(
  instruction : @bytecode.Instruction,
) -> Array[@bytecode.SlotId] {
  let sources : Array[@bytecode.SlotId] = []
  ignore(
    map_finalized_instruction_slots(instruction, fn(slot) { slot }, fn(slot) {
      sources.push(slot)
      slot
    }),
  )
  sources
}

///|
fn finalized_terminator_sources(
  terminator : @bytecode.Terminator,
) -> Array[@bytecode.SlotId] {
  let sources : Array[@bytecode.SlotId] = []
  ignore(
    map_finalized_terminator_slots(terminator, fn(slot) {
      sources.push(slot)
      slot
    }),
  )
  sources
}

///|
fn finalized_successors(terminator : @bytecode.Terminator) -> Array[Int] {
  match terminator {
    Jump(edge) => [edge.target.value]
    BranchBool(_, if_true, if_false) =>
      [if_true.target.value, if_false.target.value]
    SwitchTag(_, cases, default) =>
      cases.map(fn(edge) { edge.target.value }) + [default.target.value]
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _, _)
    | Fatal(_)
    | Unreachable => []
  }
}

///|
fn record_finalized_interference(
  interference : Array[Array[Bool]],
  definition : Int,
  live : Array[Bool],
) -> Unit {
  for other, is_live in live {
    if is_live && other != definition {
      interference[definition][other] = true
      interference[other][definition] = true
    }
  }
}

///|
fn record_finalized_simultaneous_definitions(
  interference : Array[Array[Bool]],
  definitions : Array[@bytecode.SlotId],
) -> Unit {
  for left_index in 0..<definitions.length() {
    for right_index in (left_index + 1)..<definitions.length() {
      let left = definitions[left_index].value
      let right = definitions[right_index].value
      if left != right {
        interference[left][right] = true
        interference[right][left] = true
      }
    }
  }
}

///|
fn map_finalized_edge_slots(
  edge : @bytecode.Edge,
  transform : (@bytecode.SlotId) -> @bytecode.SlotId,
) -> @bytecode.Edge {
  { ..edge, arguments: edge.arguments.map(transform) }
}

///|
fn map_finalized_terminator_slots(
  terminator : @bytecode.Terminator,
  transform : (@bytecode.SlotId) -> @bytecode.SlotId,
) -> @bytecode.Terminator {
  match terminator {
    Jump(edge) => Jump(map_finalized_edge_slots(edge, transform))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(
        transform(condition),
        map_finalized_edge_slots(if_true, transform),
        map_finalized_edge_slots(if_false, transform),
      )
    SwitchTag(tag, cases, default) =>
      SwitchTag(
        transform(tag),
        cases.map(fn(edge) { map_finalized_edge_slots(edge, transform) }),
        map_finalized_edge_slots(default, transform),
      )
    Return(value) => Return(value.map(transform))
    TailCallDirect(target, environment, witnesses, arguments) =>
      TailCallDirect(
        target,
        environment.map(transform),
        witnesses.map(transform),
        arguments.map(transform),
      )
    TailCallValue(callable, abi, witnesses, arguments) =>
      TailCallValue(
        transform(callable),
        abi,
        witnesses.map(transform),
        arguments.map(transform),
      )
    Fatal(message) => Fatal(transform(message))
    Unreachable => Unreachable
  }
}

///|
fn map_finalized_layout_operand_slots(
  layout : @bytecode.LayoutOperand,
  transform : (@bytecode.SlotId) -> @bytecode.SlotId,
) -> @bytecode.LayoutOperand {
  match layout {
    Immediate(_) => layout
    Witness(value) => Witness(transform(value))
  }
}

///|
fn map_finalized_projection_result_slots(
  result : @bytecode.ProjectionResult,
  map_destination : (@bytecode.SlotId) -> @bytecode.SlotId,
) -> @bytecode.ProjectionResult {
  {
    value_destination: map_destination(result.value_destination),
    witness_destination: result.witness_destination.map(map_destination),
  }
}

///|
fn map_finalized_projection_selection_slots(
  selection : @bytecode.ProjectionSelection,
  map_destination : (@bytecode.SlotId) -> @bytecode.SlotId,
) -> @bytecode.ProjectionSelection {
  {
    member_index: selection.member_index,
    result: map_finalized_projection_result_slots(
      selection.result,
      map_destination,
    ),
  }
}

///|
fn map_finalized_instruction_slots(
  instruction : @bytecode.Instruction,
  map_destination : (@bytecode.SlotId) -> @bytecode.SlotId,
  map_source : (@bytecode.SlotId) -> @bytecode.SlotId,
) -> @bytecode.Instruction {
  match instruction {
    Copy(destination, source) =>
      Copy(map_destination(destination), map_source(source))
    Move(destination, source) =>
      Move(map_destination(destination), map_source(source))
    RetainCopy(destination, source) =>
      RetainCopy(map_destination(destination), map_source(source))
    Release(value) => Release(map_source(value))
    ConstI64(destination, value) =>
      ConstI64(map_destination(destination), value)
    ConstI32(destination, value) =>
      ConstI32(map_destination(destination), value)
    ConstF32(destination, bits) => ConstF32(map_destination(destination), bits)
    ConstChar(destination, value) =>
      ConstChar(map_destination(destination), value)
    ConstF64(destination, bits) => ConstF64(map_destination(destination), bits)
    ConstBool(destination, value) =>
      ConstBool(map_destination(destination), value)
    ConstLayout(destination, layout) =>
      ConstLayout(map_destination(destination), layout)
    ConstFunction(destination, function) =>
      ConstFunction(map_destination(destination), function)
    ConstString(destination, constant) =>
      ConstString(map_destination(destination), constant)
    CallDirect(target, environment, witnesses, arguments, destination) =>
      CallDirect(
        target,
        environment.map(map_source),
        witnesses.map(map_source),
        arguments.map(map_source),
        destination.map(map_destination),
      )
    CallValue(callable, abi, witnesses, arguments, destination) =>
      CallValue(
        map_source(callable),
        abi,
        witnesses.map(map_source),
        arguments.map(map_source),
        destination.map(map_destination),
      )
    MakeData(destination, shape, layout, witnesses, fields) =>
      MakeData(
        map_destination(destination),
        shape,
        map_finalized_layout_operand_slots(layout, map_source),
        witnesses.map(map_source),
        fields.map(map_source),
      )
    LoadTag(destination, source) =>
      LoadTag(map_destination(destination), map_source(source))
    LoadObjectWitness(destination, shape, source, index) =>
      LoadObjectWitness(
        map_destination(destination),
        shape,
        map_source(source),
        index,
      )
    BorrowField(shape, source, index, result) =>
      BorrowField(
        shape,
        map_source(source),
        index,
        map_finalized_projection_result_slots(result, map_destination),
      )
    ConsumeFields(shape, source, selections) =>
      ConsumeFields(
        shape,
        map_source(source),
        selections.map(fn(selection) {
          map_finalized_projection_selection_slots(selection, map_destination)
        }),
      )
    MakeEnv(destination, shape, layout, witnesses, fields) =>
      MakeEnv(
        map_destination(destination),
        shape,
        map_finalized_layout_operand_slots(layout, map_source),
        witnesses.map(map_source),
        fields.map(map_source),
      )
    BorrowCapture(shape, source, index, result) =>
      BorrowCapture(
        shape,
        map_source(source),
        index,
        map_finalized_projection_result_slots(result, map_destination),
      )
    ConsumeCaptures(shape, source, selections) =>
      ConsumeCaptures(
        shape,
        map_source(source),
        selections.map(fn(selection) {
          map_finalized_projection_selection_slots(selection, map_destination)
        }),
      )
    MakeClosure(destination, function, environment) =>
      MakeClosure(
        map_destination(destination),
        function,
        map_source(environment),
      )
    ByteToI64(destination, source) =>
      ByteToI64(map_destination(destination), map_source(source))
    I64ToByte(destination, source) =>
      I64ToByte(map_destination(destination), map_source(source))
    ByteSequenceMake(destination, length, fill) =>
      ByteSequenceMake(
        map_destination(destination),
        map_source(length),
        map_source(fill),
      )
    ByteSequenceLength(destination, source) =>
      ByteSequenceLength(map_destination(destination), map_source(source))
    ByteSequenceGet(destination, source, index) =>
      ByteSequenceGet(
        map_destination(destination),
        map_source(source),
        map_source(index),
      )
    ByteSequenceSet(destination, source, index, value) =>
      ByteSequenceSet(
        map_destination(destination),
        map_source(source),
        map_source(index),
        map_source(value),
      )
    ByteSequenceEqual(destination, left, right) =>
      ByteSequenceEqual(
        map_destination(destination),
        map_source(left),
        map_source(right),
      )
    ByteSequenceConcat(destination, left, right) =>
      ByteSequenceConcat(
        map_destination(destination),
        map_source(left),
        map_source(right),
      )
    ByteSequenceSlice(destination, source, start, length) =>
      ByteSequenceSlice(
        map_destination(destination),
        map_source(source),
        map_source(start),
        map_source(length),
      )
    ByteSequenceIsValidUtf8(destination, source) =>
      ByteSequenceIsValidUtf8(map_destination(destination), map_source(source))
    I32Add(destination, left, right) =>
      I32Add(map_destination(destination), map_source(left), map_source(right))
    I32Sub(destination, left, right) =>
      I32Sub(map_destination(destination), map_source(left), map_source(right))
    I32Mul(destination, left, right) =>
      I32Mul(map_destination(destination), map_source(left), map_source(right))
    I32Neg(destination, source) =>
      I32Neg(map_destination(destination), map_source(source))
    I32Div(destination, left, right) =>
      I32Div(map_destination(destination), map_source(left), map_source(right))
    I32Rem(destination, left, right) =>
      I32Rem(map_destination(destination), map_source(left), map_source(right))
    I32Eq(destination, left, right) =>
      I32Eq(map_destination(destination), map_source(left), map_source(right))
    I32Lt(destination, left, right) =>
      I32Lt(map_destination(destination), map_source(left), map_source(right))
    I32ToI64(destination, source) =>
      I32ToI64(map_destination(destination), map_source(source))
    I64ToI32(destination, source) =>
      I64ToI32(map_destination(destination), map_source(source))
    I64Add(destination, left, right) =>
      I64Add(map_destination(destination), map_source(left), map_source(right))
    I64Sub(destination, left, right) =>
      I64Sub(map_destination(destination), map_source(left), map_source(right))
    I64Mul(destination, left, right) =>
      I64Mul(map_destination(destination), map_source(left), map_source(right))
    I64Neg(destination, source) =>
      I64Neg(map_destination(destination), map_source(source))
    I64Div(destination, left, right) =>
      I64Div(map_destination(destination), map_source(left), map_source(right))
    I64Rem(destination, left, right) =>
      I64Rem(map_destination(destination), map_source(left), map_source(right))
    I64And(destination, left, right) =>
      I64And(map_destination(destination), map_source(left), map_source(right))
    I64Or(destination, left, right) =>
      I64Or(map_destination(destination), map_source(left), map_source(right))
    I64Xor(destination, left, right) =>
      I64Xor(map_destination(destination), map_source(left), map_source(right))
    I64Not(destination, source) =>
      I64Not(map_destination(destination), map_source(source))
    I64Shl(destination, left, right) =>
      I64Shl(map_destination(destination), map_source(left), map_source(right))
    I64ShrS(destination, left, right) =>
      I64ShrS(map_destination(destination), map_source(left), map_source(right))
    I64Eq(destination, left, right) =>
      I64Eq(map_destination(destination), map_source(left), map_source(right))
    I64Ne(destination, left, right) =>
      I64Ne(map_destination(destination), map_source(left), map_source(right))
    I64Lt(destination, left, right) =>
      I64Lt(map_destination(destination), map_source(left), map_source(right))
    I64Le(destination, left, right) =>
      I64Le(map_destination(destination), map_source(left), map_source(right))
    I64Gt(destination, left, right) =>
      I64Gt(map_destination(destination), map_source(left), map_source(right))
    I64Ge(destination, left, right) =>
      I64Ge(map_destination(destination), map_source(left), map_source(right))
    BoolNot(destination, source) =>
      BoolNot(map_destination(destination), map_source(source))
    BoolEq(destination, left, right) =>
      BoolEq(map_destination(destination), map_source(left), map_source(right))
    BoolNe(destination, left, right) =>
      BoolNe(map_destination(destination), map_source(left), map_source(right))
    F32Add(destination, left, right) =>
      F32Add(map_destination(destination), map_source(left), map_source(right))
    F32Sub(destination, left, right) =>
      F32Sub(map_destination(destination), map_source(left), map_source(right))
    F32Mul(destination, left, right) =>
      F32Mul(map_destination(destination), map_source(left), map_source(right))
    F32Div(destination, left, right) =>
      F32Div(map_destination(destination), map_source(left), map_source(right))
    F32Neg(destination, source) =>
      F32Neg(map_destination(destination), map_source(source))
    F32Eq(destination, left, right) =>
      F32Eq(map_destination(destination), map_source(left), map_source(right))
    F32Ne(destination, left, right) =>
      F32Ne(map_destination(destination), map_source(left), map_source(right))
    F32Lt(destination, left, right) =>
      F32Lt(map_destination(destination), map_source(left), map_source(right))
    F32Le(destination, left, right) =>
      F32Le(map_destination(destination), map_source(left), map_source(right))
    F32Gt(destination, left, right) =>
      F32Gt(map_destination(destination), map_source(left), map_source(right))
    F32Ge(destination, left, right) =>
      F32Ge(map_destination(destination), map_source(left), map_source(right))
    I64ToF32(destination, source) =>
      I64ToF32(map_destination(destination), map_source(source))
    F32ToI64(destination, source) =>
      F32ToI64(map_destination(destination), map_source(source))
    F32ToF64(destination, source) =>
      F32ToF64(map_destination(destination), map_source(source))
    F64ToF32(destination, source) =>
      F64ToF32(map_destination(destination), map_source(source))
    F32ToString(destination, source) =>
      F32ToString(map_destination(destination), map_source(source))
    F64ToString(destination, source) =>
      F64ToString(map_destination(destination), map_source(source))
    F64Add(destination, left, right) =>
      F64Add(map_destination(destination), map_source(left), map_source(right))
    F64Sub(destination, left, right) =>
      F64Sub(map_destination(destination), map_source(left), map_source(right))
    F64Mul(destination, left, right) =>
      F64Mul(map_destination(destination), map_source(left), map_source(right))
    F64Div(destination, left, right) =>
      F64Div(map_destination(destination), map_source(left), map_source(right))
    F64Neg(destination, source) =>
      F64Neg(map_destination(destination), map_source(source))
    F64Eq(destination, left, right) =>
      F64Eq(map_destination(destination), map_source(left), map_source(right))
    F64Ne(destination, left, right) =>
      F64Ne(map_destination(destination), map_source(left), map_source(right))
    F64Lt(destination, left, right) =>
      F64Lt(map_destination(destination), map_source(left), map_source(right))
    F64Le(destination, left, right) =>
      F64Le(map_destination(destination), map_source(left), map_source(right))
    F64Gt(destination, left, right) =>
      F64Gt(map_destination(destination), map_source(left), map_source(right))
    F64Ge(destination, left, right) =>
      F64Ge(map_destination(destination), map_source(left), map_source(right))
    I64ToF64(destination, source) =>
      I64ToF64(map_destination(destination), map_source(source))
    F64ToI64(destination, source) =>
      F64ToI64(map_destination(destination), map_source(source))
    EraseI32(destination, source) =>
      EraseI32(map_destination(destination), map_source(source))
    UneraseI32(destination, source) =>
      UneraseI32(map_destination(destination), map_source(source))
    EraseI64(destination, source) =>
      EraseI64(map_destination(destination), map_source(source))
    UneraseI64(destination, source) =>
      UneraseI64(map_destination(destination), map_source(source))
    EraseF32(destination, source) =>
      EraseF32(map_destination(destination), map_source(source))
    UneraseF32(destination, source) =>
      UneraseF32(map_destination(destination), map_source(source))
    EraseF64(destination, source) =>
      EraseF64(map_destination(destination), map_source(source))
    UneraseF64(destination, source) =>
      UneraseF64(map_destination(destination), map_source(source))
    EraseUnit(destination) => EraseUnit(map_destination(destination))
    UneraseUnit(source) => UneraseUnit(map_source(source))
    InitGlobal(global, source) => InitGlobal(global, map_source(source))
    BorrowGlobal(destination, global) =>
      BorrowGlobal(map_destination(destination), global)
  }
}
