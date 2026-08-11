///|
fn simplify_body(body : FunctionBody) -> FunctionBody {
  let mut simplified = body
  let iteration_limit = body.blocks.length() + body.values.length() + 1
  for _ in 0..<iteration_limit {
    let next = simplify_body_once(simplified)
    if next == simplified {
      break
    }
    simplified = next
  }
  simplified
}

///|
fn simplify_body_once(body : FunctionBody) -> FunctionBody {
  let body = { ..body, blocks: propagate_local_scalar_values(body) }
  let body = { ..body, blocks: body.blocks.map(fold_constant_terminator) }
  let body = { ..body, blocks: remove_dead_scalar_instructions(body) }
  let body = { ..body, blocks: remove_unused_block_parameters(body) }
  let body = { ..body, blocks: thread_empty_jump_blocks(body) }
  let body = { ..body, blocks: merge_linear_blocks(body.blocks) }
  { ..body, blocks: remove_unreachable_blocks(body.blocks) }
}

///|
fn propagate_local_scalar_values(body : FunctionBody) -> Array[Block] {
  let use_def = analyze_use_def(body)
  body.blocks.mapi(fn(block_index, block) {
    let aliases : Array[(ValueId, ValueId)] = []
    let constants : Array[(Instruction, ValueId)] = []
    let instructions = []
    for original in block.instructions {
      let instruction = map_instruction_values(original, fn(value) {
        resolve_value_alias(value, aliases)
      })
      let destinations = instruction_destinations(instruction)
      let local_destination = match destinations {
        [destination] if use_def.is_used_only_in_block(destination, block_index) &&
          body.values[destination.value].ownership is Trivial &&
          !value_is_erased_companion(body.values, destination) =>
          Some(destination)
        _ => None
      }
      match instruction {
        Copy(destination, source) if local_destination == Some(destination) &&
          compatible_trivial_values(body.values, destination, source) =>
          aliases.push((destination, source))
        _ if local_destination is Some(destination) &&
          instruction_is_scalar_constant(instruction) =>
          match find_equivalent_constant(instruction, constants) {
            Some(existing) if compatible_trivial_values(
                body.values,
                destination,
                existing,
              ) => aliases.push((destination, existing))
            _ => {
              constants.push((instruction, destination))
              instructions.push(instruction)
            }
          }
        _ => instructions.push(instruction)
      }
    }
    {
      ..block,
      instructions,
      terminator: map_terminator_values(block.terminator, fn(value) {
        resolve_value_alias(value, aliases)
      }),
    }
  })
}

///|
fn resolve_value_alias(
  initial : ValueId,
  aliases : Array[(ValueId, ValueId)],
) -> ValueId {
  let mut value = initial
  for index = aliases.length() - 1; index >= 0; index = index - 1 {
    let (candidate, replacement) = aliases[index]
    if candidate == value {
      value = replacement
    }
  }
  value
}

///|
fn compatible_trivial_values(
  values : Array[ValueMetadata],
  left : ValueId,
  right : ValueId,
) -> Bool {
  values[left.value] == values[right.value] &&
  values[left.value].ownership is Trivial &&
  values[left.value].cleanup is Trivial &&
  values[left.value].erased_companion is None
}

///|
fn instruction_is_scalar_constant(instruction : Instruction) -> Bool {
  match instruction {
    ConstI64(_, _)
    | ConstI32(_, _)
    | ConstF32(_, _)
    | ConstChar(_, _)
    | ConstF64(_, _)
    | ConstBool(_, _)
    | ConstLayout(_, _)
    | ConstFunction(_, _) => true
    _ => false
  }
}

///|
fn find_equivalent_constant(
  instruction : Instruction,
  constants : Array[(Instruction, ValueId)],
) -> ValueId? {
  for entry in constants {
    let (candidate, value) = entry
    if scalar_constants_equal(instruction, candidate) {
      return Some(value)
    }
  }
  None
}

///|
fn scalar_constants_equal(left : Instruction, right : Instruction) -> Bool {
  match (left, right) {
    (ConstI64(_, left), ConstI64(_, right)) => left == right
    (ConstI32(_, left), ConstI32(_, right)) => left == right
    (ConstF32(_, left), ConstF32(_, right)) => left == right
    (ConstChar(_, left), ConstChar(_, right)) => left == right
    (ConstF64(_, left), ConstF64(_, right)) => left == right
    (ConstBool(_, left), ConstBool(_, right)) => left == right
    (ConstLayout(_, left), ConstLayout(_, right)) => left == right
    (ConstFunction(_, left), ConstFunction(_, right)) => left == right
    _ => false
  }
}

