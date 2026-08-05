///|
priv enum OwnershipOrigin {
  InputOwner(SlotId)
  InstructionOwner(BlockId, Int, SlotId)
} derive(Eq)

///|
priv struct ProjectionProvenance {
  shape : ObjectShapeId
  member_index : Int
} derive(Eq)

///|
priv struct OwnershipToken {
  origin : OwnershipOrigin
  projections : Array[ProjectionProvenance]
} derive(Eq)

///|
priv enum BorrowRoot {
  LocalRoots(Array[OwnershipToken])
  GlobalRoot(GlobalId)
} derive(Eq)

///|
priv struct BorrowProvenance {
  root : BorrowRoot
  projections : Array[ProjectionProvenance]
} derive(Eq)

///|
priv struct MemberOwnership {
  path : Array[ProjectionProvenance]
  roots : Array[OwnershipToken]
  retained : Array[OwnershipToken]
} derive(Eq)

///|
priv struct OwnershipProvenance {
  roots : Array[OwnershipToken]
  retained : Array[OwnershipToken]
  members : Array[MemberOwnership]
} derive(Eq)

///|
priv enum SlotFlowState {
  Unavailable
  LiveTrivial
  LiveBorrowed(Cleanup, BorrowProvenance)
  InvalidBorrow(BorrowProvenance)
  LiveOwned(Cleanup, OwnershipProvenance)
  MaybeOwned(Cleanup)
} derive(Eq)

///|
priv struct FunctionFlowState {
  slots : Array[SlotFlowState]
  globals : Array[Bool]
}

///|
fn FunctionFlowState::copy(self : FunctionFlowState) -> FunctionFlowState {
  { slots: self.slots.copy(), globals: self.globals.copy() }
}

///|
fn BytecodeVerifier::global_dependencies(
  self : BytecodeVerifier,
) -> Array[Array[Bool]] {
  let dependencies = self.image.functions.map(fn(_) {
    Array::make(self.image.globals.length(), false)
  })
  for function_index, entry in self.image.functions {
    if entry is BytecodeBody(body) {
      for block in body.blocks {
        for instruction in block.instructions {
          match instruction {
            BorrowGlobal(_, global) =>
              if global.value >= 0 && global.value < self.image.globals.length() {
                dependencies[function_index][global.value] = true
              }
            _ => ()
          }
        }
      }
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for function_index, entry in self.image.functions {
      if entry is BytecodeBody(body) {
        for block in body.blocks {
          for instruction in block.instructions {
            if instruction is CallDirect(target, _, _, _, _) &&
              target.value > 0 &&
              target.value <= self.image.functions.length() {
              if merge_global_dependencies(
                  dependencies[function_index],
                  dependencies[target.value - 1],
                ) {
                changed = true
              }
            }
          }
          if block.terminator is TailCallDirect(target, _, _, _) &&
            target.value > 0 &&
            target.value <= self.image.functions.length() {
            if merge_global_dependencies(
                dependencies[function_index],
                dependencies[target.value - 1],
              ) {
              changed = true
            }
          }
        }
      }
    }
  }
  dependencies
}

///|
fn merge_global_dependencies(
  destination : Array[Bool],
  source : Array[Bool],
) -> Bool {
  let mut changed = false
  for index in 0..<destination.length() {
    if source[index] && !destination[index] {
      destination[index] = true
      changed = true
    }
  }
  changed
}

///|
fn BytecodeVerifier::verify_function_flow(
  self : BytecodeVerifier,
  function : FunctionId,
  body : FunctionBody,
  global_dependencies : Array[Array[Bool]],
) -> Unit raise BytecodeVerificationError {
  let initial_slots = Array::make(
    body.slots.length(),
    SlotFlowState::Unavailable,
  )
  let function_site = BytecodeVerificationSite::Function(function)
  if body.inputs.environment is Some(environment) {
    initial_slots[environment.value] = flow_state_for_metadata(
      self.slot_metadata(function_site, body, environment),
      { origin: InputOwner(environment), projections: [] },
    )
  }
  for witness in body.inputs.witnesses {
    initial_slots[witness.value] = LiveTrivial
  }
  for parameter in body.inputs.user_parameters {
    initial_slots[parameter.value] = flow_state_for_metadata(
      self.slot_metadata(function_site, body, parameter),
      { origin: InputOwner(parameter), projections: [] },
    )
  }
  let is_initializer = self.image.initializer == Some(function)
  let initial_globals = Array::make(
    self.image.globals.length(),
    !is_initializer,
  )
  let entries : Array[FunctionFlowState?] = Array::make(
    body.blocks.length(),
    None,
  )
  entries[0] = Some({ slots: initial_slots, globals: initial_globals })
  let queue = [0]
  let mut cursor = 0
  while cursor < queue.length() {
    let block_index = queue[cursor]
    cursor += 1
    guard entries[block_index] is Some(entry) else {
      self.fail(function_site, "reachable block has no flow state")
    }
    let state = entry.copy()
    let block = body.blocks[block_index]
    let block_id : BlockId = { value: block_index }
    for instruction_index, instruction in block.instructions {
      let site = BytecodeVerificationSite::Instruction(
        function, block_id, instruction_index,
      )
      self.apply_instruction_flow(
        site, function, body, state, instruction, global_dependencies,
      )
    }
    let site = BytecodeVerificationSite::Terminator(function, block_id)
    let successors = self.apply_terminator_flow(
      site,
      function,
      body,
      state,
      block.terminator,
      global_dependencies,
      is_initializer~,
    )
    for successor in successors {
      let (target, incoming) = successor
      match entries[target] {
        None => {
          entries[target] = Some(incoming)
          queue.push(target)
        }
        Some(existing) =>
          if self.merge_predecessor_flow(site, existing, incoming) {
            queue.push(target)
          }
      }
    }
  }
}

///|
fn BytecodeVerifier::merge_predecessor_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  destination : FunctionFlowState,
  incoming : FunctionFlowState,
) -> Bool raise BytecodeVerificationError {
  if destination.globals != incoming.globals {
    self.fail(
      site, "control-flow predecessors disagree on global initialization state",
    )
  }
  let mut changed = false
  for index in 0..<destination.slots.length() {
    let joined = match (destination.slots[index], incoming.slots[index]) {
      (left, right) if left == right => left
      (LiveOwned(cleanup, _), Unavailable)
      | (Unavailable, LiveOwned(cleanup, _))
      | (MaybeOwned(cleanup), Unavailable)
      | (Unavailable, MaybeOwned(cleanup))
      | (MaybeOwned(cleanup), LiveOwned(_, _))
      | (LiveOwned(cleanup, _), MaybeOwned(_)) => MaybeOwned(cleanup)
      (LiveOwned(cleanup, left), LiveOwned(_, right)) =>
        LiveOwned(cleanup, merge_ownership_provenance(left, right))
      (LiveBorrowed(_, provenance), InvalidBorrow(invalid)) if provenance ==
        invalid => InvalidBorrow(provenance)
      (InvalidBorrow(invalid), LiveBorrowed(_, provenance)) if provenance ==
        invalid => InvalidBorrow(provenance)
      _ => Unavailable
    }
    if joined != destination.slots[index] {
      destination.slots[index] = joined
      changed = true
    }
  }
  changed
}

