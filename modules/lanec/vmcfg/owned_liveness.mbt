///|
fn thread_owned_block_values(body : FunctionBody) -> FunctionBody {
  let block_count = body.blocks.length()
  let value_count = body.values.length()
  let definitions = body.blocks.mapi(fn(index, block) {
    owned_block_definitions(body, index, block)
  })
  let live_in = body.blocks.mapi(fn(index, block) {
    owned_block_uses(body, index, block)
  })
  let mut changed = true
  while changed {
    changed = false
    let mut block_index = block_count - 1
    while block_index >= 0 {
      let next = owned_block_uses(body, block_index, body.blocks[block_index])
      for successor in block_successors(body.blocks[block_index]) {
        for value_index in 0..<value_count {
          if live_in[successor][value_index] &&
            !definitions[block_index][value_index] {
            next[value_index] = true
          }
        }
      }
      if next != live_in[block_index] {
        live_in[block_index] = next
        changed = true
      }
      block_index -= 1
    }
  }
  let threaded : Array[Array[ValueId]] = body.blocks.map(_ => [])
  for block_index in 1..<block_count {
    for value_index in 0..<value_count {
      if live_in[block_index][value_index] {
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
fn owned_block_definitions(
  body : FunctionBody,
  block_index : Int,
  block : Block,
) -> Array[Bool] {
  let definitions = Array::make(body.values.length(), false)
  if block_index == 0 {
    if body.inputs.environment is Some(value) {
      definitions[value.value] = true
    }
    for value in body.inputs.witnesses {
      definitions[value.value] = true
    }
    for value in body.inputs.user_parameters {
      definitions[value.value] = true
    }
  }
  for value in block.parameters {
    definitions[value.value] = true
  }
  for instruction in block.instructions {
    for value in instruction_destinations(instruction) {
      definitions[value.value] = true
    }
  }
  definitions
}

///|
fn owned_block_uses(
  body : FunctionBody,
  block_index : Int,
  block : Block,
) -> Array[Bool] {
  let defined = Array::make(body.values.length(), false)
  if block_index == 0 {
    if body.inputs.environment is Some(value) {
      defined[value.value] = true
    }
    for value in body.inputs.witnesses {
      defined[value.value] = true
    }
    for value in body.inputs.user_parameters {
      defined[value.value] = true
    }
  }
  for value in block.parameters {
    defined[value.value] = true
  }
  let uses = Array::make(body.values.length(), false)
  for instruction in block.instructions {
    for value in instruction_uses(instruction) {
      if body.values[value.value].ownership is Owned && !defined[value.value] {
        uses[value.value] = true
      }
    }
    for value in instruction_destinations(instruction) {
      defined[value.value] = true
    }
  }
  for value in terminator_uses(block.terminator) {
    if body.values[value.value].ownership is Owned && !defined[value.value] {
      uses[value.value] = true
    }
  }
  uses
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
