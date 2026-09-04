///|
// These equalities preserve the actual runtime value, not merely callable
// behavior. Inspect SSA definitions, never an allocation-site approximation.
fn simplify_representation_values(
  body : FunctionBody,
) -> FunctionBody raise FinalizeError {
  let use_def = analyze_use_def(body)
  let control_flow = analyze_control_flow(body.blocks)
  let aliases : Array[ValueId?] = Array::make(body.values.length(), None)
  let removed : Array[ValueId] = []
  for block_index, block in body.blocks {
    for instruction_index, instruction in block.instructions {
      // A replacement must not hide an invalid forward or cross-branch use.
      let available = fn(value : ValueId) {
        match use_def.definitions[value.value] {
          Some(FunctionInput(_)) => true
          Some(definition) =>
            if definition.block() == block_index {
              definition.position() < instruction_index
            } else {
              control_flow.dominates(definition.block(), block_index)
            }
          None => false
        }
      }
      guard use_def
        .instruction_uses(block_index, instruction_index)
        .all(available) else {
        continue
      }
      let candidate = match instruction {
        Copy(destination, source) | Move(destination, source) =>
          Some((destination, source))
        UneraseI32(destination, erased) =>
          match value_instruction(body, use_def, erased) {
            Some(EraseI32(_, source)) => Some((destination, source))
            _ => None
          }
        UneraseI64(destination, erased) =>
          match value_instruction(body, use_def, erased) {
            Some(EraseI64(_, source)) => Some((destination, source))
            _ => None
          }
        UneraseF32(destination, erased) =>
          match value_instruction(body, use_def, erased) {
            Some(EraseF32(_, source)) => Some((destination, source))
            _ => None
          }
        UneraseF64(destination, erased) =>
          match value_instruction(body, use_def, erased) {
            Some(EraseF64(_, source)) => Some((destination, source))
            _ => None
          }
        BorrowClosureEnvironment(destination, target, callable) =>
          match value_instruction(body, use_def, callable) {
            Some(MakeClosure(_, actual, environment)) if actual == target =>
              Some((destination, environment))
            _ => None
          }
        BorrowCapture(shape, environment, index, result) if result.witness_destination
          is None =>
          match value_instruction(body, use_def, environment) {
            Some(MakeEnv(_, actual, _, _, captures)) if shape == actual =>
              Some((result.value_destination, captures[index]))
            _ => None
          }
        _ => None
      }
      if candidate is Some((destination, source)) && available(source) {
        let left = body.values[destination.value]
        let right = body.values[source.value]
        if left.representation == right.representation &&
          left.cleanup == right.cleanup &&
          left.kind == right.kind &&
          left.erased_companion == right.erased_companion {
          aliases[destination.value] = Some(source)
          removed.push(destination)
        }
      }
    }
  }
  if removed.is_empty() {
    return body
  }
  let resolve = fn(value : ValueId) {
    for current = value {
      match aliases[current.value] {
        Some(source) => continue source
        None => break current
      }
    }
  }
  remove_dead_callable_construction({
    ..body,
    values: body.values.map(metadata => {
      ..metadata,
      erased_companion: metadata.erased_companion.map(resolve),
    }),
    blocks: body.blocks.map(block => {
      ..block,
      instructions: block.instructions.filter_map(instruction => {
        if instruction_destinations(instruction) is [destination] &&
          removed.contains(destination) {
          None
        } else {
          Some(map_instruction_values(instruction, resolve))
        }
      }),
      terminator: map_terminator_values(block.terminator, resolve),
    }),
  })
}

///|
fn value_instruction(
  body : FunctionBody,
  use_def : UseDefAnalysis,
  value : ValueId,
) -> Instruction? {
  match use_def.definitions[value.value] {
    Some(InstructionResult(block, instruction)) =>
      Some(body.blocks[block].instructions[instruction])
    _ => None
  }
}
