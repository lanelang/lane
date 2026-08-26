///|
priv struct PhysicalSlotPlan {
  arc_final : ArcFinalBody
  slots : Array[@physical.SlotMetadata]
  values : Array[@physical.SlotId?]
}

///|
fn allocate_physical_slots(
  arc_final : ArcFinalBody,
) -> PhysicalSlotPlan raise FinalizeError {
  let body = arc_final.body
  let value_count = body.values.length()
  let active = Array::make(value_count, false)
  let use_def = arc_final.use_def
  for value_index in 0..<value_count {
    active[value_index] = use_def.definitions[value_index] is Some(_) ||
      use_def.use_count({ value: value_index, }) > 0
  }
  for value_index, metadata in body.values {
    if active[value_index] && metadata.erased_companion is Some(companion) {
      active[companion.value] = true
    }
  }
  let control_flow = analyze_control_flow(body.blocks)
  let liveness = analyze_liveness(body, control_flow, use_def)
  let interference = body.values.map(_ => Array::make(value_count, false))
  for block_index, block in body.blocks {
    let live = liveness.live_out[block_index].copy()
    for source in use_def.terminator_uses(block_index) {
      live[source.value] = true
    }
    let mut instruction_index = block.instructions.length() - 1
    while instruction_index >= 0 {
      let destinations = use_def.instruction_definitions(
        block_index, instruction_index,
      )
      let sources = use_def.instruction_uses(block_index, instruction_index)
      for destination in destinations {
        record_physical_interference(interference, destination.value, live)
        for source in sources {
          if destination != source {
            interference[destination.value][source.value] = true
            interference[source.value][destination.value] = true
          }
        }
      }
      for destination in destinations {
        live[destination.value] = false
      }
      for source in sources {
        live[source.value] = true
      }
      instruction_index -= 1
    }
    let entry_definitions = if block_index == 0 {
      block.parameters + function_input_values(body.inputs)
    } else {
      block.parameters
    }
    for definition in entry_definitions {
      record_physical_interference(interference, definition.value, live)
    }
    record_simultaneous_definitions(interference, entry_definitions)
  }
  for owner, metadata in body.values {
    if active[owner] && metadata.erased_companion is Some(companion) {
      for other in 0..<value_count {
        if interference[owner][other] {
          interference[companion.value][other] = true
          interference[other][companion.value] = true
        }
      }
    }
  }
  let values : Array[@physical.SlotId?] = Array::make(value_count, None)
  let slots : Array[@physical.SlotMetadata] = []
  let slot_values : Array[Array[Int]] = []
  for value_index in 0..<value_count {
    if !active[value_index] {
      continue
    }
    let metadata = value_metadata_to_slot(body.values[value_index])
    let reusable = !(metadata.cleanup is OwnedErased) &&
      metadata.erased_companion is None
    let mut slot_index = -1
    if reusable {
      for candidate, candidate_metadata in slots {
        if candidate_metadata == metadata &&
          slot_values[candidate].all(fn(other) {
            !interference[value_index][other]
          }) {
          slot_index = candidate
          break
        }
      }
    }
    if slot_index < 0 {
      slot_index = slots.length()
      slots.push(metadata)
      slot_values.push([])
    }
    slot_values[slot_index].push(value_index)
    values[value_index] = Some({ value: slot_index, })
  }
  let plan = PhysicalSlotPlan::{
    arc_final,
    values,
    slots: slots.map(metadata => {
      ..metadata,
      erased_companion: metadata.erased_companion.map(companion => {
        planned_slot(values, { value: companion.value, })
      }),
    }),
  }
  validate_physical_slot_plan(body, use_def, plan, active, interference)
  plan
}

///|
fn validate_physical_slot_plan(
  body : FunctionBody,
  use_def : UseDefAnalysis,
  plan : PhysicalSlotPlan,
  active : Array[Bool],
  interference : Array[Array[Bool]],
) -> Unit raise FinalizeError {
  for value in function_input_values(body.inputs) {
    ignore(plan.slot(value))
  }
  for block_index, block in body.blocks {
    for value in block.parameters {
      ignore(plan.slot(value))
    }
    for instruction_index, _ in block.instructions {
      for
        value in use_def.instruction_definitions(block_index, instruction_index) {
        ignore(plan.slot(value))
      }
      for value in use_def.instruction_uses(block_index, instruction_index) {
        ignore(plan.slot(value))
      }
    }
    for value in use_def.terminator_uses(block_index) {
      ignore(plan.slot(value))
    }
  }
  for value_index in 0..<body.values.length() {
    if !active[value_index] {
      continue
    }
    let value : ValueId = { value: value_index, }
    let slot = plan.slot(value)
    let logical_metadata = value_metadata_to_slot(body.values[value_index])
    let expected_metadata : @physical.SlotMetadata = {
      ..logical_metadata,
      erased_companion: logical_metadata.erased_companion.map(companion => {
        planned_slot(plan.values, { value: companion.value, })
      }),
    }
    if plan.slots[slot.value] != expected_metadata {
      raise PhysicalSlotAllocationCompilerDefect(MetadataMismatch(value, slot))
    }
    for other_index in (value_index + 1)..<body.values.length() {
      if active[other_index] &&
        interference[value_index][other_index] &&
        plan.slot({ value: other_index, }) == slot {
        raise PhysicalSlotAllocationCompilerDefect(
          InterferenceConflict(value, { value: other_index, }, slot),
        )
      }
    }
  }
}

///|
fn PhysicalSlotPlan::slot(
  self : PhysicalSlotPlan,
  value : ValueId,
) -> @physical.SlotId raise FinalizeError {
  planned_slot(self.values, value)
}

///|
fn PhysicalSlotPlan::metadata(
  self : PhysicalSlotPlan,
  value : ValueId,
) -> @physical.SlotMetadata raise FinalizeError {
  self.slots[self.slot(value).value]
}

///|
fn planned_slot(
  values : Array[@physical.SlotId?],
  value : ValueId,
) -> @physical.SlotId raise FinalizeError {
  match values.get(value.value) {
    Some(Some(slot)) => slot
    _ => raise PhysicalSlotAllocationCompilerDefect(MissingAssignment(value))
  }
}

///|
fn function_input_values(inputs : FunctionInputs) -> Array[ValueId] {
  let values = []
  if inputs.environment is Some(environment) {
    values.push(environment)
  }
  values.append(inputs.witnesses)
  values.append(inputs.user_parameters)
  values
}

///|
fn record_physical_interference(
  interference : Array[Array[Bool]],
  definition : Int,
  live : Array[Bool],
) -> Unit {
  for other, is_live in live {
    if is_live && other != definition {
      interference[definition][other] = true
      interference[other][definition] = true
    }
  }
}

///|
fn record_simultaneous_definitions(
  interference : Array[Array[Bool]],
  definitions : Array[ValueId],
) -> Unit {
  for left_index in 0..<definitions.length() {
    for right_index in (left_index + 1)..<definitions.length() {
      let left = definitions[left_index].value
      let right = definitions[right_index].value
      if left != right {
        interference[left][right] = true
        interference[right][left] = true
      }
    }
  }
}
