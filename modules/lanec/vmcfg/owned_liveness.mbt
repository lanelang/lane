///|
fn promote_cross_block_instruction_borrows(
  body : FunctionBody,
) -> FunctionBody raise FinalizeError {
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
    guard definition is InstructionResult(block, instruction) else {
      raise IllegalValueMetadata(value={ value: value_index, })
    }
    values[value_index] = { ..metadata, ownership: Owned, }
    let borrowed : ValueId = { value: values.length(), }
    values.push(metadata)
    instruction_promotions[block][instruction].push(
      ({ value: value_index, }, borrowed),
    )
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
fn thread_owned_block_values(
  body : FunctionBody,
) -> FunctionBody raise FinalizeError {
  let block_count = body.blocks.length()
  let value_count = body.values.length()
  let control_flow = analyze_control_flow(body.blocks)
  let use_def = analyze_use_def(body)
  let liveness = analyze_liveness(body, control_flow, use_def)
  let values = body.values.copy()
  let threaded : Array[Array[(ValueId, ValueId)]] = body.blocks.map(_ => [])
  for block_index in 1..<block_count {
    for value_index in 0..<value_count {
      if body.values[value_index].ownership is Owned &&
        liveness.live_in[block_index][value_index] {
        let source : ValueId = { value: value_index, }
        let parameter : ValueId = { value: values.length(), }
        values.push(body.values[value_index])
        threaded[block_index].push((source, parameter))
      }
    }
  }
  {
    ..body,
    values,
    blocks: body.blocks.mapi(fn(block_index, block) {
      let carried = threaded[block_index]
      let rewrite = fn(value) { threaded_value(value, carried) }
      {
        parameters: block.parameters + carried.map(pair => pair.1),
        instructions: block.instructions.map(instruction => {
          map_instruction_values(instruction, rewrite)
        }),
        terminator: append_threaded_edge_arguments(
          map_terminator_values(block.terminator, rewrite),
          threaded,
          carried,
        ),
      }
    }),
  }
}

///|
fn threaded_value(
  value : ValueId,
  threaded : Array[(ValueId, ValueId)],
) -> ValueId {
  for pair in threaded {
    if value == pair.0 {
      return pair.1
    }
  }
  value
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
    | Fatal(_)
    | Unreachable => []
  }
}

///|
fn append_threaded_edge_arguments(
  terminator : Terminator,
  threaded : Array[Array[(ValueId, ValueId)]],
  source_threading : Array[(ValueId, ValueId)],
) -> Terminator {
  match terminator {
    Jump(edge) => Jump(append_threaded_edge(edge, threaded, source_threading))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(
        condition,
        append_threaded_edge(if_true, threaded, source_threading),
        append_threaded_edge(if_false, threaded, source_threading),
      )
    SwitchTag(tag, cases, default) =>
      SwitchTag(
        tag,
        cases.map(edge => append_threaded_edge(edge, threaded, source_threading)),
        append_threaded_edge(default, threaded, source_threading),
      )
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal(_)
    | Unreachable => terminator
  }
}

///|
fn append_threaded_edge(
  edge : Edge,
  threaded : Array[Array[(ValueId, ValueId)]],
  source_threading : Array[(ValueId, ValueId)],
) -> Edge {
  {
    ..edge,
    arguments: edge.arguments +
    threaded[edge.target.value].map(pair => {
      threaded_value(pair.0, source_threading)
    }),
  }
}