///|
fn flow_state_for_metadata(
  metadata : SlotMetadata,
  token : OwnershipToken,
) -> SlotFlowState {
  match metadata.cleanup {
    Trivial => LiveTrivial
    cleanup =>
      LiveOwned(cleanup, { roots: [token], retained: [token], members: [] })
  }
}

///|
fn merged_tokens(
  left : Array[OwnershipToken],
  right : Array[OwnershipToken],
) -> Array[OwnershipToken] {
  let merged = left.copy()
  append_retained_tokens(merged, right)
  merged
}

///|
fn merge_member_ownership(
  left : MemberOwnership,
  right : MemberOwnership,
) -> MemberOwnership {
  {
    path: left.path,
    roots: merged_tokens(left.roots, right.roots),
    retained: merged_tokens(left.retained, right.retained),
  }
}

///|
fn merge_member_ownerships(
  left : Array[MemberOwnership],
  right : Array[MemberOwnership],
) -> Array[MemberOwnership] {
  let merged = []
  for left_member in left {
    for right_member in right {
      if left_member.path == right_member.path {
        merged.push(merge_member_ownership(left_member, right_member))
        break
      }
    }
  }
  merged
}

///|
fn merge_ownership_provenance(
  left : OwnershipProvenance,
  right : OwnershipProvenance,
) -> OwnershipProvenance {
  {
    roots: merged_tokens(left.roots, right.roots),
    retained: merged_tokens(left.retained, right.retained),
    members: merge_member_ownerships(left.members, right.members),
  }
}

///|
fn BytecodeVerifier::instruction_owner_token(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  destination : SlotId,
) -> OwnershipToken raise BytecodeVerificationError {
  match site {
    Instruction(_, block, instruction_index) =>
      {
        origin: InstructionOwner(block, instruction_index, destination),
        projections: [],
      }
    _ => self.fail(site, "owner definition is not an instruction")
  }
}

///|
fn ownership_token_covers(
  retained : OwnershipToken,
  required : OwnershipToken,
) -> Bool {
  if retained.origin != required.origin ||
    retained.projections.length() > required.projections.length() {
    return false
  }
  for index in 0..<retained.projections.length() {
    if retained.projections[index] != required.projections[index] {
      return false
    }
  }
  true
}

///|
fn local_root_is_live(
  state : FunctionFlowState,
  token : OwnershipToken,
) -> Bool {
  state.slots.any(slot => {
    slot is LiveOwned(_, ownership) &&
    ownership.retained.any(retained => ownership_token_covers(retained, token))
  })
}

