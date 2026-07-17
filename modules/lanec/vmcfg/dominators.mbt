///|
priv struct ControlFlowAnalysis {
  predecessors : Array[Array[Int]]
  reachable : Array[Bool]
  dominators : Array[Array[Bool]]
  immediate_dominators : Array[Int?]
}

///|
fn analyze_control_flow(blocks : Array[Block]) -> ControlFlowAnalysis {
  let predecessors : Array[Array[Int]] = blocks.map(_ => [])
  for block_index, block in blocks {
    for successor in block_successors(block) {
      predecessors[successor].push(block_index)
    }
  }
  let reachable = Array::make(blocks.length(), false)
  if !blocks.is_empty() {
    let pending = [0]
    while pending.pop() is Some(block_index) {
      if reachable[block_index] {
        continue
      }
      reachable[block_index] = true
      for successor in block_successors(blocks[block_index]) {
        if !reachable[successor] {
          pending.push(successor)
        }
      }
    }
  }
  let dominators = blocks.mapi(fn(block_index, _) {
    if !reachable[block_index] {
      Array::make(blocks.length(), false)
    } else if block_index == 0 {
      let entry = Array::make(blocks.length(), false)
      entry[0] = true
      entry
    } else {
      reachable.copy()
    }
  })
  let mut changed = true
  while changed {
    changed = false
    for block_index in 1..<blocks.length() {
      if !reachable[block_index] {
        continue
      }
      let mut next = Array::make(blocks.length(), false)
      let mut has_predecessor = false
      for predecessor in predecessors[block_index] {
        if !reachable[predecessor] {
          continue
        }
        if !has_predecessor {
          next = dominators[predecessor].copy()
          has_predecessor = true
        } else {
          for candidate in 0..<blocks.length() {
            next[candidate] = next[candidate] &&
              dominators[predecessor][candidate]
          }
        }
      }
      next[block_index] = true
      if next != dominators[block_index] {
        dominators[block_index] = next
        changed = true
      }
    }
  }
  let immediate_dominators : Array[Int?] = blocks.mapi(fn(block_index, _) {
    if block_index == 0 || !reachable[block_index] {
      return None
    }
    let strict = []
    for candidate in 0..<blocks.length() {
      if candidate != block_index && dominators[block_index][candidate] {
        strict.push(candidate)
      }
    }
    for candidate in strict {
      if strict.all(other => other == candidate || !dominators[other][candidate]) {
        return Some(candidate)
      }
    }
    None
  })
  { predecessors, reachable, dominators, immediate_dominators }
}

///|
fn ControlFlowAnalysis::dominates(
  self : ControlFlowAnalysis,
  dominator : Int,
  block : Int,
) -> Bool {
  self.dominators[block][dominator]
}
