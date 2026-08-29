///|
priv enum ArcValueState {
  Unavailable
  LiveTrivial
  LiveOwned(Array[ValueId])
  LiveBorrowed(Array[ValueId])
} derive(Eq)

///|
fn insert_arc(body : FunctionBody) -> ArcFinalBody raise FinalizeError {
  verify_arc_final_body(insert_arc_unverified(body))
}

///|
fn verify_arc_final_body(
  body : FunctionBody,
) -> ArcFinalBody raise FinalizeError {
  let use_def = verify_arc_final_structure(body)
  verify_arc_final_flow(body)
  { body, use_def, }
}

///|
fn[T] arc_final_fail(error : ArcFinalBodyError) -> T raise FinalizeError {
  raise ArcFinalVerificationCompilerDefect(error)
}

///|
fn verify_arc_final_structure(
  body : FunctionBody,
) -> UseDefAnalysis raise FinalizeError {
  if body.blocks.is_empty() {
    arc_final_fail(EmptyControlFlowGraph)
  }
  if !body.blocks[0].parameters.is_empty() {
    arc_final_fail(EntryBlockHasParameters)
  }
  for value in function_input_values(body.inputs) {
    require_arc_value(body, value)
  }
  for index, metadata in body.values {
    if metadata.erased_companion is Some(companion) {
      require_arc_value(body, companion)
      if body.values[companion.value].ownership is Owned {
        arc_final_fail(InvalidValue({ value: index, }))
      }
    }
  }
  for source_index, block in body.blocks {
    let source : @physical.BlockId = { value: source_index, }
    for parameter in block.parameters {
      require_arc_value(body, parameter)
    }
    for instruction in block.instructions {
      for destination in instruction_destinations(instruction) {
        require_arc_value(body, destination)
      }
      for value in instruction_operand_values(instruction) {
        require_arc_value(body, value)
      }
    }
    for value in terminator_operand_values(block.terminator) {
      require_arc_value(body, value)
    }
    for edge in block_edges(block.terminator) {
      verify_arc_edge(body, source, edge)
    }
  }
  let use_def = analyze_use_def(body)
  for value_index, uses in use_def.uses {
    if !uses.is_empty() && use_def.definitions[value_index] is None {
      arc_final_fail(MissingDefinition({ value: value_index, }))
    }
  }
  let reachable = Array::make(body.blocks.length(), false)
  let pending = [0]
  while pending.pop() is Some(block_index) {
    if reachable[block_index] {
      continue
    }
    reachable[block_index] = true
    for successor in block_successors(body.blocks[block_index]) {
      if !reachable[successor] {
        pending.push(successor)
      }
    }
  }
  for block_index, is_reachable in reachable {
    if !is_reachable {
      arc_final_fail(UnreachableBlock({ value: block_index, }))
    }
  }
  use_def
}

///|
fn require_arc_value(
  body : FunctionBody,
  value : ValueId,
) -> Unit raise FinalizeError {
  if value.value < 0 || value.value >= body.values.length() {
    arc_final_fail(InvalidValue(value))
  }
}

///|
fn block_edges(terminator : Terminator) -> Array[Edge] {
  match terminator {
    Jump(edge) => [edge]
    BranchBool(_, if_true, if_false) => [if_true, if_false]
    SwitchTag(_, cases, default) => cases + [default]
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallPackedDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal(_)
    | Unreachable => []
  }
}

///|
fn verify_arc_edge(
  body : FunctionBody,
  source : @physical.BlockId,
  edge : Edge,
) -> Unit raise FinalizeError {
  if edge.target.value < 0 || edge.target.value >= body.blocks.length() {
    arc_final_fail(InvalidBlock(edge.target))
  }
  let parameters = body.blocks[edge.target.value].parameters
  if edge.arguments.length() != parameters.length() {
    arc_final_fail(
      EdgeArityMismatch(
        source,
        edge.target,
        parameters.length(),
        edge.arguments.length(),
      ),
    )
  }
  for index, argument in edge.arguments {
    let parameter = parameters[index]
    if !arc_edge_metadata_matches(body, edge, argument, parameter) {
      arc_final_fail(EdgeMetadataMismatch(source, edge.target, index))
    }
  }
}

///|
fn arc_edge_metadata_matches(
  body : FunctionBody,
  edge : Edge,
  argument : ValueId,
  parameter : ValueId,
) -> Bool {
  let source = body.values[argument.value]
  let target = body.values[parameter.value]
  if source.representation != target.representation ||
    source.cleanup != target.cleanup ||
    source.kind != target.kind ||
    source.ownership != target.ownership {
    return false
  }
  match (source.erased_companion, target.erased_companion) {
    (None, None) => true
    (Some(source_companion), Some(target_companion)) => {
      let parameters = body.blocks[edge.target.value].parameters
      for index, candidate in parameters {
        if candidate == target_companion {
          return edge.arguments[index] == source_companion
        }
      }
      source_companion == target_companion
    }
    _ => false
  }
}