///|
fn ownership_origin_is_live(
  state : FunctionFlowState,
  origin : OwnershipOrigin,
) -> Bool {
  state.slots.any(slot => {
    slot is LiveOwned(_, ownership) &&
    ownership.retained.any(token => token.origin == origin)
  })
}

///|
fn local_roots_are_live(
  state : FunctionFlowState,
  tokens : Array[OwnershipToken],
) -> Bool {
  tokens.all(token => local_root_is_live(state, token))
}

///|
fn borrow_origin_text(provenance : BorrowProvenance) -> String {
  match provenance.projections.last() {
    Some({ shape, member_index }) =>
      "ObjectShapeId \{shape.value} member \{member_index}"
    None => "its root value"
  }
}

///|
fn BytecodeVerifier::require_borrow_root_live(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  state : FunctionFlowState,
  borrowed_slot : SlotId,
  provenance : BorrowProvenance,
) -> Unit raise BytecodeVerificationError {
  match provenance.root {
    GlobalRoot(_) => ()
    LocalRoots(tokens) =>
      if !local_roots_are_live(state, tokens) {
        self.fail(
          site,
          "borrowed SlotId \{borrowed_slot.value} from \{borrow_origin_text(provenance)} outlives its local owner",
        )
      }
  }
}

///|
fn invalidate_consumed_root_borrows(
  state : FunctionFlowState,
  token : OwnershipToken,
) -> Unit {
  if local_root_is_live(state, token) {
    return
  }
  for index, slot in state.slots {
    if slot is LiveBorrowed(_, { root: LocalRoots(roots), .. }) &&
      roots.any(root => ownership_token_covers(token, root)) &&
      !local_roots_are_live(state, roots) {
      guard slot is LiveBorrowed(_, provenance) else { continue }
      state.slots[index] = InvalidBorrow(provenance)
    }
  }
}

///|
fn BytecodeVerifier::require_new_owner_token_available(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  state : FunctionFlowState,
  token : OwnershipToken,
) -> Unit raise BytecodeVerificationError {
  if ownership_origin_is_live(state, token.origin) {
    self.fail(site, "owner definition is still live from an earlier iteration")
  }
}

///|
fn BytecodeVerifier::read_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  state : FunctionFlowState,
  slot : SlotId,
) -> SlotFlowState raise BytecodeVerificationError {
  match state.slots[slot.value] {
    Unavailable =>
      self.fail(site, "read from uninitialized SlotId \{slot.value}")
    MaybeOwned(_) =>
      self.fail(
        site,
        "owned SlotId \{slot.value} is not live on every predecessor",
      )
    InvalidBorrow(provenance) =>
      self.fail(
        site,
        "borrowed SlotId \{slot.value} from \{borrow_origin_text(provenance)} outlives its local owner",
      )
    LiveBorrowed(_, provenance) as live => {
      self.require_borrow_root_live(site, state, slot, provenance)
      live
    }
    live => live
  }
}

///|
fn BytecodeVerifier::require_erased_companion_live(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  slot : SlotId,
) -> Unit raise BytecodeVerificationError {
  let metadata = body.slots[slot.value]
  if metadata.cleanup is OwnedErased {
    guard metadata.erased_companion is Some(companion) else {
      self.fail(site, "OwnedErased slot lacks a companion")
    }
    if self.read_flow(site, state, companion) != LiveTrivial {
      self.fail(site, "OwnedErased companion is not a live trivial witness")
    }
  }
}

///|
fn BytecodeVerifier::write_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  value : SlotFlowState,
) -> Unit raise BytecodeVerificationError {
  if state.slots[destination.value] is LiveOwned(_, _) ||
    state.slots[destination.value] is MaybeOwned(_) {
    self.fail(
      site,
      "write would overwrite live owner SlotId \{destination.value}",
    )
  }
  if value is LiveOwned(OwnedErased, _) {
    self.require_erased_companion_live(site, body, state, destination)
  }
  state.slots[destination.value] = value
}

///|
fn BytecodeVerifier::write_from_metadata(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
) -> Unit raise BytecodeVerificationError {
  let token = self.instruction_owner_token(site, destination)
  if body.slots[destination.value].cleanup != Trivial {
    self.require_new_owner_token_available(site, state, token)
  }
  self.write_flow(
    site,
    body,
    state,
    destination,
    flow_state_for_metadata(body.slots[destination.value], token),
  )
}

///|
fn append_retained_tokens(
  destination : Array[OwnershipToken],
  source : Array[OwnershipToken],
) -> Unit {
  for token in source {
    if !destination.contains(token) {
      destination.push(token)
    }
  }
}

///|
fn projected_tokens(
  roots : Array[OwnershipToken],
  projection : ProjectionProvenance,
) -> Array[OwnershipToken] {
  roots.map(root => {
    let projections = root.projections.copy()
    projections.push(projection)
    { ..root, projections, }
  })
}

