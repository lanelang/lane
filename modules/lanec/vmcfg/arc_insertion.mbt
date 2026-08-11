///|
fn insert_arc_unverified(
  body : FunctionBody,
) -> FunctionBody raise FinalizeError {
  let blocks = []
  let edge_blocks = []
  let original_block_count = body.blocks.length()
  for block_index, block in body.blocks {
    blocks.push(
      insert_arc_block(
        body, block_index, block, original_block_count, edge_blocks,
      ),
    )
  }
  blocks.append(edge_blocks)
  { ..body, blocks, }
}

///|
fn insert_arc_block(
  body : FunctionBody,
  block_index : Int,
  block : Block,
  original_block_count : Int,
  edge_blocks : Array[Block],
) -> Block raise FinalizeError {
  let remaining = block_use_counts(body.values.length(), block)
  let live = Array::make(body.values.length(), false)
  if block_index == 0 {
    for value in function_input_values(body.inputs) {
      mark_live(body, live, value)
    }
  }
  for value in block.parameters {
    mark_live(body, live, value)
  }
  let instructions = []
  for instruction in block.instructions {
    instructions.push(
      insert_arc_instruction(
        body, block_index, live, remaining, instructions, instruction,
      ),
    )
  }
  let terminator = insert_arc_terminator(
    body,
    block_index,
    live,
    remaining,
    instructions,
    block.terminator,
    original_block_count,
    edge_blocks,
  )
  for value_index, is_live in live {
    if is_live {
      instructions.push(Release({ value: value_index }))
    }
  }
  { parameters: block.parameters, instructions, terminator }
}

///|
fn consume_arc_value(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[Instruction],
  value : ValueId,
) -> ValueId raise FinalizeError {
  remaining[value.value] -= 1
  match body.values[value.value].ownership {
    Trivial => value
    Borrowed => {
      let promoted = append_owned_value(body, value)
      prefix.push(RetainCopy(promoted, value))
      promoted
    }
    Owned => {
      if !live[value.value] {
        raise UseBeforeOwnership(value~, block~)
      }
      if remaining[value.value] > 0 {
        let retained = append_owned_value(body, value)
        prefix.push(RetainCopy(retained, value))
        retained
      } else {
        live[value.value] = false
        value
      }
    }
  }
}

///|
fn mark_live(body : FunctionBody, live : Array[Bool], value : ValueId) -> Unit {
  if body.values[value.value].ownership is Owned {
    live[value.value] = true
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
fn insert_arc_instruction(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[Instruction],
  instruction : Instruction,
) -> Instruction raise FinalizeError {
  let plan = arc_instruction_plan(instruction)
  let operands = []
  for operand in plan.operands {
    let (value, mode) = operand
    operands.push(
      match mode {
        Borrow => borrow_value(remaining, value)
        Consume =>
          consume_arc_value(body, block, live, remaining, prefix, value)
      },
    )
  }
  let result = (plan.materialize)(operands)
  for destination in instruction_destinations(instruction) {
    mark_destination(body, live, destination)
  }
  result
}

///|
fn insert_arc_terminator(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[Instruction],
  terminator : Terminator,
  original_block_count : Int,
  edge_blocks : Array[Block],
) -> Terminator raise FinalizeError {
  match terminator {
    Jump(edge) =>
      Jump(insert_arc_edge(body, block, live, remaining, prefix, edge))
    BranchBool(condition, if_true, if_false) => {
      ignore(borrow_value(remaining, condition))
      let true_remaining = remaining.copy()
      subtract_edge_uses(true_remaining, if_false)
      let false_remaining = remaining.copy()
      subtract_edge_uses(false_remaining, if_true)
      let lowered_true = insert_arc_branch_edge(
        body, block, live, true_remaining, if_true, original_block_count, edge_blocks,
      )
      let lowered_false = insert_arc_branch_edge(
        body, block, live, false_remaining, if_false, original_block_count, edge_blocks,
      )
      clear_live(live)
      BranchBool(condition, lowered_true, lowered_false)
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
          insert_arc_branch_edge(
            body, block, live, path_remaining, edge, original_block_count, edge_blocks,
          ),
        )
      }
      clear_live(live)
      let lowered_default = lowered_edges.pop().unwrap()
      SwitchTag(tag, lowered_edges, lowered_default)
    }
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal(_)
    | Unreachable => {
      let plan = arc_terminal_plan(terminator).unwrap()
      let operands = []
      for operand in plan.operands {
        let (value, mode) = operand
        operands.push(
          match mode {
            Borrow => borrow_value(remaining, value)
            Consume =>
              consume_arc_value(body, block, live, remaining, prefix, value)
          },
        )
      }
      (plan.materialize)(operands)
    }
  }
}

///|
fn insert_arc_branch_edge(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  edge : Edge,
  original_block_count : Int,
  edge_blocks : Array[Block],
) -> Edge raise FinalizeError {
  let edge_live = live.copy()
  let instructions = []
  let lowered = insert_arc_edge(
    body, block, edge_live, remaining, instructions, edge,
  )
  for value_index, is_live in edge_live {
    if is_live {
      instructions.push(Release({ value: value_index }))
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
fn insert_arc_edge(
  body : FunctionBody,
  block : Int,
  live : Array[Bool],
  remaining : Array[Int],
  prefix : Array[Instruction],
  edge : Edge,
) -> Edge raise FinalizeError {
  {
    target: edge.target,
    arguments: edge.arguments.map(value => {
      consume_arc_value(body, block, live, remaining, prefix, value)
    }),
  }
}