///|
fn fold_constant_terminator(block : Block) -> Block {
  let terminator = match block.terminator {
    BranchBool(condition, if_true, if_false) =>
      match find_bool_constant(block.instructions, condition) {
        Some(true) => Jump(if_true)
        Some(false) => Jump(if_false)
        None => block.terminator
      }
    SwitchTag(tag, cases, default) =>
      match find_int_constant(block.instructions, tag) {
        Some(value) if value >= 0L && value < cases.length().to_int64() =>
          Jump(cases[value.to_int()])
        _ => SwitchTag(tag, cases, default)
      }
    _ => block.terminator
  }
  { ..block, terminator, }
}

///|
fn find_bool_constant(
  instructions : Array[Instruction],
  value : ValueId,
) -> Bool? {
  for instruction in instructions {
    if instruction is ConstBool(destination, constant) && destination == value {
      return Some(constant)
    }
  }
  None
}

///|
fn find_int_constant(
  instructions : Array[Instruction],
  value : ValueId,
) -> Int64? {
  for instruction in instructions {
    if instruction is ConstI64(destination, constant) && destination == value {
      return Some(constant)
    }
  }
  None
}

///|
fn remove_dead_scalar_instructions(body : FunctionBody) -> Array[Block] {
  let control_flow = analyze_control_flow(body.blocks)
  let use_def = analyze_use_def(body)
  let liveness = analyze_liveness(body, control_flow, use_def)
  body.blocks.mapi(fn(block_index, block) {
    let instructions = []
    for instruction_index, instruction in block.instructions {
      let keep = if !instruction_is_dead_scalar_candidate(instruction) {
        true
      } else {
        let destinations = instruction_destinations(instruction)
        destinations.is_empty() ||
        destinations.any(destination => {
          liveness.is_live_after_instruction(
            body, block_index, instruction_index, destination,
          ) ||
          body.values[destination.value].ownership != Trivial ||
          value_is_erased_companion(body.values, destination)
        })
      }
      if keep {
        instructions.push(instruction)
      }
    }
    { ..block, instructions, }
  })
}

///|
fn value_is_erased_companion(
  values : Array[ValueMetadata],
  value : ValueId,
) -> Bool {
  values.any(metadata => metadata.erased_companion == Some(value))
}

///|
fn instruction_is_dead_scalar_candidate(instruction : Instruction) -> Bool {
  match instruction {
    Copy(_, _)
    | ConstI64(_, _)
    | ConstI32(_, _)
    | ConstF32(_, _)
    | ConstChar(_, _)
    | ConstF64(_, _)
    | ConstBool(_, _)
    | ConstLayout(_, _)
    | ConstFunction(_, _)
    | I32Add(_, _, _)
    | I32Sub(_, _, _)
    | I32Mul(_, _, _)
    | I32Neg(_, _)
    | I32Eq(_, _, _)
    | I32Lt(_, _, _)
    | I32ToI64(_, _)
    | I64ToI32(_, _)
    | I64Add(_, _, _)
    | I64Sub(_, _, _)
    | I64Mul(_, _, _)
    | I64Neg(_, _)
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
    | F32ToF64(_, _)
    | F64ToF32(_, _)
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
    | EraseI32(_, _)
    | UneraseI32(_, _)
    | EraseI64(_, _)
    | UneraseI64(_, _)
    | EraseF32(_, _)
    | UneraseF32(_, _)
    | EraseF64(_, _)
    | UneraseF64(_, _)
    | EraseUnit(_) => true
    _ => false
  }
}

///|
fn remove_unused_block_parameters(body : FunctionBody) -> Array[Block] {
  let use_def = analyze_use_def(body)
  let kept_parameters = body.blocks.map(fn(block) {
    block.parameters.map(fn(parameter) { use_def.use_count(parameter) > 0 })
  })
  body.blocks.mapi(fn(block_index, block) {
    {
      parameters: filter_values_by_mask(
        block.parameters,
        kept_parameters[block_index],
      ),
      instructions: block.instructions,
      terminator: map_terminator_edges(block.terminator, fn(edge) {
        let kept = kept_parameters[edge.target.value]
        { ..edge, arguments: filter_edge_arguments(edge.arguments, kept) }
      }),
    }
  })
}