///|
fn prefixed_projection_path(
  prefix : ProjectionProvenance,
  path : Array[ProjectionProvenance],
) -> Array[ProjectionProvenance] {
  let prefixed = [prefix]
  prefixed.append(path)
  prefixed
}

///|
fn direct_member_ownership(
  ownership : OwnershipProvenance,
  projection : ProjectionProvenance,
) -> MemberOwnership? {
  for entry in ownership.members {
    if entry.path.length() == 1 && entry.path[0] == projection {
      return Some(entry)
    }
  }
  None
}

///|
fn ownership_after_projection(
  ownership : OwnershipProvenance,
  projection : ProjectionProvenance,
) -> OwnershipProvenance {
  let direct = direct_member_ownership(ownership, projection)
  let roots = match direct {
    Some(entry) => entry.roots.copy()
    None => projected_tokens(ownership.roots, projection)
  }
  let retained = match direct {
    Some(entry) => entry.retained.copy()
    None => roots.copy()
  }
  let members = []
  for entry in ownership.members {
    if entry.path.length() > 1 && entry.path[0] == projection {
      members.push({
        path: entry.path[1:].to_owned(),
        roots: entry.roots,
        retained: entry.retained,
      })
    }
  }
  { roots, retained, members }
}

///|
fn BytecodeVerifier::write_transferred_owner(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  ownership : OwnershipProvenance,
) -> Unit raise BytecodeVerificationError {
  let cleanup = body.slots[destination.value].cleanup
  if cleanup is Trivial {
    self.write_flow(site, body, state, destination, LiveTrivial)
    for token in ownership.retained {
      invalidate_consumed_root_borrows(state, token)
    }
  } else {
    self.write_flow(
      site,
      body,
      state,
      destination,
      LiveOwned(cleanup, ownership),
    )
  }
}

///|
fn BytecodeVerifier::transfer_aggregate_ownership(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  shape : ObjectShapeId,
  fields : Array[SlotId],
) -> Unit raise BytecodeVerificationError {
  let values = fields.map(field => self.read_flow(site, state, field))
  for index, field in fields {
    if values[index] is (LiveBorrowed(_, _) | InvalidBorrow(_)) {
      self.fail(site, "aggregate construction cannot consume a borrowed value")
    }
    if values[index] is LiveOwned(_, _) {
      for earlier in 0..<index {
        if fields[earlier] == field && values[earlier] is LiveOwned(_, _) {
          self.fail(site, "aggregate construction consumes one owner twice")
        }
      }
      state.slots[field.value] = Unavailable
    }
  }
  let token = self.instruction_owner_token(site, destination)
  self.require_new_owner_token_available(site, state, token)
  let retained = [token]
  let members : Array[MemberOwnership] = []
  for index, value in values {
    match value {
      LiveOwned(_, ownership) => {
        append_retained_tokens(retained, ownership.retained)
        let projection = { shape, member_index: index }
        members.push({
          path: [projection],
          roots: ownership.roots,
          retained: ownership.retained,
        })
        for entry in ownership.members {
          members.push({
            ..entry,
            path: prefixed_projection_path(projection, entry.path),
          })
        }
      }
      _ => ()
    }
  }
  self.write_transferred_owner(site, body, state, destination, {
    roots: [token],
    retained,
    members,
  })
}

///|
fn BytecodeVerifier::transfer_owner_into_new_value(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  source : SlotId,
) -> Unit raise BytecodeVerificationError {
  guard self.read_flow(site, state, source) is LiveOwned(_, ownership) else {
    self.fail(site, "ownership transfer source is not a live owner")
  }
  state.slots[source.value] = Unavailable
  let token = self.instruction_owner_token(site, destination)
  self.require_new_owner_token_available(site, state, token)
  let retained = [token]
  append_retained_tokens(retained, ownership.retained)
  self.write_transferred_owner(site, body, state, destination, {
    roots: [token],
    retained,
    members: [],
  })
}

///|
fn BytecodeVerifier::consume_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
) -> SlotFlowState raise BytecodeVerificationError {
  let live = self.read_flow(site, state, source)
  match live {
    LiveBorrowed(_, _) =>
      self.fail(site, "borrowed SlotId \{source.value} cannot be consumed")
    LiveOwned(OwnedErased, _) =>
      self.require_erased_companion_live(site, body, state, source)
    _ => ()
  }
  if live is LiveOwned(_, ownership) {
    state.slots[source.value] = Unavailable
    for token in ownership.retained {
      invalidate_consumed_root_borrows(state, token)
    }
  }
  live
}

///|
fn BytecodeVerifier::consume_owner(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
) -> Cleanup raise BytecodeVerificationError {
  match self.consume_flow(site, body, state, source) {
    LiveOwned(cleanup, _) => cleanup
    _ => self.fail(site, "SlotId \{source.value} is not a live owner")
  }
}

