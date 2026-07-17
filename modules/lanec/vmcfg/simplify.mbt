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
  coalesce_single_block_trivial_values(simplified)
}

///|
fn simplify_body_once(body : FunctionBody) -> FunctionBody {
  let blocks = propagate_local_scalar_values(body.values, body.blocks)
  let blocks = blocks.map(fold_constant_terminator)
  let blocks = remove_dead_scalar_instructions(body.values, blocks)
  let blocks = remove_unused_block_parameters(body.values.length(), blocks)
  let blocks = thread_empty_jump_blocks(blocks)
  let blocks = merge_linear_blocks(blocks)
  { ..body, blocks: remove_unreachable_blocks(blocks) }
}

///|
fn propagate_local_scalar_values(
  values : Array[ValueMetadata],
  blocks : Array[Block],
) -> Array[Block] {
  let use_locations = value_use_locations(values.length(), blocks)
  blocks.mapi(fn(block_index, block) {
    let aliases : Array[(ValueId, ValueId)] = []
    let constants : Array[(Instruction, ValueId)] = []
    let instructions = []
    for original in block.instructions {
      let instruction = map_instruction_values(original, fn(value) {
        resolve_value_alias(value, aliases)
      })
      let destinations = instruction_destinations(instruction)
      let local_destination = match destinations {
        [destination] if use_locations[destination.value] == block_index &&
          values[destination.value].ownership is Trivial => Some(destination)
        _ => None
      }
      match instruction {
        Copy(destination, source) if local_destination == Some(destination) &&
          compatible_trivial_values(values, destination, source) =>
          aliases.push((destination, source))
        _ if local_destination is Some(destination) &&
          instruction_is_scalar_constant(instruction) =>
          match find_equivalent_constant(instruction, constants) {
            Some(existing) if compatible_trivial_values(
                values, destination, existing,
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
fn value_use_locations(value_count : Int, blocks : Array[Block]) -> Array[Int] {
  let locations = Array::make(value_count, -1)
  for block_index, block in blocks {
    for instruction in block.instructions {
      for value in instruction_uses(instruction) {
        record_use_location(locations, value, block_index)
      }
    }
    for value in terminator_uses(block.terminator) {
      record_use_location(locations, value, block_index)
    }
  }
  locations
}

///|
fn record_use_location(
  locations : Array[Int],
  value : ValueId,
  block : Int,
) -> Unit {
  let current = locations[value.value]
  if current == -1 {
    locations[value.value] = block
  } else if current != block {
    locations[value.value] = -2
  }
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
    ConstInt(_, _)
    | ConstDouble(_, _)
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
    (ConstInt(_, left), ConstInt(_, right)) => left == right
    (ConstDouble(_, left), ConstDouble(_, right)) => left == right
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
    if instruction is ConstInt(destination, constant) && destination == value {
      return Some(constant)
    }
  }
  None
}

///|
fn remove_dead_scalar_instructions(
  values : Array[ValueMetadata],
  blocks : Array[Block],
) -> Array[Block] {
  let used = Array::make(values.length(), false)
  for block in blocks {
    for instruction in block.instructions {
      for value in instruction_uses(instruction) {
        used[value.value] = true
      }
    }
    for value in terminator_uses(block.terminator) {
      used[value.value] = true
    }
  }
  blocks.map(fn(block) {
    {
      ..block,
      instructions: block.instructions.filter(fn(instruction) {
        guard instruction_is_dead_scalar_candidate(instruction) else {
          return true
        }
        let destinations = instruction_destinations(instruction)
        destinations.is_empty() ||
        destinations.any(fn(destination) {
          used[destination.value] ||
          values[destination.value].ownership != Trivial
        })
      }),
    }
  })
}

///|
fn instruction_is_dead_scalar_candidate(instruction : Instruction) -> Bool {
  match instruction {
    Copy(_, _)
    | ConstInt(_, _)
    | ConstDouble(_, _)
    | ConstBool(_, _)
    | ConstLayout(_, _)
    | ConstFunction(_, _)
    | IntAdd(_, _, _)
    | IntSub(_, _, _)
    | IntMul(_, _, _)
    | IntNeg(_, _)
    | IntAnd(_, _, _)
    | IntOr(_, _, _)
    | IntXor(_, _, _)
    | IntNot(_, _)
    | IntShl(_, _, _)
    | IntShrS(_, _, _)
    | IntEq(_, _, _)
    | IntNe(_, _, _)
    | IntLt(_, _, _)
    | IntLe(_, _, _)
    | IntGt(_, _, _)
    | IntGe(_, _, _)
    | BoolNot(_, _)
    | BoolEq(_, _, _)
    | BoolNe(_, _, _)
    | DoubleAdd(_, _, _)
    | DoubleSub(_, _, _)
    | DoubleMul(_, _, _)
    | DoubleDiv(_, _, _)
    | DoubleNeg(_, _)
    | DoubleEq(_, _, _)
    | DoubleNe(_, _, _)
    | DoubleLt(_, _, _)
    | DoubleLe(_, _, _)
    | DoubleGt(_, _, _)
    | DoubleGe(_, _, _)
    | IntToDouble(_, _)
    | EraseI32(_, _)
    | UneraseI32(_, _)
    | EraseI64(_, _)
    | UneraseI64(_, _)
    | EraseF64(_, _)
    | UneraseF64(_, _)
    | EraseUnit(_) => true
    _ => false
  }
}

///|
fn remove_unused_block_parameters(
  value_count : Int,
  blocks : Array[Block],
) -> Array[Block] {
  let kept_parameters = blocks.map(fn(block) {
    let uses = block_use_counts(value_count, block)
    block.parameters.map(fn(parameter) { uses[parameter.value] > 0 })
  })
  blocks.mapi(fn(block_index, block) {
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
fn thread_empty_jump_blocks(blocks : Array[Block]) -> Array[Block] {
  blocks.map(fn(block) {
    {
      ..block,
      terminator: map_terminator_edges(block.terminator, fn(edge) {
        thread_edge(edge, blocks)
      }),
    }
  })
}

///|
fn thread_edge(initial : Edge, blocks : Array[Block]) -> Edge {
  let mut edge = initial
  let visited = Array::make(blocks.length(), false)
  while edge.target.value != 0 && !visited[edge.target.value] {
    let target_index = edge.target.value
    visited[target_index] = true
    let target = blocks[target_index]
    guard target.instructions.is_empty() &&
      target.terminator is Jump(next) &&
      target.parameters.length() == edge.arguments.length() else {
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
  let predecessors = block_predecessor_counts(blocks)
  blocks.mapi(fn(index, block) {
    guard block.terminator is Jump(edge) &&
      edge.target.value != index &&
      edge.arguments.is_empty() else {
      return block
    }
    let target = blocks[edge.target.value]
    if predecessors[edge.target.value] == 1 && target.parameters.is_empty() {
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
fn block_predecessor_counts(blocks : Array[Block]) -> Array[Int] {
  let counts = Array::make(blocks.length(), 0)
  for block in blocks {
    for successor in block_successors(block) {
      counts[successor] += 1
    }
  }
  counts
}

///|
fn remove_unreachable_blocks(blocks : Array[Block]) -> Array[Block] {
  let reachable = Array::make(blocks.length(), false)
  let pending = [0]
  while pending.pop() is Some(index) {
    if reachable[index] {
      continue
    }
    reachable[index] = true
    for successor in block_successors(blocks[index]) {
      if !reachable[successor] {
        pending.push(successor)
      }
    }
  }
  let remap = Array::make(blocks.length(), -1)
  let compacted = []
  for index, block in blocks {
    if reachable[index] {
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
    | Unreachable => terminator
  }
}

///|
fn coalesce_single_block_trivial_values(body : FunctionBody) -> FunctionBody {
  guard body.blocks is [block] else { return body }
  let value_count = body.values.length()
  let first = Array::make(value_count, -1)
  let last = Array::make(value_count, -1)
  for value in function_input_values(body.inputs) {
    record_interval_use(first, last, value, 0)
  }
  for value in block.parameters {
    record_interval_use(first, last, value, 0)
  }
  for position, instruction in block.instructions {
    let position = position + 1
    for destination in instruction_destinations(instruction) {
      record_interval_definition(first, last, destination, position)
    }
    for value in instruction_uses(instruction) {
      record_interval_use(first, last, value, position)
    }
  }
  let terminator_position = block.instructions.length() + 1
  for value in terminator_uses(block.terminator) {
    record_interval_use(first, last, value, terminator_position)
  }
  for metadata in body.values {
    if metadata.erased_companion is Some(companion) {
      record_interval_use(first, last, companion, 0)
    }
  }
  let remap = Array::make(value_count, -1)
  let compacted : Array[ValueMetadata] = []
  let reusable_ends : Array[Int] = []
  for value_index in 0..<value_count {
    let metadata = body.values[value_index]
    let value_first = first[value_index]
    let value_last = last[value_index]
    if value_first < 0 {
      continue
    }
    let reusable = metadata.ownership is Trivial &&
      metadata.cleanup is Trivial &&
      metadata.erased_companion is None &&
      value_first >= 0
    let mut slot = -1
    if reusable {
      for candidate, candidate_metadata in compacted {
        if reusable_ends[candidate] < value_first &&
          candidate_metadata == metadata {
          slot = candidate
          break
        }
      }
    }
    if slot < 0 {
      slot = compacted.length()
      compacted.push(metadata)
      reusable_ends.push(value_last)
    } else {
      reusable_ends[slot] = value_last
    }
    remap[value_index] = slot
  }
  if compacted.length() == value_count {
    return body
  }
  let remap_value = fn(value : ValueId) -> ValueId {
    { value: remap[value.value] }
  }
  {
    values: compacted.map(fn(metadata) {
      {
        ..metadata,
        erased_companion: metadata.erased_companion.map(remap_value),
      }
    }),
    inputs: {
      environment: body.inputs.environment.map(remap_value),
      witnesses: body.inputs.witnesses.map(remap_value),
      user_parameters: body.inputs.user_parameters.map(remap_value),
    },
    result: body.result,
    blocks: [
      {
        parameters: block.parameters.map(remap_value),
        instructions: block.instructions.map(fn(instruction) {
          map_instruction_values(instruction, remap_value)
        }),
        terminator: map_terminator_values(block.terminator, remap_value),
      },
    ],
  }
}

///|
fn function_input_values(inputs : FunctionInputs) -> Array[ValueId] {
  let values = []
  if inputs.environment is Some(environment) {
    values.push(environment)
  }
  values.append(inputs.witnesses)
  values.append(inputs.user_parameters)
  values
}

///|
fn record_interval_definition(
  first : Array[Int],
  last : Array[Int],
  value : ValueId,
  position : Int,
) -> Unit {
  if first[value.value] < 0 {
    first[value.value] = position
  }
  if last[value.value] < position {
    last[value.value] = position
  }
}

///|
fn record_interval_use(
  first : Array[Int],
  last : Array[Int],
  value : ValueId,
  position : Int,
) -> Unit {
  if first[value.value] < 0 {
    first[value.value] = 0
  }
  if last[value.value] < position {
    last[value.value] = position
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
    ConstInt(destination, value) => ConstInt(transform(destination), value)
    ConstDouble(destination, bits) => ConstDouble(transform(destination), bits)
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
    StringLength(destination, source) =>
      StringLength(transform(destination), transform(source))
    StringConcat(destination, left, right) =>
      StringConcat(transform(destination), transform(left), transform(right))
    StringSlice(destination, string, start, length) =>
      StringSlice(
        transform(destination),
        transform(string),
        transform(start),
        transform(length),
      )
    StringEq(destination, left, right) =>
      StringEq(transform(destination), transform(left), transform(right))
    IntAdd(destination, left, right) =>
      IntAdd(transform(destination), transform(left), transform(right))
    IntSub(destination, left, right) =>
      IntSub(transform(destination), transform(left), transform(right))
    IntMul(destination, left, right) =>
      IntMul(transform(destination), transform(left), transform(right))
    IntNeg(destination, source) =>
      IntNeg(transform(destination), transform(source))
    IntDiv(destination, left, right) =>
      IntDiv(transform(destination), transform(left), transform(right))
    IntRem(destination, left, right) =>
      IntRem(transform(destination), transform(left), transform(right))
    IntAnd(destination, left, right) =>
      IntAnd(transform(destination), transform(left), transform(right))
    IntOr(destination, left, right) =>
      IntOr(transform(destination), transform(left), transform(right))
    IntXor(destination, left, right) =>
      IntXor(transform(destination), transform(left), transform(right))
    IntNot(destination, source) =>
      IntNot(transform(destination), transform(source))
    IntShl(destination, left, right) =>
      IntShl(transform(destination), transform(left), transform(right))
    IntShrS(destination, left, right) =>
      IntShrS(transform(destination), transform(left), transform(right))
    IntEq(destination, left, right) =>
      IntEq(transform(destination), transform(left), transform(right))
    IntNe(destination, left, right) =>
      IntNe(transform(destination), transform(left), transform(right))
    IntLt(destination, left, right) =>
      IntLt(transform(destination), transform(left), transform(right))
    IntLe(destination, left, right) =>
      IntLe(transform(destination), transform(left), transform(right))
    IntGt(destination, left, right) =>
      IntGt(transform(destination), transform(left), transform(right))
    IntGe(destination, left, right) =>
      IntGe(transform(destination), transform(left), transform(right))
    BoolNot(destination, source) =>
      BoolNot(transform(destination), transform(source))
    BoolEq(destination, left, right) =>
      BoolEq(transform(destination), transform(left), transform(right))
    BoolNe(destination, left, right) =>
      BoolNe(transform(destination), transform(left), transform(right))
    DoubleAdd(destination, left, right) =>
      DoubleAdd(transform(destination), transform(left), transform(right))
    DoubleSub(destination, left, right) =>
      DoubleSub(transform(destination), transform(left), transform(right))
    DoubleMul(destination, left, right) =>
      DoubleMul(transform(destination), transform(left), transform(right))
    DoubleDiv(destination, left, right) =>
      DoubleDiv(transform(destination), transform(left), transform(right))
    DoubleNeg(destination, source) =>
      DoubleNeg(transform(destination), transform(source))
    DoubleEq(destination, left, right) =>
      DoubleEq(transform(destination), transform(left), transform(right))
    DoubleNe(destination, left, right) =>
      DoubleNe(transform(destination), transform(left), transform(right))
    DoubleLt(destination, left, right) =>
      DoubleLt(transform(destination), transform(left), transform(right))
    DoubleLe(destination, left, right) =>
      DoubleLe(transform(destination), transform(left), transform(right))
    DoubleGt(destination, left, right) =>
      DoubleGt(transform(destination), transform(left), transform(right))
    DoubleGe(destination, left, right) =>
      DoubleGe(transform(destination), transform(left), transform(right))
    IntToDouble(destination, source) =>
      IntToDouble(transform(destination), transform(source))
    DoubleToInt(destination, source) =>
      DoubleToInt(transform(destination), transform(source))
    EraseI32(destination, source) =>
      EraseI32(transform(destination), transform(source))
    UneraseI32(destination, source) =>
      UneraseI32(transform(destination), transform(source))
    EraseI64(destination, source) =>
      EraseI64(transform(destination), transform(source))
    UneraseI64(destination, source) =>
      UneraseI64(transform(destination), transform(source))
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
