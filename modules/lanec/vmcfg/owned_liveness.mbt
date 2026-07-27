///|
fn promote_cross_block_borrows(body : FunctionBody) -> FunctionBody {
  let use_def = analyze_use_def(body)
  let values = body.values.copy()
  let instruction_promotions : Array[Array[Array[(ValueId, ValueId)]]] = body.blocks.map(block => {
      block.instructions.map(_ => [])
    },
  )
  for value_index, metadata in body.values {
    guard metadata.ownership is Borrowed &&
      use_def.definitions[value_index] is Some(definition) &&
      use_def.uses[value_index].any(site => site.block() != definition.block()) else {
      continue
    }
    values[value_index] = { ..metadata, ownership: Owned }
    if definition is InstructionResult(block, instruction) {
      let borrowed : ValueId = { value: values.length() }
      values.push(metadata)
      instruction_promotions[block][instruction].push(
        ({ value: value_index }, borrowed),
      )
    }
  }
  {
    ..body,
    values,
    blocks: body.blocks.mapi(fn(block_index, block) {
      let instructions = []
      for instruction_index, instruction in block.instructions {
        let promotions = instruction_promotions[block_index][instruction_index]
        instructions.push(
          map_instruction_values(instruction, fn(value) {
            for promotion in promotions {
              let (original, borrowed) = promotion
              if value == original {
                return borrowed
              }
            }
            value
          }),
        )
        for promotion in promotions {
          let (owned, borrowed) = promotion
          instructions.push(RetainCopy(owned, borrowed))
        }
      }
      { ..block, instructions, }
    }),
  }
}

///|
fn thread_owned_block_values(body : FunctionBody) -> FunctionBody {
  let block_count = body.blocks.length()
  let value_count = body.values.length()
  let control_flow = analyze_control_flow(body.blocks)
  let use_def = analyze_use_def(body)
  let liveness = analyze_liveness(body, control_flow, use_def)
  let threaded : Array[Array[ValueId]] = body.blocks.map(_ => [])
  for block_index in 1..<block_count {
    for value_index in 0..<value_count {
      if body.values[value_index].ownership is Owned &&
        liveness.live_in[block_index][value_index] {
        threaded[block_index].push({ value: value_index })
      }
    }
  }
  {
    ..body,
    blocks: body.blocks.mapi(fn(block_index, block) {
      let carried = threaded[block_index]
      {
        ..block,
        parameters: block.parameters + carried,
        terminator: append_threaded_edge_arguments(block.terminator, threaded),
      }
    }),
  }
}

///|
fn block_successors(block : Block) -> Array[Int] {
  match block.terminator {
    Jump(edge) => [edge.target.value]
    BranchBool(_, if_true, if_false) =>
      [if_true.target.value, if_false.target.value]
    SwitchTag(_, cases, default) => {
      let successors = cases.map(edge => edge.target.value)
      successors.push(default.target.value)
      successors
    }
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Unreachable => []
  }
}

///|
fn append_threaded_edge_arguments(
  terminator : Terminator,
  threaded : Array[Array[ValueId]],
) -> Terminator {
  match terminator {
    Jump(edge) => Jump(append_threaded_edge(edge, threaded))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(
        condition,
        append_threaded_edge(if_true, threaded),
        append_threaded_edge(if_false, threaded),
      )
    SwitchTag(tag, cases, default) =>
      SwitchTag(
        tag,
        cases.map(edge => append_threaded_edge(edge, threaded)),
        append_threaded_edge(default, threaded),
      )
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Unreachable => terminator
  }
}

///|
fn append_threaded_edge(edge : Edge, threaded : Array[Array[ValueId]]) -> Edge {
  { ..edge, arguments: edge.arguments + threaded[edge.target.value] }
}