///|
fn BytecodeVerifier::write_trivial_after_reads(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  sources : Array[SlotId],
) -> Unit raise BytecodeVerificationError {
  for source in sources {
    ignore(self.read_flow(site, state, source))
  }
  self.write_flow(site, body, state, destination, LiveTrivial)
}

///|
fn BytecodeVerifier::apply_instruction_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  function : FunctionId,
  body : FunctionBody,
  state : FunctionFlowState,
  instruction : Instruction,
  global_dependencies : Array[Array[Bool]],
) -> Unit raise BytecodeVerificationError {
  match instruction {
    Copy(destination, source) => {
      let value = self.read_flow(site, state, source)
      self.write_flow(site, body, state, destination, value)
    }
    Move(destination, source) => {
      let value = self.read_flow(site, state, source)
      match value {
        LiveBorrowed(_, _) =>
          self.fail(site, "borrowed SlotId \{source.value} cannot be moved")
        LiveOwned(_, _) if destination == source => ()
        LiveOwned(_, _) => {
          self.write_flow(site, body, state, destination, value)
          state.slots[source.value] = Unavailable
        }
        _ => self.write_flow(site, body, state, destination, value)
      }
    }
    RetainCopy(destination, source) => {
      let source_state = self.read_flow(site, state, source)
      let cleanup = match source_state {
        LiveOwned(cleanup, _) | LiveBorrowed(cleanup, _) => cleanup
        _ => self.fail(site, "RetainCopy source is not a retainable value")
      }
      if cleanup != body.slots[destination.value].cleanup {
        self.fail(site, "RetainCopy changes the resource cleanup kind")
      }
      match source_state {
        LiveOwned(_, ownership) =>
          self.write_flow(
            site,
            body,
            state,
            destination,
            LiveOwned(cleanup, ownership),
          )
        LiveBorrowed(_, _) =>
          self.write_from_metadata(site, body, state, destination)
        _ => self.fail(site, "RetainCopy source is not a retainable value")
      }
    }
    Release(source) =>
      match self.read_flow(site, state, source) {
        LiveOwned(_, _) => ignore(self.consume_owner(site, body, state, source))
        LiveTrivial => ()
        LiveBorrowed(_, _) =>
          self.fail(site, "Release cannot consume a borrowed value")
        InvalidBorrow(_) =>
          self.fail(site, "Release reads an invalid borrowed value")
        MaybeOwned(_) =>
          self.fail(site, "Release requires a definitely live owner")
        Unavailable => self.fail(site, "Release reads an uninitialized slot")
      }
    ConstI64(destination, _)
    | ConstI32(destination, _)
    | ConstChar(destination, _)
    | ConstF64(destination, _)
    | ConstF32(destination, _)
    | ConstBool(destination, _)
    | ConstLayout(destination, _) =>
      self.write_flow(site, body, state, destination, LiveTrivial)
    ConstFunction(destination, _) | ConstString(destination, _) =>
      self.write_from_metadata(site, body, state, destination)
    CallDirect(target, environment, witnesses, arguments, destination) => {
      for witness in witnesses {
        ignore(self.read_flow(site, state, witness))
      }
      self.require_global_dependencies(
        site,
        state,
        global_dependencies[target.value - 1],
      )
      if environment is Some(environment) {
        ignore(self.consume_owner(site, body, state, environment))
      }
      for argument in arguments {
        ignore(self.consume_flow(site, body, state, argument))
      }
      if destination is Some(destination) {
        self.write_from_metadata(site, body, state, destination)
      }
    }
    CallValue(callable, witnesses, arguments, destination) => {
      for witness in witnesses {
        ignore(self.read_flow(site, state, witness))
      }
      ignore(self.consume_owner(site, body, state, callable))
      for argument in arguments {
        ignore(self.consume_flow(site, body, state, argument))
      }
      if destination is Some(destination) {
        self.write_from_metadata(site, body, state, destination)
      }
    }
    MakeData(destination, shape, layout, witnesses, fields)
    | MakeEnv(destination, shape, layout, witnesses, fields) => {
      if layout is Witness(witness) {
        ignore(self.read_flow(site, state, witness))
      }
      for witness in witnesses {
        ignore(self.read_flow(site, state, witness))
      }
      self.transfer_aggregate_ownership(
        site, body, state, destination, shape, fields,
      )
    }
    LoadTag(destination, source)
    | LoadObjectWitness(destination, _, source, _) =>
      self.write_trivial_after_reads(site, body, state, destination, [source])
    BorrowField(shape, source, member_index, result) => {
      guard self.image.object_shapes[shape.value] is Data(data) else {
        self.fail(site, "BorrowField shape changed after static verification")
      }
      self.write_borrowed_projection(
        site,
        body,
        state,
        source,
        shape,
        member_index,
        data.members[member_index],
        result,
      )
    }
    BorrowCapture(shape, source, member_index, result) => {
      guard self.image.object_shapes[shape.value] is Environment(environment) else {
        self.fail(site, "BorrowCapture shape changed after static verification")
      }
      self.write_borrowed_projection(
        site,
        body,
        state,
        source,
        shape,
        member_index,
        environment.members[member_index],
        result,
      )
    }
    ConsumeFields(shape, source, selections) => {
      guard self.image.object_shapes[shape.value] is Data(_) else {
        self.fail(site, "ConsumeFields shape changed after static verification")
      }
      self.write_consumed_projections(
        site, body, state, source, shape, selections,
      )
    }
    ConsumeCaptures(shape, source, selections) => {
      guard self.image.object_shapes[shape.value] is Environment(_) else {
        self.fail(
          site, "ConsumeCaptures shape changed after static verification",
        )
      }
      self.write_consumed_projections(
        site, body, state, source, shape, selections,
      )
    }
    MakeClosure(destination, _, environment) =>
      self.transfer_owner_into_new_value(
        site, body, state, destination, environment,
      )
    ByteSequenceSet(destination, source, index, value) => {
      ignore(self.read_flow(site, state, index))
      ignore(self.read_flow(site, state, value))
      ignore(self.consume_owner(site, body, state, source))
      self.write_from_metadata(site, body, state, destination)
    }
    ByteSequenceConcat(destination, left, right) => {
      ignore(self.consume_owner(site, body, state, left))
      ignore(self.consume_owner(site, body, state, right))
      self.write_from_metadata(site, body, state, destination)
    }
    ByteSequenceSlice(destination, source, start, length) => {
      ignore(self.read_flow(site, state, start))
      ignore(self.read_flow(site, state, length))
      ignore(self.consume_owner(site, body, state, source))
      self.write_from_metadata(site, body, state, destination)
    }
    ByteSequenceMake(destination, length, fill) => {
      ignore(self.read_flow(site, state, length))
      ignore(self.read_flow(site, state, fill))
      self.write_from_metadata(site, body, state, destination)
    }
    F32ToString(destination, source) | F64ToString(destination, source) => {
      ignore(self.read_flow(site, state, source))
      self.write_from_metadata(site, body, state, destination)
    }
    EraseI32(destination, source)
    | EraseI64(destination, source)
    | EraseF64(destination, source)
    | EraseF32(destination, source) =>
      match self.read_flow(site, state, source) {
        LiveOwned(_, ownership) => {
          state.slots[source.value] = Unavailable
          self.write_transferred_owner(
            site, body, state, destination, ownership,
          )
        }
        LiveTrivial => self.write_from_metadata(site, body, state, destination)
        _ => ignore(self.consume_flow(site, body, state, source))
      }
    UneraseI32(destination, source)
    | UneraseI64(destination, source)
    | UneraseF64(destination, source)
    | UneraseF32(destination, source) => {
      guard self.read_flow(site, state, source) is LiveOwned(_, ownership) else {
        self.fail(site, "unerasure source is not a live owner")
      }
      state.slots[source.value] = Unavailable
      self.write_transferred_owner(site, body, state, destination, ownership)
    }
    EraseUnit(destination) =>
      self.write_from_metadata(site, body, state, destination)
    UneraseUnit(source) => ignore(self.consume_owner(site, body, state, source))
    InitGlobal(global, source) => {
      if self.image.initializer != Some(function) {
        self.fail(site, "InitGlobal appears outside the instance initializer")
      }
      self.initialize_global_flow(site, body, state, global, source)
    }
    BorrowGlobal(destination, global) =>
      self.borrow_global_flow(site, body, state, destination, global)
    unary_or_binary =>
      self.apply_trivial_instruction_flow(site, body, state, unary_or_binary)
  }
}

