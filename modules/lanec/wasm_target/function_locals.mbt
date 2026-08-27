///|
priv struct FunctionLocalPlan {
  parameter_count : Int
  locals : Array[@wasm_types.ValueType]
  slot_local_count : Int
  control_local_count : Int
  arc_local_count : Int
  transfer_locals : Array[Array[Int]]
  dispatcher_local : Int?
  slot_cleanups : Array[@physical.Cleanup]
  erased_liveness_locals : Array[Int]
}

///|
fn plan_function_locals(
  body : @physical.FunctionBody,
  parameter_count : Int,
  uses_cfg : Bool,
  use_dispatcher : Bool,
) -> FunctionLocalPlan {
  let locals = body.slots.map(fn(slot) {
    wasm_representation(slot.representation)
  })
  let transfer_locals = body.blocks.map(_ => [])
  let i32_pool : Array[Int] = []
  let i64_pool : Array[Int] = []
  let f32_pool : Array[Int] = []
  let f64_pool : Array[Int] = []
  if uses_cfg {
    for block_index, block in body.blocks {
      let mut i32_count = 0
      let mut i64_count = 0
      let mut f32_count = 0
      let mut f64_count = 0
      for parameter in block.parameters {
        let representation = body.slots[parameter.value].representation
        let (pool, ordinal) = match representation {
          I32 => {
            let ordinal = i32_count
            i32_count += 1
            (i32_pool, ordinal)
          }
          I64 => {
            let ordinal = i64_count
            i64_count += 1
            (i64_pool, ordinal)
          }
          F32 => {
            let ordinal = f32_count
            f32_count += 1
            (f32_pool, ordinal)
          }
          F64 => {
            let ordinal = f64_count
            f64_count += 1
            (f64_pool, ordinal)
          }
        }
        if ordinal == pool.length() {
          pool.push(parameter_count + locals.length())
          locals.push(wasm_representation(representation))
        }
        transfer_locals[block_index].push(pool[ordinal])
      }
    }
  }
  let dispatcher_local = if use_dispatcher {
    let local_index = parameter_count + locals.length()
    locals.push(I32)
    Some(local_index)
  } else {
    None
  }
  let erased_liveness_locals = Array::make(body.slots.length(), -1)
  let mut erased_owned_count = 0
  for index, slot in body.slots {
    if slot.cleanup is OwnedErased {
      erased_liveness_locals[index] = parameter_count + locals.length()
      locals.push(I32)
      erased_owned_count += 1
    }
  }
  {
    parameter_count,
    locals,
    slot_local_count: body.slots.length(),
    control_local_count: i32_pool.length() +
    i64_pool.length() +
    f32_pool.length() +
    f64_pool.length() +
    (if dispatcher_local is Some(_) { 1 } else { 0 }),
    arc_local_count: erased_owned_count,
    transfer_locals,
    dispatcher_local,
    slot_cleanups: body.slots.map(slot => slot.cleanup),
    erased_liveness_locals,
  }
}

///|
fn FunctionLocalPlan::slot_local(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Int {
  self.parameter_count + slot.value
}

///|
fn FunctionLocalPlan::transfer_local(
  self : FunctionLocalPlan,
  block : @physical.BlockId,
  parameter_index : Int,
) -> Int {
  self.transfer_locals[block.value][parameter_index]
}

///|
fn FunctionLocalPlan::dispatcher_state_local(self : FunctionLocalPlan) -> Int {
  self.dispatcher_local.unwrap()
}

///|
fn FunctionLocalPlan::erased_liveness_local(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Int {
  self.erased_liveness_locals[slot.value]
}

///|
fn FunctionLocalPlan::mark_slot_live(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  match self.slot_cleanups[slot.value] {
    Trivial | OwnedRef | OwnedCallable => []
    OwnedErased => [I32Const(1), LocalSet(self.erased_liveness_local(slot))]
  }
}

///|
fn FunctionLocalPlan::mark_slot_dead(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  match self.slot_cleanups[slot.value] {
    Trivial => []
    OwnedRef => [I32Const(0), LocalSet(self.slot_local(slot))]
    OwnedCallable => [I64Const(0L), LocalSet(self.slot_local(slot))]
    OwnedErased => [I32Const(0), LocalSet(self.erased_liveness_local(slot))]
  }
}

///|
fn FunctionLocalPlan::mark_slot_dead_after_definition(
  self : FunctionLocalPlan,
  source : @physical.SlotId,
  destination : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  if source == destination {
    []
  } else {
    self.mark_slot_dead(source)
  }
}

///|
fn FunctionLocalPlan::test_slot_live(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  match self.slot_cleanups[slot.value] {
    Trivial => abort("trivial slot does not require a liveness test")
    OwnedRef => [LocalGet(self.slot_local(slot))]
    OwnedCallable => [LocalGet(self.slot_local(slot)), I64Eqz, I32Eqz]
    OwnedErased => [LocalGet(self.erased_liveness_local(slot))]
  }
}
