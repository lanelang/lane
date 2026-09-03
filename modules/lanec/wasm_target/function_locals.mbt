///|
priv struct FunctionLocalPlan {
  locals : Array[@wasm_types.ValueType]
  slot_locals : Array[Int]
  slot_local_count : Int
  control_local_count : Int
  transfer_locals : Array[Array[Int]]
  dispatcher_local : Int?
}

///|
fn plan_function_locals(
  body : @physical.FunctionBody,
  parameter_count : Int,
  uses_cfg : Bool,
  use_dispatcher : Bool,
) -> FunctionLocalPlan {
  let locals : Array[@wasm_types.ValueType] = []
  let slot_locals = Array::make(body.slots.length(), -1)
  let mut parameter_index = 1
  if body.inputs.environment is Some(slot) {
    slot_locals[slot.value] = 0
  }
  for slot in body.inputs.witnesses {
    slot_locals[slot.value] = parameter_index
    parameter_index += 1
  }
  for slot in body.inputs.user_parameters {
    slot_locals[slot.value] = parameter_index
    parameter_index += 1
  }
  for slot_index, slot in body.slots {
    if slot_locals[slot_index] < 0 {
      slot_locals[slot_index] = parameter_count + locals.length()
      locals.push(wasm_representation(slot.representation))
    }
  }
  let slot_local_count = locals.length()
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
  {
    locals,
    slot_locals,
    slot_local_count,
    control_local_count: i32_pool.length() +
    i64_pool.length() +
    f32_pool.length() +
    f64_pool.length() +
    (if dispatcher_local is Some(_) { 1 } else { 0 }),
    transfer_locals,
    dispatcher_local,
  }
}

///|
fn FunctionLocalPlan::slot_local(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Int {
  self.slot_locals[slot.value]
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