///|
fn BytecodeVerifier::apply_trivial_instruction_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  instruction : Instruction,
) -> Unit raise BytecodeVerificationError {
  match instruction {
    ByteToI64(destination, source)
    | I64ToByte(destination, source)
    | ByteSequenceLength(destination, source)
    | ByteSequenceIsValidUtf8(destination, source)
    | I32Neg(destination, source)
    | I32ToI64(destination, source)
    | I64ToI32(destination, source)
    | I64Neg(destination, source)
    | I64Not(destination, source)
    | BoolNot(destination, source)
    | F64Neg(destination, source)
    | I64ToF64(destination, source)
    | F64ToI64(destination, source)
    | F32Neg(destination, source)
    | I64ToF32(destination, source)
    | F32ToI64(destination, source)
    | F32ToF64(destination, source)
    | F64ToF32(destination, source) =>
      self.write_trivial_after_reads(site, body, state, destination, [source])
    ByteSequenceGet(destination, source, index) =>
      self.write_trivial_after_reads(site, body, state, destination, [
        source, index,
      ])
    ByteSequenceEqual(destination, left, right)
    | I32Add(destination, left, right)
    | I32Sub(destination, left, right)
    | I32Mul(destination, left, right)
    | I32Div(destination, left, right)
    | I32Rem(destination, left, right)
    | I32Eq(destination, left, right)
    | I32Lt(destination, left, right)
    | I64Add(destination, left, right)
    | I64Sub(destination, left, right)
    | I64Mul(destination, left, right)
    | I64Div(destination, left, right)
    | I64Rem(destination, left, right)
    | I64And(destination, left, right)
    | I64Or(destination, left, right)
    | I64Xor(destination, left, right)
    | I64Shl(destination, left, right)
    | I64ShrS(destination, left, right)
    | I64Eq(destination, left, right)
    | I64Ne(destination, left, right)
    | I64Lt(destination, left, right)
    | I64Le(destination, left, right)
    | I64Gt(destination, left, right)
    | I64Ge(destination, left, right)
    | BoolEq(destination, left, right)
    | BoolNe(destination, left, right)
    | F64Add(destination, left, right)
    | F64Sub(destination, left, right)
    | F64Mul(destination, left, right)
    | F64Div(destination, left, right)
    | F64Eq(destination, left, right)
    | F64Ne(destination, left, right)
    | F64Lt(destination, left, right)
    | F64Le(destination, left, right)
    | F64Gt(destination, left, right)
    | F64Ge(destination, left, right)
    | F32Add(destination, left, right)
    | F32Sub(destination, left, right)
    | F32Mul(destination, left, right)
    | F32Div(destination, left, right)
    | F32Eq(destination, left, right)
    | F32Ne(destination, left, right)
    | F32Lt(destination, left, right)
    | F32Le(destination, left, right)
    | F32Gt(destination, left, right)
    | F32Ge(destination, left, right) =>
      self.write_trivial_after_reads(site, body, state, destination, [
        left, right,
      ])
    _ => self.fail(site, "instruction has no dataflow rule")
  }
}