///|
fn filter_values_by_mask(
  values : Array[ValueId],
  kept : Array[Bool],
) -> Array[ValueId] {
  let filtered = []
  for index, value in values {
    if kept[index] {
      filtered.push(value)
    }
  }
  filtered
}

///|
fn filter_edge_arguments(
  arguments : Array[ValueId],
  kept : Array[Bool],
) -> Array[ValueId] {
  let filtered = []
  for index, argument in arguments {
    if index >= kept.length() || kept[index] {
      filtered.push(argument)
    }
  }
  filtered
}

///|
fn thread_empty_jump_blocks(body : FunctionBody) -> Array[Block] {
  let use_def = analyze_use_def(body)
  body.blocks.map(fn(block) {
    {
      ..block,
      terminator: map_terminator_edges(block.terminator, fn(edge) {
        thread_edge(edge, body.blocks, use_def)
      }),
    }
  })
}

///|
fn thread_edge(
  initial : Edge,
  blocks : Array[Block],
  use_def : UseDefAnalysis,
) -> Edge {
  let mut edge = initial
  let visited = Array::make(blocks.length(), false)
  while edge.target.value != 0 && !visited[edge.target.value] {
    let target_index = edge.target.value
    visited[target_index] = true
    let target = blocks[target_index]
    guard target.instructions.is_empty() &&
      target.terminator is Jump(next) &&
      target.parameters.length() == edge.arguments.length() &&
      target.parameters.all(parameter => {
        use_def.is_used_only_in_block(parameter, target_index)
      }) else {
      break
    }
    edge = {
      target: next.target,
      arguments: next.arguments.map(fn(argument) {
        substitute_block_parameter(argument, target.parameters, edge.arguments)
      }),
    }
  }
  edge
}

///|
fn substitute_block_parameter(
  value : ValueId,
  parameters : Array[ValueId],
  arguments : Array[ValueId],
) -> ValueId {
  for index, parameter in parameters {
    if value == parameter {
      return arguments[index]
    }
  }
  value
}

///|
fn merge_linear_blocks(blocks : Array[Block]) -> Array[Block] {
  let control_flow = analyze_control_flow(blocks)
  blocks.mapi(fn(index, block) {
    guard block.terminator is Jump(edge) &&
      edge.target.value != index &&
      edge.arguments.is_empty() else {
      return block
    }
    let target = blocks[edge.target.value]
    if control_flow.predecessors[edge.target.value].length() == 1 &&
      control_flow.dominates(index, edge.target.value) &&
      control_flow.immediate_dominators[edge.target.value] == Some(index) &&
      target.parameters.is_empty() {
      {
        parameters: block.parameters,
        instructions: block.instructions + target.instructions,
        terminator: target.terminator,
      }
    } else {
      block
    }
  })
}

///|
fn remove_unreachable_blocks(blocks : Array[Block]) -> Array[Block] {
  let control_flow = analyze_control_flow(blocks)
  let remap = Array::make(blocks.length(), -1)
  let compacted = []
  for index, block in blocks {
    if control_flow.reachable[index] {
      remap[index] = compacted.length()
      compacted.push(block)
    }
  }
  compacted.map(fn(block) {
    {
      ..block,
      terminator: map_terminator_edges(block.terminator, fn(edge) {
        { ..edge, target: { value: remap[edge.target.value] } }
      }),
    }
  })
}

///|
fn map_terminator_edges(
  terminator : Terminator,
  transform : (Edge) -> Edge,
) -> Terminator {
  match terminator {
    Jump(edge) => Jump(transform(edge))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(condition, transform(if_true), transform(if_false))
    SwitchTag(tag, cases, default) =>
      SwitchTag(tag, cases.map(transform), transform(default))
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal(_)
    | Unreachable => terminator
  }
}

