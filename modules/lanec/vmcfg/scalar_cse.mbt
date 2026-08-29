///|
fn eliminate_common_scalar_expressions(body : FunctionBody) -> FunctionBody {
  if body.blocks.is_empty() {
    return body
  }
  let control_flow = analyze_control_flow(body.blocks)
  let children : Array[Array[Int]] = body.blocks.map(_ => [])
  for block_index in 1..<body.blocks.length() {
    if control_flow.immediate_dominators[block_index] is Some(parent) {
      children[parent].push(block_index)
    }
  }
  let blocks = body.blocks.copy()
  eliminate_common_scalar_expressions_in_block(body, children, blocks, 0, [], [])
  { ..body, blocks, }
}

///|
fn eliminate_common_scalar_expressions_in_block(
  body : FunctionBody,
  children : Array[Array[Int]],
  blocks : Array[Block],
  block_index : Int,
  inherited_expressions : Array[(Instruction, ValueId)],
  inherited_aliases : Array[(ValueId, ValueId)],
) -> Unit {
  let expressions = inherited_expressions.copy()
  let aliases = inherited_aliases.copy()
  let instructions = []
  for original in body.blocks[block_index].instructions {
    let instruction = map_instruction_values(original, value => {
      resolve_value_alias(value, aliases)
    })
    guard instruction_destinations(instruction) is [destination] &&
      body.values[destination.value].ownership is Trivial &&
      body.values[destination.value].cleanup is Trivial &&
      body.values[destination.value].erased_companion is None &&
      !value_is_erased_companion(body.values, destination) else {
      instructions.push(instruction)
      continue
    }
    if instruction is Copy(_, source) &&
      compatible_trivial_values(body.values, destination, source) {
      aliases.push((destination, source))
      continue
    }
    guard scalar_expression_key(instruction) is Some(key) else {
      instructions.push(instruction)
      continue
    }
    match
      find_available_scalar_expression(
        expressions,
        key,
        destination,
        body.values,
      ) {
      Some(existing) => aliases.push((destination, existing))
      None => {
        instructions.push(instruction)
        expressions.push((key, destination))
      }
    }
  }
  blocks[block_index] = {
    ..body.blocks[block_index],
    instructions,
    terminator: map_terminator_values(body.blocks[block_index].terminator, value => {
      resolve_value_alias(value, aliases)
    }),
  }
  for child in children[block_index] {
    eliminate_common_scalar_expressions_in_block(
      body, children, blocks, child, expressions, aliases,
    )
  }
}

///|
fn scalar_expression_key(instruction : Instruction) -> Instruction? {
  if !instruction_is_common_scalar_candidate(instruction) {
    return None
  }
  guard instruction_destinations(instruction) is [destination] else {
    return None
  }
  Some(
    map_instruction_values(instruction, value => {
      if value == destination {
        { value: 0, }
      } else {
        value
      }
    }),
  )
}

///|
fn instruction_is_common_scalar_candidate(instruction : Instruction) -> Bool {
  if !instruction_is_dead_scalar_candidate(instruction) {
    return false
  }
  match instruction {
    Copy(_, _)
    | EraseI32(_, _)
    | UneraseI32(_, _)
    | EraseI64(_, _)
    | UneraseI64(_, _)
    | EraseF32(_, _)
    | UneraseF32(_, _)
    | EraseF64(_, _)
    | UneraseF64(_, _)
    | EraseUnit(_) => false
    _ => true
  }
}

///|
fn find_available_scalar_expression(
  expressions : Array[(Instruction, ValueId)],
  key : Instruction,
  destination : ValueId,
  values : Array[ValueMetadata],
) -> ValueId? {
  for index = expressions.length() - 1; index >= 0; index = index - 1 {
    let (candidate, value) = expressions[index]
    if candidate == key && compatible_trivial_values(values, destination, value) {
      return Some(value)
    }
  }
  None
}