///|
fn BytecodeVerifier::write_borrowed_projection(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
  shape : ObjectShapeId,
  member_index : Int,
  schema : MemberSchema,
  result : ProjectionResult,
) -> Unit raise BytecodeVerificationError {
  if result.witness_destination is Some(witness) {
    self.write_flow(site, body, state, witness, LiveTrivial)
  }
  let value = match schema.cleanup {
    Trivial => SlotFlowState::LiveTrivial
    cleanup => {
      let provenance = match self.read_flow(site, state, source) {
        LiveOwned(OwnedRef, ownership) => {
          let projection = { shape, member_index }
          let roots = ownership_after_projection(ownership, projection).roots
          { root: LocalRoots(roots), projections: [] }
        }
        LiveBorrowed(OwnedRef, provenance) =>
          { ..provenance, projections: provenance.projections.copy() }
        _ =>
          self.fail(
            site, "borrowed projection source is not a live object reference",
          )
      }
      provenance.projections.push({ shape, member_index })
      LiveBorrowed(cleanup, provenance)
    }
  }
  self.write_flow(site, body, state, result.value_destination, value)
}

///|
fn BytecodeVerifier::write_consumed_projections(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
  shape : ObjectShapeId,
  selections : Array[ProjectionSelection],
) -> Unit raise BytecodeVerificationError {
  guard self.read_flow(site, state, source) is LiveOwned(_, ownership) else {
    self.fail(site, "consuming projection source is not a live owner")
  }
  state.slots[source.value] = Unavailable
  for selection in selections {
    if selection.result.witness_destination is Some(witness) {
      self.write_flow(site, body, state, witness, LiveTrivial)
    }
    self.write_transferred_owner(
      site,
      body,
      state,
      selection.result.value_destination,
      ownership_after_projection(ownership, {
        shape,
        member_index: selection.member_index,
      }),
    )
  }
  for token in ownership.retained {
    invalidate_consumed_root_borrows(state, token)
  }
}

///|
fn BytecodeVerifier::initialize_global_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  global : GlobalId,
  source : SlotId,
) -> Unit raise BytecodeVerificationError {
  if state.globals[global.value] {
    self.fail(site, "GlobalId \{global.value} is initialized twice")
  }
  ignore(self.consume_flow(site, body, state, source))
  let metadata = self.image.globals[global.value]
  if metadata.erased_companion is Some(global_companion) {
    if state.globals[global_companion.value] {
      self.fail(site, "erased companion global is initialized twice")
    }
    guard body.slots[source.value].erased_companion is Some(source_companion) else {
      self.fail(site, "OwnedErased source lacks a companion")
    }
    ignore(self.read_flow(site, state, source_companion))
    state.globals[global_companion.value] = true
  }
  state.globals[global.value] = true
}