///|
fn map_terminator_values(
  terminator : Terminator,
  transform : (ValueId) -> ValueId,
) -> Terminator {
  match terminator {
    Jump(edge) => Jump(map_edge_values(edge, transform))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(
        transform(condition),
        map_edge_values(if_true, transform),
        map_edge_values(if_false, transform),
      )
    SwitchTag(tag, cases, default) =>
      SwitchTag(
        transform(tag),
        cases.map(fn(edge) { map_edge_values(edge, transform) }),
        map_edge_values(default, transform),
      )
    Return(value) => Return(value.map(transform))
    TailCallDirect(target, environment, witnesses, arguments) =>
      TailCallDirect(
        target,
        environment.map(transform),
        witnesses.map(transform),
        arguments.map(transform),
      )
    TailCallValue(callable, witnesses, arguments) =>
      TailCallValue(
        transform(callable),
        witnesses.map(transform),
        arguments.map(transform),
      )
    Fatal(message) => Fatal(transform(message))
    Unreachable => Unreachable
  }
}

///|
fn map_edge_values(edge : Edge, transform : (ValueId) -> ValueId) -> Edge {
  { ..edge, arguments: edge.arguments.map(transform) }
}

///|
fn map_projection_result_values(
  result : ProjectionResult,
  transform : (ValueId) -> ValueId,
) -> ProjectionResult {
  {
    value_destination: transform(result.value_destination),
    witness_destination: result.witness_destination.map(transform),
  }
}

///|
fn map_projection_selection_values(
  selection : ProjectionSelection,
  transform : (ValueId) -> ValueId,
) -> ProjectionSelection {
  {
    member_index: selection.member_index,
    result: map_projection_result_values(selection.result, transform),
  }
}

///|
fn map_layout_operand_values(
  layout : LayoutOperand,
  transform : (ValueId) -> ValueId,
) -> LayoutOperand {
  match layout {
    Immediate(_) => layout
    Witness(value) => Witness(transform(value))
  }
}

