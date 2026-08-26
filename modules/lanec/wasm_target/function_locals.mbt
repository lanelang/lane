///|
priv struct FunctionLocalPlan {
  parameter_count : Int
  locals : Array[@wasm_types.ValueType]
  transfer_locals : Array[Array[Int]]
  dispatcher_local : Int?
  liveness_locals : Array[Int]
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
  let liveness_locals = Array::make(body.slots.length(), -1)
  for index, slot in body.slots {
    if !(slot.cleanup is Trivial) {
      liveness_locals[index] = parameter_count + locals.length()
      locals.push(I32)
    }
  }
  {
    parameter_count,
    locals,
    transfer_locals,
    dispatcher_local,
    liveness_locals,
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
fn FunctionLocalPlan::liveness_local(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Int? {
  let local_index = self.liveness_locals[slot.value]
  if local_index < 0 {
    None
  } else {
    Some(local_index)
  }
}

///|
fn FunctionLocalPlan::mark_slot_live(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  match self.liveness_local(slot) {
    None => []
    Some(local_index) => [I32Const(1), LocalSet(local_index)]
  }
}

///|
fn FunctionLocalPlan::mark_slot_dead(
  self : FunctionLocalPlan,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  match self.liveness_local(slot) {
    None => []
    Some(local_index) => [I32Const(0), LocalSet(local_index)]
  }
}