///|
fn BytecodeVerifier::borrow_global_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  global : GlobalId,
) -> Unit raise BytecodeVerificationError {
  if !state.globals[global.value] {
    self.fail(site, "read from uninitialized GlobalId \{global.value}")
  }
  let metadata = self.image.globals[global.value]
  if metadata.erased_companion is Some(global_companion) {
    if !state.globals[global_companion.value] {
      self.fail(site, "erased companion global is uninitialized")
    }
    guard body.slots[destination.value].erased_companion
      is Some(destination_companion) else {
      self.fail(site, "OwnedErased global borrow destination lacks a companion")
    }
    self.write_flow(site, body, state, destination_companion, LiveTrivial)
  }
  self.write_flow(
    site,
    body,
    state,
    destination,
    match metadata.cleanup {
      Trivial => LiveTrivial
      cleanup =>
        LiveBorrowed(cleanup, { root: GlobalRoot(global), projections: [] })
    },
  )
}

///|
fn BytecodeVerifier::require_global_dependencies(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  state : FunctionFlowState,
  dependencies : Array[Bool],
) -> Unit raise BytecodeVerificationError {
  for index, required in dependencies {
    if required && !state.globals[index] {
      self.fail(site, "call may read uninitialized GlobalId \{index}")
    }
  }
}

///|
fn BytecodeVerifier::require_initializer_globals_complete(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  state : FunctionFlowState,
) -> Unit raise BytecodeVerificationError {
  for index, initialized in state.globals {
    if !initialized {
      self.fail(site, "initializer leaves GlobalId \{index} uninitialized")
    }
  }
}

///|
fn BytecodeVerifier::apply_terminator_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  function : FunctionId,
  body : FunctionBody,
  state : FunctionFlowState,
  terminator : Terminator,
  global_dependencies : Array[Array[Bool]],
  is_initializer~ : Bool,
) -> Array[(Int, FunctionFlowState)] raise BytecodeVerificationError {
  match terminator {
    Jump(edge) => [self.transfer_edge_flow(site, body, state, edge)]
    BranchBool(condition, true_edge, false_edge) => {
      ignore(self.read_flow(site, state, condition))
      [
        self.transfer_edge_flow(site, body, state.copy(), true_edge),
        self.transfer_edge_flow(site, body, state.copy(), false_edge),
      ]
    }
    SwitchTag(tag, cases, default) => {
      ignore(self.read_flow(site, state, tag))
      let successors = cases.map(edge => {
        self.transfer_edge_flow(site, body, state.copy(), edge)
      })
      successors.push(
        self.transfer_edge_flow(site, body, state.copy(), default),
      )
      successors
    }
    Return(source) => {
      if source is Some(source) {
        ignore(self.consume_flow(site, body, state, source))
      }
      self.require_no_live_owners(site, state)
      if is_initializer {
        self.require_initializer_globals_complete(site, state)
      }
      []
    }
    TailCallDirect(target, environment, witnesses, arguments) => {
      for witness in witnesses {
        ignore(self.read_flow(site, state, witness))
      }
      self.require_global_dependencies(
        site,
        state,
        global_dependencies[target.value - 1],
      )
      if environment is Some(environment) {
        ignore(self.consume_owner(site, body, state, environment))
      }
      for argument in arguments {
        ignore(self.consume_flow(site, body, state, argument))
      }
      self.require_no_live_owners(site, state)
      []
    }
    TailCallValue(callable, witnesses, arguments) => {
      for witness in witnesses {
        ignore(self.read_flow(site, state, witness))
      }
      ignore(self.consume_owner(site, body, state, callable))
      for argument in arguments {
        ignore(self.consume_flow(site, body, state, argument))
      }
      self.require_no_live_owners(site, state)
      []
    }
    Unreachable => {
      ignore(function)
      []
    }
  }
}

///|
fn BytecodeVerifier::transfer_edge_flow(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  edge : Edge,
) -> (Int, FunctionFlowState) raise BytecodeVerificationError {
  let target = body.blocks[edge.target.value]
  let values = edge.arguments.map(argument => {
    self.read_flow(site, state, argument)
  })
  for index, argument in edge.arguments {
    let value = values[index]
    match value {
      LiveBorrowed(_, _) =>
        self.fail(site, "borrowed values cannot cross block edges")
      LiveOwned(OwnedErased, _) =>
        self.require_erased_companion_live(site, body, state, argument)
      LiveOwned(_, _) => ()
      _ => continue
    }
    for earlier in 0..<index {
      if edge.arguments[earlier] == argument {
        self.fail(site, "an owned edge argument cannot be transferred twice")
      }
    }
  }
  for index, argument in edge.arguments {
    if values[index] is LiveOwned(_, _) {
      state.slots[argument.value] = Unavailable
    }
  }
  for index in 0..<values.length() {
    self.write_flow(site, body, state, target.parameters[index], values[index])
  }
  (edge.target.value, state)
}

///|
fn BytecodeVerifier::require_no_live_owners(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  state : FunctionFlowState,
) -> Unit raise BytecodeVerificationError {
  for index, slot in state.slots {
    if slot is LiveOwned(_, _) {
      self.fail(site, "live owner SlotId \{index} escapes function completion")
    }
    if slot is MaybeOwned(_) {
      self.fail(
        site,
        "possible owner SlotId \{index} escapes function completion",
      )
    }
  }
}