///|
fn map_instruction_values(
  instruction : Instruction,
  transform : (ValueId) -> ValueId,
) -> Instruction {
  match instruction {
    Copy(destination, source) => Copy(transform(destination), transform(source))
    Move(destination, source) => Move(transform(destination), transform(source))
    RetainCopy(destination, source) =>
      RetainCopy(transform(destination), transform(source))
    Release(value) => Release(transform(value))
    ConstI64(destination, value) => ConstI64(transform(destination), value)
    ConstI32(destination, value) => ConstI32(transform(destination), value)
    ConstF32(destination, bits) => ConstF32(transform(destination), bits)
    ConstChar(destination, value) => ConstChar(transform(destination), value)
    ConstF64(destination, bits) => ConstF64(transform(destination), bits)
    ConstBool(destination, value) => ConstBool(transform(destination), value)
    ConstLayout(destination, layout) =>
      ConstLayout(transform(destination), layout)
    ConstFunction(destination, function) =>
      ConstFunction(transform(destination), function)
    ConstString(destination, constant) =>
      ConstString(transform(destination), constant)
    CallDirect(target, environment, witnesses, arguments, destination) =>
      CallDirect(
        target,
        environment.map(transform),
        witnesses.map(transform),
        arguments.map(transform),
        destination.map(transform),
      )
    CallValue(callable, witnesses, arguments, destination) =>
      CallValue(
        transform(callable),
        witnesses.map(transform),
        arguments.map(transform),
        destination.map(transform),
      )
    MakeData(destination, shape, layout, witnesses, fields) =>
      MakeData(
        transform(destination),
        shape,
        map_layout_operand_values(layout, transform),
        witnesses.map(transform),
        fields.map(transform),
      )
    LoadTag(destination, source) =>
      LoadTag(transform(destination), transform(source))
    LoadObjectWitness(destination, shape, source, index) =>
      LoadObjectWitness(transform(destination), shape, transform(source), index)
    BorrowField(shape, source, index, result) =>
      BorrowField(
        shape,
        transform(source),
        index,
        map_projection_result_values(result, transform),
      )
    ConsumeFields(shape, source, selections) =>
      ConsumeFields(
        shape,
        transform(source),
        selections.map(fn(selection) {
          map_projection_selection_values(selection, transform)
        }),
      )
    MakeEnv(destination, shape, layout, witnesses, fields) =>
      MakeEnv(
        transform(destination),
        shape,
        map_layout_operand_values(layout, transform),
        witnesses.map(transform),
        fields.map(transform),
      )
    BorrowCapture(shape, source, index, result) =>
      BorrowCapture(
        shape,
        transform(source),
        index,
        map_projection_result_values(result, transform),
      )
    ConsumeCaptures(shape, source, selections) =>
      ConsumeCaptures(
        shape,
        transform(source),
        selections.map(fn(selection) {
          map_projection_selection_values(selection, transform)
        }),
      )
    MakeClosure(destination, function, environment) =>
      MakeClosure(transform(destination), function, transform(environment))
    ByteToI64(destination, source) =>
      ByteToI64(transform(destination), transform(source))
    I64ToByte(destination, source) =>
      I64ToByte(transform(destination), transform(source))
    ByteSequenceMake(destination, length, fill) =>
      ByteSequenceMake(
        transform(destination),
        transform(length),
        transform(fill),
      )
    ByteSequenceLength(destination, source) =>
      ByteSequenceLength(transform(destination), transform(source))
    ByteSequenceGet(destination, source, index) =>
      ByteSequenceGet(
        transform(destination),
        transform(source),
        transform(index),
      )
    ByteSequenceSet(destination, source, index, value) =>
      ByteSequenceSet(
        transform(destination),
        transform(source),
        transform(index),
        transform(value),
      )
    ByteSequenceEqual(destination, left, right) =>
      ByteSequenceEqual(
        transform(destination),
        transform(left),
        transform(right),
      )
    ByteSequenceConcat(destination, left, right) =>
      ByteSequenceConcat(
        transform(destination),
        transform(left),
        transform(right),
      )
    ByteSequenceSlice(destination, source, start, length) =>
      ByteSequenceSlice(
        transform(destination),
        transform(source),
        transform(start),
        transform(length),
      )
    ByteSequenceIsValidUtf8(destination, source) =>
      ByteSequenceIsValidUtf8(transform(destination), transform(source))
    I32Add(destination, left, right) =>
      I32Add(transform(destination), transform(left), transform(right))
    I32Sub(destination, left, right) =>
      I32Sub(transform(destination), transform(left), transform(right))
    I32Mul(destination, left, right) =>
      I32Mul(transform(destination), transform(left), transform(right))
    I32Neg(destination, source) =>
      I32Neg(transform(destination), transform(source))
    I32Div(destination, left, right) =>
      I32Div(transform(destination), transform(left), transform(right))
    I32Rem(destination, left, right) =>
      I32Rem(transform(destination), transform(left), transform(right))
    I32Eq(destination, left, right) =>
      I32Eq(transform(destination), transform(left), transform(right))
    I32Lt(destination, left, right) =>
      I32Lt(transform(destination), transform(left), transform(right))
    I32ToI64(destination, source) =>
      I32ToI64(transform(destination), transform(source))
    I64ToI32(destination, source) =>
      I64ToI32(transform(destination), transform(source))
    I64Add(destination, left, right) =>
      I64Add(transform(destination), transform(left), transform(right))
    I64Sub(destination, left, right) =>
      I64Sub(transform(destination), transform(left), transform(right))
    I64Mul(destination, left, right) =>
      I64Mul(transform(destination), transform(left), transform(right))
    I64Neg(destination, source) =>
      I64Neg(transform(destination), transform(source))
    I64Div(destination, left, right) =>
      I64Div(transform(destination), transform(left), transform(right))
    I64Rem(destination, left, right) =>
      I64Rem(transform(destination), transform(left), transform(right))
    I64And(destination, left, right) =>
      I64And(transform(destination), transform(left), transform(right))
    I64Or(destination, left, right) =>
      I64Or(transform(destination), transform(left), transform(right))
    I64Xor(destination, left, right) =>
      I64Xor(transform(destination), transform(left), transform(right))
    I64Not(destination, source) =>
      I64Not(transform(destination), transform(source))
    I64Shl(destination, left, right) =>
      I64Shl(transform(destination), transform(left), transform(right))
    I64ShrS(destination, left, right) =>
      I64ShrS(transform(destination), transform(left), transform(right))
    I64Eq(destination, left, right) =>
      I64Eq(transform(destination), transform(left), transform(right))
    I64Ne(destination, left, right) =>
      I64Ne(transform(destination), transform(left), transform(right))
    I64Lt(destination, left, right) =>
      I64Lt(transform(destination), transform(left), transform(right))
    I64Le(destination, left, right) =>
      I64Le(transform(destination), transform(left), transform(right))
    I64Gt(destination, left, right) =>
      I64Gt(transform(destination), transform(left), transform(right))
    I64Ge(destination, left, right) =>
      I64Ge(transform(destination), transform(left), transform(right))
    BoolNot(destination, source) =>
      BoolNot(transform(destination), transform(source))
    BoolEq(destination, left, right) =>
      BoolEq(transform(destination), transform(left), transform(right))
    BoolNe(destination, left, right) =>
      BoolNe(transform(destination), transform(left), transform(right))
    F32Add(destination, left, right) =>
      F32Add(transform(destination), transform(left), transform(right))
    F32Sub(destination, left, right) =>
      F32Sub(transform(destination), transform(left), transform(right))
    F32Mul(destination, left, right) =>
      F32Mul(transform(destination), transform(left), transform(right))
    F32Div(destination, left, right) =>
      F32Div(transform(destination), transform(left), transform(right))
    F32Neg(destination, source) =>
      F32Neg(transform(destination), transform(source))
    F32Eq(destination, left, right) =>
      F32Eq(transform(destination), transform(left), transform(right))
    F32Ne(destination, left, right) =>
      F32Ne(transform(destination), transform(left), transform(right))
    F32Lt(destination, left, right) =>
      F32Lt(transform(destination), transform(left), transform(right))
    F32Le(destination, left, right) =>
      F32Le(transform(destination), transform(left), transform(right))
    F32Gt(destination, left, right) =>
      F32Gt(transform(destination), transform(left), transform(right))
    F32Ge(destination, left, right) =>
      F32Ge(transform(destination), transform(left), transform(right))
    I64ToF32(destination, source) =>
      I64ToF32(transform(destination), transform(source))
    F32ToI64(destination, source) =>
      F32ToI64(transform(destination), transform(source))
    F32ToF64(destination, source) =>
      F32ToF64(transform(destination), transform(source))
    F64ToF32(destination, source) =>
      F64ToF32(transform(destination), transform(source))
    F32ToString(destination, source) =>
      F32ToString(transform(destination), transform(source))
    F64ToString(destination, source) =>
      F64ToString(transform(destination), transform(source))
    F64Add(destination, left, right) =>
      F64Add(transform(destination), transform(left), transform(right))
    F64Sub(destination, left, right) =>
      F64Sub(transform(destination), transform(left), transform(right))
    F64Mul(destination, left, right) =>
      F64Mul(transform(destination), transform(left), transform(right))
    F64Div(destination, left, right) =>
      F64Div(transform(destination), transform(left), transform(right))
    F64Neg(destination, source) =>
      F64Neg(transform(destination), transform(source))
    F64Eq(destination, left, right) =>
      F64Eq(transform(destination), transform(left), transform(right))
    F64Ne(destination, left, right) =>
      F64Ne(transform(destination), transform(left), transform(right))
    F64Lt(destination, left, right) =>
      F64Lt(transform(destination), transform(left), transform(right))
    F64Le(destination, left, right) =>
      F64Le(transform(destination), transform(left), transform(right))
    F64Gt(destination, left, right) =>
      F64Gt(transform(destination), transform(left), transform(right))
    F64Ge(destination, left, right) =>
      F64Ge(transform(destination), transform(left), transform(right))
    I64ToF64(destination, source) =>
      I64ToF64(transform(destination), transform(source))
    F64ToI64(destination, source) =>
      F64ToI64(transform(destination), transform(source))
    EraseI32(destination, source) =>
      EraseI32(transform(destination), transform(source))
    UneraseI32(destination, source) =>
      UneraseI32(transform(destination), transform(source))
    EraseI64(destination, source) =>
      EraseI64(transform(destination), transform(source))
    UneraseI64(destination, source) =>
      UneraseI64(transform(destination), transform(source))
    EraseF32(destination, source) =>
      EraseF32(transform(destination), transform(source))
    UneraseF32(destination, source) =>
      UneraseF32(transform(destination), transform(source))
    EraseF64(destination, source) =>
      EraseF64(transform(destination), transform(source))
    UneraseF64(destination, source) =>
      UneraseF64(transform(destination), transform(source))
    EraseUnit(destination) => EraseUnit(transform(destination))
    UneraseUnit(source) => UneraseUnit(transform(source))
    InitGlobal(global, source) => InitGlobal(global, transform(source))
    BorrowGlobal(destination, global) =>
      BorrowGlobal(transform(destination), global)
  }
}
