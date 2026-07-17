///|
priv struct LivenessAnalysis {
  live_in : Array[Array[Bool]]
  live_out : Array[Array[Bool]]
}

///|
fn analyze_liveness(
  body : FunctionBody,
  control_flow : ControlFlowAnalysis,
  use_def : UseDefAnalysis,
) -> LivenessAnalysis {
  let definitions = body.blocks.map(_ => {
    Array::make(body.values.length(), false)
  })
  let upward_uses = body.blocks.map(_ => {
    Array::make(body.values.length(), false)
  })
  for value_index in 0..<body.values.length() {
    let definition = use_def.definitions[value_index]
    if definition is Some(site) {
      definitions[site.block()][value_index] = true
    }
    for use_site in use_def.uses[value_index] {
      let upward = match definition {
        None => true
        Some(site) if site.block() != use_site.block() => true
        Some(site) => use_site.position(body) < site.position()
      }
      if upward {
        upward_uses[use_site.block()][value_index] = true
      }
    }
  }
  let live_in = body.blocks.map(_ => Array::make(body.values.length(), false))
  let live_out = body.blocks.map(_ => Array::make(body.values.length(), false))
  let mut changed = true
  while changed {
    changed = false
    let mut block_index = body.blocks.length() - 1
    while block_index >= 0 {
      let next_out = Array::make(body.values.length(), false)
      for successor in block_successors(body.blocks[block_index]) {
        if !control_flow.reachable[block_index] ||
          !control_flow.reachable[successor] {
          continue
        }
        for value_index in 0..<body.values.length() {
          next_out[value_index] = next_out[value_index] ||
            live_in[successor][value_index]
        }
      }
      let next_in = upward_uses[block_index].copy()
      for value_index in 0..<body.values.length() {
        if next_out[value_index] && !definitions[block_index][value_index] {
          next_in[value_index] = true
        }
      }
      if next_out != live_out[block_index] || next_in != live_in[block_index] {
        live_out[block_index] = next_out
        live_in[block_index] = next_in
        changed = true
      }
      block_index -= 1
    }
  }
  { live_in, live_out }
}

///|
fn LivenessAnalysis::is_live_after_instruction(
  self : LivenessAnalysis,
  body : FunctionBody,
  block_index : Int,
  instruction_index : Int,
  value : ValueId,
) -> Bool {
  let live = self.live_out[block_index].copy()
  let block = body.blocks[block_index]
  for used in terminator_uses(block.terminator) {
    live[used.value] = true
  }
  let mut index = block.instructions.length() - 1
  while index > instruction_index {
    for destination in instruction_destinations(block.instructions[index]) {
      live[destination.value] = false
    }
    for used in instruction_uses(block.instructions[index]) {
      live[used.value] = true
    }
    index -= 1
  }
  live[value.value]
}
