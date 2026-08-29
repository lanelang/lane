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
  object_shapes : Array[ObjectShapeId?]
  layout_recipes : Array[LayoutRecipe?]
  tag_sources : Array[SlotId?]
  mut initialized_global_prefix : Int
}

///|
fn FunctionFlowState::copy(self : FunctionFlowState) -> FunctionFlowState {
  {
    slots: self.slots.copy(),
    object_shapes: self.object_shapes.copy(),
    layout_recipes: self.layout_recipes.copy(),
    tag_sources: self.tag_sources.copy(),
    initialized_global_prefix: self.initialized_global_prefix,
  }
}

///|
fn PhysicalProgramVerifier::global_dependencies(
  self : PhysicalProgramVerifier,
) -> Array[Array[Bool]] {
  let dependencies = self.image.functions.map(fn(_) {
    Array::make(self.image.globals.length(), false)
  })
  for function_index, entry in self.image.functions {
    if entry is PhysicalBody(body) {
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
      if entry is PhysicalBody(body) {
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
fn PhysicalProgramVerifier::verify_function_flow(
  self : PhysicalProgramVerifier,
  function : FunctionId,
  body : FunctionBody,
  global_dependencies : Array[Array[Bool]],
  global_lifecycle : GlobalLifecyclePlan,
) -> Unit raise PhysicalProgramVerificationError {
  let initial_slots = Array::make(
    body.slots.length(),
    SlotFlowState::Unavailable,
  )
  let function_site = PhysicalVerificationSite::Function(function)
  let initial_object_shapes : Array[ObjectShapeId?] = Array::make(
    body.slots.length(),
    None,
  )
  let initial_tag_sources : Array[SlotId?] = Array::make(
    body.slots.length(),
    None,
  )
  let initial_layout_recipes : Array[LayoutRecipe?] = Array::make(
    body.slots.length(),
    None,
  )
  if body.inputs.environment is Some(environment) {
    initial_slots[environment.value] = flow_state_for_metadata(
      self.slot_metadata(function_site, body, environment),
      { origin: InputOwner(environment), projections: [], },
    )
    initial_object_shapes[environment.value] = statically_known_object_shape(
      self.image.object_shapes,
      body.slots[environment.value].kind,
    )
  }
  for witness in body.inputs.witnesses {
    initial_slots[witness.value] = flow_state_for_metadata(
      self.slot_metadata(function_site, body, witness),
      { origin: InputOwner(witness), projections: [], },
    )
  }
  for parameter in body.inputs.user_parameters {
    initial_slots[parameter.value] = flow_state_for_metadata(
      self.slot_metadata(function_site, body, parameter),
      { origin: InputOwner(parameter), projections: [], },
    )
    initial_object_shapes[parameter.value] = statically_known_object_shape(
      self.image.object_shapes,
      body.slots[parameter.value].kind,
    )
  }
  let is_initializer = self.image.initializer == Some(function)
  let initialized_global_prefix = if is_initializer {
    0
  } else {
    global_lifecycle.roots.length()
  }
  let entries : Array[FunctionFlowState?] = Array::make(
    body.blocks.length(),
    None,
  )
  entries[0] = Some({
    slots: initial_slots,
    object_shapes: initial_object_shapes,
    layout_recipes: initial_layout_recipes,
    tag_sources: initial_tag_sources,
    initialized_global_prefix,
  })
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
    let block_id : BlockId = { value: block_index, }
    for instruction_index, instruction in block.instructions {
      let site = PhysicalVerificationSite::Instruction(
        function, block_id, instruction_index,
      )
      self.apply_instruction_flow(
        site, function, body, state, instruction, global_dependencies, global_lifecycle,
      )
    }
    let site = PhysicalVerificationSite::Terminator(function, block_id)
    let successors = self.apply_terminator_flow(
      site,
      function,
      body,
      state,
      block.terminator,
      global_dependencies,
      global_lifecycle,
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
fn PhysicalProgramVerifier::merge_predecessor_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  destination : FunctionFlowState,
  incoming : FunctionFlowState,
) -> Bool raise PhysicalProgramVerificationError {
  if destination.initialized_global_prefix != incoming.initialized_global_prefix {
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
    let joined_shape = if destination.object_shapes[index] ==
      incoming.object_shapes[index] {
      destination.object_shapes[index]
    } else {
      None
    }
    if joined_shape != destination.object_shapes[index] {
      destination.object_shapes[index] = joined_shape
      changed = true
    }
    let joined_layout = if destination.layout_recipes[index] ==
      incoming.layout_recipes[index] {
      destination.layout_recipes[index]
    } else {
      None
    }
    if joined_layout != destination.layout_recipes[index] {
      destination.layout_recipes[index] = joined_layout
      changed = true
    }
    let joined_tag_source = if destination.tag_sources[index] ==
      incoming.tag_sources[index] {
      destination.tag_sources[index]
    } else {
      None
    }
    if joined_tag_source != destination.tag_sources[index] {
      destination.tag_sources[index] = joined_tag_source
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
      LiveOwned(cleanup, { roots: [token], retained: [token], members: [], })
  }
}

///|
fn PhysicalProgramVerifier::kind_accepts_object_shape(
  self : PhysicalProgramVerifier,
  kind : SemanticValueKind,
  shape : ObjectShapeId,
) -> Bool {
  match (kind, self.image.object_shapes[shape.value]) {
    (DataValue(expected), Data({ family: actual, .. })) => expected == actual
    (EnvironmentValue(expected), Environment(_)) => expected == shape
    _ => false
  }
}

///|
fn PhysicalProgramVerifier::require_object_layout_witness(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  witness : SlotId,
  shape : ObjectShapeId,
) -> Unit raise PhysicalProgramVerificationError {
  let expected : LayoutRecipe = match self.image.object_shapes[shape.value] {
    Data(_) => Data(shape)
    Environment(_) => Environment(shape)
  }
  match state.layout_recipes[witness.value] {
    Some(actual) if actual == expected => ()
    Some(_) =>
      self.fail(site, "object layout witness references a different shape")
    None => self.fail(site, "object layout witness has no proven layout recipe")
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
fn PhysicalProgramVerifier::instruction_owner_token(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  destination : SlotId,
) -> OwnershipToken raise PhysicalProgramVerificationError {
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
    Some({ shape, member_index, }) =>
      "ObjectShapeId \{shape.value} member \{member_index}"
    None => "its root value"
  }
}

///|
fn PhysicalProgramVerifier::require_borrow_root_live(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  borrowed_slot : SlotId,
  provenance : BorrowProvenance,
) -> Unit raise PhysicalProgramVerificationError {
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
fn PhysicalProgramVerifier::require_new_owner_token_available(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  token : OwnershipToken,
) -> Unit raise PhysicalProgramVerificationError {
  if ownership_origin_is_live(state, token.origin) {
    self.fail(site, "owner definition is still live from an earlier iteration")
  }
}

///|
fn PhysicalProgramVerifier::read_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  slot : SlotId,
) -> SlotFlowState raise PhysicalProgramVerificationError {
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
fn PhysicalProgramVerifier::require_erased_companion_live(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  slot : SlotId,
) -> Unit raise PhysicalProgramVerificationError {
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
fn PhysicalProgramVerifier::write_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  value : SlotFlowState,
) -> Unit raise PhysicalProgramVerificationError {
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
  state.object_shapes[destination.value] = None
  state.layout_recipes[destination.value] = None
  state.tag_sources[destination.value] = None
}

///|
fn PhysicalProgramVerifier::write_from_metadata(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
) -> Unit raise PhysicalProgramVerificationError {
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
  state.object_shapes[destination.value] = statically_known_object_shape(
    self.image.object_shapes,
    body.slots[destination.value].kind,
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
  { roots, retained, members, }
}

///|
fn PhysicalProgramVerifier::write_transferred_owner(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  ownership : OwnershipProvenance,
) -> Unit raise PhysicalProgramVerificationError {
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
fn PhysicalProgramVerifier::transfer_aggregate_ownership(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  shape : ObjectShapeId,
  fields : Array[SlotId],
) -> Unit raise PhysicalProgramVerificationError {
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
      state.object_shapes[field.value] = None
      state.tag_sources[field.value] = None
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
        let projection = { shape, member_index: index, }
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
  state.object_shapes[destination.value] = Some(shape)
}

///|
fn PhysicalProgramVerifier::transfer_owner_into_new_value(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  source : SlotId,
) -> Unit raise PhysicalProgramVerificationError {
  guard self.read_flow(site, state, source) is LiveOwned(_, ownership) else {
    self.fail(site, "ownership transfer source is not a live owner")
  }
  state.slots[source.value] = Unavailable
  state.object_shapes[source.value] = None
  state.tag_sources[source.value] = None
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
fn PhysicalProgramVerifier::consume_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
) -> SlotFlowState raise PhysicalProgramVerificationError {
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
    state.object_shapes[source.value] = None
    state.tag_sources[source.value] = None
    for token in ownership.retained {
      invalidate_consumed_root_borrows(state, token)
    }
  }
  live
}

///|
fn PhysicalProgramVerifier::consume_owner(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
) -> Cleanup raise PhysicalProgramVerificationError {
  match self.consume_flow(site, body, state, source) {
    LiveOwned(cleanup, _) => cleanup
    _ => self.fail(site, "SlotId \{source.value} is not a live owner")
  }
}

///|
fn PhysicalProgramVerifier::write_trivial_after_reads(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  sources : Array[SlotId],
) -> Unit raise PhysicalProgramVerificationError {
  for source in sources {
    ignore(self.read_flow(site, state, source))
  }
  self.write_flow(site, body, state, destination, LiveTrivial)
}

///|
fn PhysicalProgramVerifier::apply_instruction_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  function : FunctionId,
  body : FunctionBody,
  state : FunctionFlowState,
  instruction : Instruction,
  global_dependencies : Array[Array[Bool]],
  global_lifecycle : GlobalLifecyclePlan,
) -> Unit raise PhysicalProgramVerificationError {
  match instruction {
    Copy(destination, source) => {
      let value = self.read_flow(site, state, source)
      let object_shape = state.object_shapes[source.value]
      let layout_recipe = state.layout_recipes[source.value]
      let tag_source = state.tag_sources[source.value]
      self.write_flow(site, body, state, destination, value)
      state.object_shapes[destination.value] = object_shape
      state.layout_recipes[destination.value] = layout_recipe
      state.tag_sources[destination.value] = tag_source
    }
    Move(destination, source) => {
      let value = self.read_flow(site, state, source)
      let object_shape = state.object_shapes[source.value]
      let layout_recipe = state.layout_recipes[source.value]
      let tag_source = state.tag_sources[source.value]
      match value {
        LiveBorrowed(_, _) =>
          self.fail(site, "borrowed SlotId \{source.value} cannot be moved")
        LiveOwned(_, _) if destination == source => ()
        LiveOwned(_, _) => {
          self.write_flow(site, body, state, destination, value)
          state.slots[source.value] = Unavailable
          state.object_shapes[source.value] = None
          state.layout_recipes[source.value] = None
          state.tag_sources[source.value] = None
        }
        _ => self.write_flow(site, body, state, destination, value)
      }
      state.object_shapes[destination.value] = object_shape
      state.layout_recipes[destination.value] = layout_recipe
      state.tag_sources[destination.value] = tag_source
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
      state.object_shapes[destination.value] = state.object_shapes[source.value]
      state.layout_recipes[destination.value] = state.layout_recipes[source.value]
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
    | ConstBool(destination, _) =>
      self.write_flow(site, body, state, destination, LiveTrivial)
    ConstLayout(destination, layout) => {
      self.write_flow(site, body, state, destination, LiveTrivial)
      state.layout_recipes[destination.value] = Some(
        self.layout_recipe(site, layout),
      )
    }
    ConstFunction(destination, _) | ConstString(destination, _) =>
      self.write_from_metadata(site, body, state, destination)
    CallDirect(target, environment, witnesses, arguments, destination) => {
      for witness in witnesses {
        ignore(self.consume_flow(site, body, state, witness))
      }
      self.require_global_dependencies(
        site,
        state,
        global_dependencies[target.value - 1],
        global_lifecycle,
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
    CallValue(callable, _, witnesses, arguments, destination) => {
      for witness in witnesses {
        ignore(self.consume_flow(site, body, state, witness))
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
        self.require_object_layout_witness(site, state, witness, shape)
      }
      for witness in witnesses {
        ignore(self.consume_flow(site, body, state, witness))
      }
      self.transfer_aggregate_ownership(
        site, body, state, destination, shape, fields,
      )
    }
    LoadTag(destination, source) => {
      self.write_trivial_after_reads(site, body, state, destination, [source])
      state.tag_sources[destination.value] = Some(source)
    }
    LoadObjectWitness(destination, shape, source, _) => {
      self.require_exact_object_shape(site, state, source, shape)
      self.write_trivial_after_reads(site, body, state, destination, [source])
    }
    BorrowField(shape, source, member_index, result) => {
      guard self.image.object_shapes[shape.value] is Data(data) else {
        self.fail(site, "BorrowField shape changed after static verification")
      }
      self.require_exact_object_shape(site, state, source, shape)
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
      self.require_exact_object_shape(site, state, source, shape)
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
      self.require_exact_object_shape(site, state, source, shape)
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
      self.require_exact_object_shape(site, state, source, shape)
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
          let object_shape = state.object_shapes[source.value]
          state.slots[source.value] = Unavailable
          state.object_shapes[source.value] = None
          state.layout_recipes[source.value] = None
          state.tag_sources[source.value] = None
          self.write_transferred_owner(
            site, body, state, destination, ownership,
          )
          state.object_shapes[destination.value] = object_shape
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
      let source_shape = state.object_shapes[source.value]
      if source_shape is Some(shape) &&
        !self.kind_accepts_object_shape(
          body.slots[destination.value].kind,
          shape,
        ) {
        self.fail(
          site,
          "unerasure destination does not accept proven ObjectShapeId \{shape.value}",
        )
      }
      state.slots[source.value] = Unavailable
      state.object_shapes[source.value] = None
      state.layout_recipes[source.value] = None
      state.tag_sources[source.value] = None
      self.write_transferred_owner(site, body, state, destination, ownership)
      state.object_shapes[destination.value] = match source_shape {
        Some(shape) => Some(shape)
        None =>
          statically_known_object_shape(
            self.image.object_shapes,
            body.slots[destination.value].kind,
          )
      }
    }
    EraseUnit(destination) =>
      self.write_from_metadata(site, body, state, destination)
    UneraseUnit(source) => ignore(self.consume_owner(site, body, state, source))
    InitGlobal(global, source) => {
      if self.image.initializer != Some(function) {
        self.fail(site, "InitGlobal appears outside the instance initializer")
      }
      self.initialize_global_flow(
        site, body, state, global, source, global_lifecycle,
      )
    }
    BorrowGlobal(destination, global) =>
      self.borrow_global_flow(
        site, body, state, destination, global, global_lifecycle,
      )
    unary_or_binary =>
      self.apply_trivial_instruction_flow(site, body, state, unary_or_binary)
  }
}

///|
fn PhysicalProgramVerifier::apply_trivial_instruction_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  instruction : Instruction,
) -> Unit raise PhysicalProgramVerificationError {
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
    WasiFdWrite(destination, left, right)
    | ByteSequenceEqual(destination, left, right)
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
fn PhysicalProgramVerifier::require_exact_object_shape(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  source : SlotId,
  expected : ObjectShapeId,
) -> Unit raise PhysicalProgramVerificationError {
  ignore(self.read_flow(site, state, source))
  match state.object_shapes[source.value] {
    Some(actual) if actual == expected => ()
    Some(actual) =>
      self.fail(
        site,
        "SlotId \{source.value} has ObjectShapeId \{actual.value}, expected ObjectShapeId \{expected.value}",
      )
    None =>
      self.fail(
        site,
        "SlotId \{source.value} has no proven ObjectShapeId \{expected.value}",
      )
  }
}

///|
fn PhysicalProgramVerifier::write_borrowed_projection(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
  shape : ObjectShapeId,
  member_index : Int,
  schema : MemberSchema,
  result : ProjectionResult,
) -> Unit raise PhysicalProgramVerificationError {
  if result.witness_destination is Some(witness) {
    self.write_flow(site, body, state, witness, LiveTrivial)
  }
  let value = match schema.cleanup {
    Trivial => SlotFlowState::LiveTrivial
    cleanup => {
      let provenance = match self.read_flow(site, state, source) {
        LiveOwned(OwnedRef, ownership) => {
          let projection = { shape, member_index, }
          let roots = ownership_after_projection(ownership, projection).roots
          { root: LocalRoots(roots), projections: [], }
        }
        LiveBorrowed(OwnedRef, provenance) =>
          { ..provenance, projections: provenance.projections.copy(), }
        _ =>
          self.fail(
            site, "borrowed projection source is not a live object reference",
          )
      }
      provenance.projections.push({ shape, member_index, })
      LiveBorrowed(cleanup, provenance)
    }
  }
  self.write_flow(site, body, state, result.value_destination, value)
  state.object_shapes[result.value_destination.value] = statically_known_object_shape(
    self.image.object_shapes,
    schema.kind,
  )
}

///|
fn PhysicalProgramVerifier::write_consumed_projections(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  source : SlotId,
  shape : ObjectShapeId,
  selections : Array[ProjectionSelection],
) -> Unit raise PhysicalProgramVerificationError {
  guard self.read_flow(site, state, source) is LiveOwned(_, ownership) else {
    self.fail(site, "consuming projection source is not a live owner")
  }
  state.slots[source.value] = Unavailable
  state.object_shapes[source.value] = None
  state.tag_sources[source.value] = None
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
    state.object_shapes[selection.result.value_destination.value] = statically_known_object_shape(
      self.image.object_shapes,
      body.slots[selection.result.value_destination.value].kind,
    )
  }
  for token in ownership.retained {
    invalidate_consumed_root_borrows(state, token)
  }
}

///|
fn PhysicalProgramVerifier::initialize_global_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  global : GlobalId,
  source : SlotId,
  global_lifecycle : GlobalLifecyclePlan,
) -> Unit raise PhysicalProgramVerificationError {
  if state.initialized_global_prefix >= global_lifecycle.roots.length() {
    self.fail(site, "GlobalId \{global.value} is initialized twice")
  }
  let expected = global_lifecycle.roots[state.initialized_global_prefix]
  if expected.global != global {
    if global_lifecycle.root_ordinals[global.value] <
      state.initialized_global_prefix {
      self.fail(site, "GlobalId \{global.value} is initialized twice")
    }
    self.fail(
      site,
      "GlobalId \{global.value} is out of initialization order; expected GlobalId \{expected.global.value}",
    )
  }
  ignore(self.consume_flow(site, body, state, source))
  if expected.companion is Some(_) {
    guard body.slots[source.value].erased_companion is Some(source_companion) else {
      self.fail(site, "OwnedErased source lacks a companion")
    }
    ignore(self.read_flow(site, state, source_companion))
  }
  state.initialized_global_prefix += 1
}

///|
fn PhysicalProgramVerifier::borrow_global_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  destination : SlotId,
  global : GlobalId,
  global_lifecycle : GlobalLifecyclePlan,
) -> Unit raise PhysicalProgramVerificationError {
  if global_lifecycle.root_ordinals[global.value] >=
    state.initialized_global_prefix {
    self.fail(site, "read from uninitialized GlobalId \{global.value}")
  }
  let metadata = self.image.globals[global.value]
  if metadata.erased_companion is Some(_) {
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
        LiveBorrowed(cleanup, { root: GlobalRoot(global), projections: [], })
    },
  )
  state.object_shapes[destination.value] = statically_known_object_shape(
    self.image.object_shapes,
    body.slots[destination.value].kind,
  )
}

///|
fn PhysicalProgramVerifier::require_global_dependencies(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  dependencies : Array[Bool],
  global_lifecycle : GlobalLifecyclePlan,
) -> Unit raise PhysicalProgramVerificationError {
  for index, required in dependencies {
    if required &&
      global_lifecycle.root_ordinals[index] >= state.initialized_global_prefix {
      self.fail(site, "call may read uninitialized GlobalId \{index}")
    }
  }
}

///|
fn PhysicalProgramVerifier::require_initializer_globals_complete(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
  global_lifecycle : GlobalLifecyclePlan,
) -> Unit raise PhysicalProgramVerificationError {
  if state.initialized_global_prefix != global_lifecycle.roots.length() {
    let expected = global_lifecycle.roots[state.initialized_global_prefix]
    self.fail(
      site,
      "initializer leaves GlobalId \{expected.global.value} uninitialized",
    )
  }
}

///|
fn PhysicalProgramVerifier::apply_terminator_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  function : FunctionId,
  body : FunctionBody,
  state : FunctionFlowState,
  terminator : Terminator,
  global_dependencies : Array[Array[Bool]],
  global_lifecycle : GlobalLifecyclePlan,
  is_initializer~ : Bool,
) -> Array[(Int, FunctionFlowState)] raise PhysicalProgramVerificationError {
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
      let successors = []
      for constructor_tag, edge in cases {
        let case_state = state.copy()
        if case_state.tag_sources[tag.value] is Some(source) {
          self.refine_data_shape(case_state, body, source, constructor_tag)
        }
        successors.push(self.transfer_edge_flow(site, body, case_state, edge))
      }
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
        self.require_initializer_globals_complete(site, state, global_lifecycle)
      }
      []
    }
    TailCallDirect(target, environment, witnesses, arguments) => {
      for witness in witnesses {
        ignore(self.consume_flow(site, body, state, witness))
      }
      self.require_global_dependencies(
        site,
        state,
        global_dependencies[target.value - 1],
        global_lifecycle,
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
    TailCallValue(callable, _, witnesses, arguments) => {
      for witness in witnesses {
        ignore(self.consume_flow(site, body, state, witness))
      }
      ignore(self.consume_owner(site, body, state, callable))
      for argument in arguments {
        ignore(self.consume_flow(site, body, state, argument))
      }
      self.require_no_live_owners(site, state)
      []
    }
    Fatal(message) => {
      ignore(self.consume_owner(site, body, state, message))
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
fn PhysicalProgramVerifier::refine_data_shape(
  self : PhysicalProgramVerifier,
  state : FunctionFlowState,
  body : FunctionBody,
  source : SlotId,
  constructor_tag : Int,
) -> Unit {
  guard body.slots[source.value].kind is DataValue(family) else { return }
  for index, shape in self.image.object_shapes {
    if shape is Data({ family: actual_family, constructor_tag: actual_tag, .. }) &&
      actual_family == family &&
      actual_tag == constructor_tag {
      state.object_shapes[source.value] = Some({ value: index, })
      return
    }
  }
}

///|
fn PhysicalProgramVerifier::transfer_edge_flow(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  state : FunctionFlowState,
  edge : Edge,
) -> (Int, FunctionFlowState) raise PhysicalProgramVerificationError {
  let target = body.blocks[edge.target.value]
  let values = edge.arguments.map(argument => {
    self.read_flow(site, state, argument)
  })
  let object_shapes = edge.arguments.map(argument => {
    state.object_shapes[argument.value]
  })
  let layout_recipes = edge.arguments.map(argument => {
    state.layout_recipes[argument.value]
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
      state.object_shapes[argument.value] = None
      state.layout_recipes[argument.value] = None
      state.tag_sources[argument.value] = None
    }
  }
  for index in 0..<values.length() {
    self.write_flow(site, body, state, target.parameters[index], values[index])
    state.object_shapes[target.parameters[index].value] = object_shapes[index]
    state.layout_recipes[target.parameters[index].value] = layout_recipes[index]
  }
  (edge.target.value, state)
}

///|
fn PhysicalProgramVerifier::require_no_live_owners(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  state : FunctionFlowState,
) -> Unit raise PhysicalProgramVerificationError {
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