///|
fn verify_arc_final_flow(body : FunctionBody) -> Unit raise FinalizeError {
  let entries : Array[Array[ArcValueState]?] = Array::make(
    body.blocks.length(),
    None,
  )
  let initial = Array::make(body.values.length(), ArcValueState::Unavailable)
  for value in function_input_values(body.inputs) {
    initial[value.value] = initial_arc_state(value, body.values[value.value])
  }
  entries[0] = Some(initial)
  let queue = [0]
  let mut cursor = 0
  while cursor < queue.length() {
    let block_index = queue[cursor]
    cursor += 1
    guard entries[block_index] is Some(entry) else {
      abort("ARC-final verifier queued a block without an entry state")
    }
    let state = entry.copy()
    let block = body.blocks[block_index]
    let block_id : @physical.BlockId = { value: block_index, }
    for instruction in block.instructions {
      apply_arc_instruction(body, block_id, state, instruction)
    }
    let successors = apply_arc_terminator(
      body,
      block_id,
      state,
      block.terminator,
    )
    for successor in successors {
      let (target, incoming) = successor
      match entries[target.value] {
        None => {
          entries[target.value] = Some(incoming)
          queue.push(target.value)
        }
        Some(existing) =>
          if merge_arc_entry(existing, incoming, target) {
            queue.push(target.value)
          }
      }
    }
  }
}

///|
fn initial_arc_state(
  value : ValueId,
  metadata : ValueMetadata,
) -> ArcValueState {
  match metadata.ownership {
    Trivial => LiveTrivial
    Owned => LiveOwned([value])
    Borrowed => LiveBorrowed([])
  }
}

///|
fn apply_arc_instruction(
  body : FunctionBody,
  block : @physical.BlockId,
  state : Array[ArcValueState],
  instruction : Instruction,
) -> Unit raise FinalizeError {
  let destinations = instruction_destinations(instruction)
  let destination_roots = destinations.map(destination => {
    arc_destination_roots(state, instruction, destination)
  })
  for operand in instruction_arc_operands(instruction) {
    let (value, mode) = operand
    apply_arc_operand(body, block, state, value, mode)
  }
  if instruction is Release(value) &&
    body.values[value.value].ownership != Owned {
    arc_final_fail(InvalidRelease(value, block))
  }
  for index, destination in destinations {
    define_arc_destination(
      body,
      block,
      state,
      instruction,
      destination,
      destination_roots[index],
    )
  }
}

///|
fn apply_arc_operand(
  body : FunctionBody,
  block : @physical.BlockId,
  state : Array[ArcValueState],
  value : ValueId,
  mode : ArcOperandMode,
) -> Unit raise FinalizeError {
  match (mode, body.values[value.value].ownership, state[value.value]) {
    (_, _, Unavailable) => arc_final_fail(UseBeforeDefinition(value, block))
    (Borrow, Owned, LiveOwned(_)) | (Borrow, Trivial, LiveTrivial) => ()
    (Borrow, Borrowed, LiveBorrowed(roots)) =>
      if first_uncovered_arc_root(state, roots) is Some(owner) {
        arc_final_fail(BorrowOwnerNotLive(value, owner, block))
      }
    (Consume, Owned, LiveOwned(_)) => state[value.value] = Unavailable
    (Consume, Borrowed, _) =>
      arc_final_fail(BorrowedValueConsumed(value, block))
    (Consume, Trivial, LiveTrivial) => ()
    (_, Owned, _) => arc_final_fail(OwnedValueNotLive(value, block))
    _ => arc_final_fail(UseBeforeDefinition(value, block))
  }
}

///|
fn define_arc_destination(
  body : FunctionBody,
  block : @physical.BlockId,
  state : Array[ArcValueState],
  instruction : Instruction,
  destination : ValueId,
  roots : Array[ValueId],
) -> Unit raise FinalizeError {
  if state[destination.value] is LiveOwned(_) {
    arc_final_fail(OwnedValueOverwritten(destination, block))
  }
  state[destination.value] = match body.values[destination.value].ownership {
    Trivial => LiveTrivial
    Owned => LiveOwned(roots)
    Borrowed => LiveBorrowed(arc_borrow_roots(state, instruction, destination))
  }
}

///|
fn arc_destination_roots(
  state : Array[ArcValueState],
  instruction : Instruction,
  destination : ValueId,
) -> Array[ValueId] {
  let sources = match instruction {
    Move(_, source) | RetainCopy(_, source) => [source]
    MakeData(_, _, _, witnesses, fields) => witnesses + fields
    MakeEnv(_, _, _, _, captures) => captures
    MakeClosure(_, _, environment) => [environment]
    ByteSequenceSet(_, source, _, _) => [source]
    EraseI32(_, source)
    | UneraseI32(_, source)
    | EraseI64(_, source)
    | UneraseI64(_, source)
    | EraseF32(_, source)
    | UneraseF32(_, source)
    | EraseF64(_, source)
    | UneraseF64(_, source) => [source]
    _ => []
  }
  let roots = [destination]
  for source in sources {
    append_arc_roots(roots, arc_state_roots(state[source.value]))
  }
  roots
}

