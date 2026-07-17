///|
fn select_consuming_projections(image : Image) -> Image {
  {
    ..image,
    functions: image.functions.map(fn(entry) {
      match entry {
        Body(body) => Body(select_consuming_projections_in_body(body))
        RuntimeImport(_) => entry
      }
    }),
  }
}

///|
fn select_consuming_projections_in_body(body : FunctionBody) -> FunctionBody {
  let values = body.values.copy()
  let uses = body_value_use_counts(body)
  {
    ..body,
    values,
    blocks: body.blocks.map(fn(block) {
      select_consuming_projections_in_block(body, values, uses, block)
    }),
  }
}

///|
fn select_consuming_projections_in_block(
  body : FunctionBody,
  values : Array[ValueMetadata],
  uses : Array[Int],
  block : Block,
) -> Block {
  let instructions = []
  let mut index = 0
  while index < block.instructions.length() {
    match block.instructions[index] {
      BorrowField(shape, source, _, _) => {
        let (next, selections) = collect_field_projections(
          block.instructions,
          index,
          shape,
          source,
        )
        if projection_group_can_consume(
            body,
            uses,
            block.instructions,
            index,
            source,
            selections,
          ) {
          mark_projection_results_owned(values, selections)
          instructions.push(ConsumeFields(shape, source, selections))
        } else {
          instructions.append(block.instructions[index:next])
        }
        index = next
      }
      BorrowCapture(shape, source, _, _) => {
        let (next, selections) = collect_capture_projections(
          block.instructions,
          index,
          shape,
          source,
        )
        if projection_group_can_consume(
            body,
            uses,
            block.instructions,
            index,
            source,
            selections,
          ) {
          mark_projection_results_owned(values, selections)
          instructions.push(ConsumeCaptures(shape, source, selections))
        } else {
          instructions.append(block.instructions[index:next])
        }
        index = next
      }
      instruction => {
        instructions.push(instruction)
        index += 1
      }
    }
  }
  { ..block, instructions, }
}

///|
fn collect_field_projections(
  instructions : Array[Instruction],
  start : Int,
  shape : @bytecode.ObjectShapeId,
  source : ValueId,
) -> (Int, Array[ProjectionSelection]) {
  let selections = []
  let mut index = start
  while index < instructions.length() {
    guard instructions[index]
      is BorrowField(selected_shape, selected_source, member_index, result) &&
      selected_shape == shape &&
      selected_source == source else {
      break
    }
    selections.push({ member_index, result })
    index += 1
  }
  (index, selections)
}

///|
fn collect_capture_projections(
  instructions : Array[Instruction],
  start : Int,
  shape : @bytecode.ObjectShapeId,
  source : ValueId,
) -> (Int, Array[ProjectionSelection]) {
  let selections = []
  let mut index = start
  while index < instructions.length() {
    guard instructions[index]
      is BorrowCapture(selected_shape, selected_source, member_index, result) &&
      selected_shape == shape &&
      selected_source == source else {
      break
    }
    selections.push({ member_index, result })
    index += 1
  }
  (index, selections)
}

///|
fn projection_group_can_consume(
  body : FunctionBody,
  uses : Array[Int],
  instructions : Array[Instruction],
  start : Int,
  source : ValueId,
  selections : Array[ProjectionSelection],
) -> Bool {
  let prior_uses = independent_prior_source_uses(instructions, start, source)
  body.values[source.value].ownership is Owned &&
  prior_uses is Some(prior_uses) &&
  uses[source.value] == prior_uses + selections.length() &&
  selections.any(fn(selection) {
    projection_result_requires_owner(body, selection.result)
  })
}

///|
fn independent_prior_source_uses(
  instructions : Array[Instruction],
  end : Int,
  source : ValueId,
) -> Int? {
  let mut count = 0
  for index in 0..<end {
    let instruction = instructions[index]
    let used_values = instruction_uses(instruction)
    guard used_values.contains(source) else { continue }
    match instruction {
      LoadTag(_, selected) if selected == source => count += 1
      LoadObjectWitness(_, _, selected, _) if selected == source => count += 1
      _ => return None
    }
  }
  Some(count)
}

///|
fn projection_result_requires_owner(
  body : FunctionBody,
  result : ProjectionResult,
) -> Bool {
  let value = result.value_destination
  guard body.values[value.value].ownership is Borrowed else { return false }
  for block in body.blocks {
    for instruction in block.instructions {
      if instruction_consumes_value(instruction, value) {
        return true
      }
    }
    if terminator_consumes_value(block.terminator, value) {
      return true
    }
  }
  false
}

///|
fn instruction_consumes_value(
  instruction : Instruction,
  value : ValueId,
) -> Bool {
  match instruction {
    Move(_, source)
    | Release(source)
    | RetainCopy(_, source)
    | MakeClosure(_, _, source)
    | EraseI32(_, source)
    | UneraseI32(_, source)
    | EraseI64(_, source)
    | UneraseI64(_, source)
    | EraseF64(_, source)
    | UneraseF64(_, source)
    | UneraseUnit(source)
    | InitGlobal(_, source) => source == value
    CallDirect(_, environment, _, arguments, _) =>
      environment == Some(value) || arguments.contains(value)
    CallValue(callable, _, arguments, _) =>
      callable == value || arguments.contains(value)
    MakeData(_, _, _, _, fields) | MakeEnv(_, _, _, _, fields) =>
      fields.contains(value)
    ConsumeFields(_, source, _) | ConsumeCaptures(_, source, _) =>
      source == value
    _ => false
  }
}

///|
fn terminator_consumes_value(terminator : Terminator, value : ValueId) -> Bool {
  match terminator {
    Return(result) => result == Some(value)
    Jump(edge) => edge.arguments.contains(value)
    BranchBool(_, if_true, if_false) =>
      if_true.arguments.contains(value) || if_false.arguments.contains(value)
    SwitchTag(_, cases, default) =>
      cases.any(fn(edge) { edge.arguments.contains(value) }) ||
      default.arguments.contains(value)
    TailCallDirect(_, environment, _, arguments) =>
      environment == Some(value) || arguments.contains(value)
    TailCallValue(callable, _, arguments) =>
      callable == value || arguments.contains(value)
    Unreachable => false
  }
}

///|
fn mark_projection_results_owned(
  values : Array[ValueMetadata],
  selections : Array[ProjectionSelection],
) -> Unit {
  for selection in selections {
    let destination = selection.result.value_destination
    let metadata = values[destination.value]
    if metadata.ownership is Borrowed {
      values[destination.value] = { ..metadata, ownership: Owned }
    }
  }
}