///|
fn arc_borrow_roots(
  state : Array[ArcValueState],
  instruction : Instruction,
  destination : ValueId,
) -> Array[ValueId] {
  let source = match instruction {
    BorrowField(_, source, _, result) | BorrowCapture(_, source, _, result) if projection_destinations(
        result,
      ).contains(destination) => Some(source)
    Copy(candidate, source) if candidate == destination => Some(source)
    _ => None
  }
  guard source is Some(value) else { return [] }
  arc_state_roots(state[value.value])
}

///|
fn arc_state_roots(state : ArcValueState) -> Array[ValueId] {
  match state {
    LiveOwned(roots) | LiveBorrowed(roots) => roots
    _ => []
  }
}

///|
fn append_arc_roots(
  destination : Array[ValueId],
  source : Array[ValueId],
) -> Unit {
  for root in source {
    if !destination.contains(root) {
      destination.push(root)
    }
  }
}

///|
fn first_uncovered_arc_root(
  state : Array[ArcValueState],
  roots : Array[ValueId],
) -> ValueId? {
  for root in roots {
    if !state.any(value_state => {
        value_state is LiveOwned(owned) && owned.contains(root)
      }) {
      return Some(root)
    }
  }
  None
}

///|
fn apply_arc_terminator(
  body : FunctionBody,
  block : @physical.BlockId,
  state : Array[ArcValueState],
  terminator : Terminator,
) -> Array[(@physical.BlockId, Array[ArcValueState])] raise FinalizeError {
  match terminator {
    Jump(edge) => [apply_arc_edge(body, block, state, edge)]
    BranchBool(condition, if_true, if_false) => {
      apply_arc_operand(body, block, state, condition, Borrow)
      [
        apply_arc_edge(body, block, state.copy(), if_true),
        apply_arc_edge(body, block, state.copy(), if_false),
      ]
    }
    SwitchTag(tag, cases, default) => {
      apply_arc_operand(body, block, state, tag, Borrow)
      let successors = cases.map(edge => {
        apply_arc_edge(body, block, state.copy(), edge)
      })
      successors.push(apply_arc_edge(body, block, state.copy(), default))
      successors
    }
    Fatal(message) => {
      apply_arc_operand(body, block, state, message, Borrow)
      []
    }
    Unreachable => []
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallPackedDirect(_, _, _, _)
    | TailCallValue(_, _, _) => {
      let plan = arc_terminal_plan(terminator).unwrap()
      for operand in plan.operands {
        let (value, mode) = operand
        apply_arc_operand(body, block, state, value, mode)
      }
      require_arc_ownership_empty(state, block)
      []
    }
  }
}

///|
fn apply_arc_edge(
  body : FunctionBody,
  block : @physical.BlockId,
  initial : Array[ArcValueState],
  edge : Edge,
) -> (@physical.BlockId, Array[ArcValueState]) raise FinalizeError {
  let state = initial
  let arguments = edge.arguments.map(value => state[value.value])
  for value in edge.arguments {
    apply_arc_operand(body, block, state, value, Consume)
  }
  let parameters = body.blocks[edge.target.value].parameters
  for index, parameter in parameters {
    if state[parameter.value] is LiveOwned(_) {
      arc_final_fail(OwnedValueOverwritten(parameter, block))
    }
    state[parameter.value] = arguments[index]
  }
  (edge.target, state)
}

///|
fn require_arc_ownership_empty(
  state : Array[ArcValueState],
  block : @physical.BlockId,
) -> Unit raise FinalizeError {
  for index, value_state in state {
    if value_state is LiveOwned(_) {
      arc_final_fail(OwnedValueEscapes({ value: index, }, block))
    }
  }
}

///|
fn merge_arc_entry(
  destination : Array[ArcValueState],
  incoming : Array[ArcValueState],
  block : @physical.BlockId,
) -> Bool raise FinalizeError {
  let mut changed = false
  for index in 0..<destination.length() {
    if destination[index] == incoming[index] {
      continue
    }
    match (destination[index], incoming[index]) {
      (LiveOwned(left), LiveOwned(right)) => {
        let joined = left.copy()
        append_arc_roots(joined, right)
        if joined != left {
          destination[index] = LiveOwned(joined)
          changed = true
        }
      }
      (LiveBorrowed(left), LiveBorrowed(right)) => {
        let joined = left.copy()
        append_arc_roots(joined, right)
        if joined != left {
          destination[index] = LiveBorrowed(joined)
          changed = true
        }
      }
      (LiveOwned(_), _) | (_, LiveOwned(_)) =>
        arc_final_fail(InconsistentOwnershipAtJoin({ value: index, }, block))
      _ =>
        if !(destination[index] is Unavailable) {
          destination[index] = Unavailable
          changed = true
        }
    }
  }
  changed
}
