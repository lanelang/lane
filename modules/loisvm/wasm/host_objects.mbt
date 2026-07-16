///|
priv suberror WasmHostObjectFailure {
  InvalidHostObjectToken(detail~ : String)
  HostObjectRuntimeFailure(detail~ : String)
}

///|
priv struct WasmHostObjectSlot {
  mut generation : Int
  mut handle : @loisvm_runtime.HostObjectHandle?
}

///|
priv struct WasmHostObjects {
  runtime : @loisvm_runtime.ExecutionRuntime
  slots : Array[WasmHostObjectSlot]
}

///|
fn WasmHostObjects::new(
  runtime : @loisvm_runtime.ExecutionRuntime,
) -> WasmHostObjects {
  { runtime, slots: [] }
}

///|
fn host_object_token(slot : Int, generation : Int) -> Int64 {
  (generation.to_int64() << 32) | (slot + 1).to_int64()
}

///|
fn WasmHostObjects::insert(
  self : WasmHostObjects,
  handle : @loisvm_runtime.HostObjectHandle,
) -> Int64 {
  for index, slot in self.slots {
    if slot.handle is None {
      slot.handle = Some(handle)
      return host_object_token(index, slot.generation)
    }
  }
  self.slots.push({ generation: 1, handle: Some(handle) })
  host_object_token(self.slots.length() - 1, 1)
}

///|
fn WasmHostObjects::slot(
  self : WasmHostObjects,
  token : Int64,
) -> WasmHostObjectSlot raise WasmHostObjectFailure {
  let encoded_slot = token & 0xFFFFFFFFL
  if encoded_slot == 0L {
    raise InvalidHostObjectToken(detail="Host Object token has a zero slot")
  }
  let index = encoded_slot.to_int() - 1
  if index < 0 || index >= self.slots.length() {
    raise InvalidHostObjectToken(
      detail="Host Object token slot is out of range",
    )
  }
  let slot = self.slots[index]
  let generation = (token >> 32).to_int()
  if generation <= 0 || slot.generation != generation {
    raise InvalidHostObjectToken(detail="Host Object token generation is stale")
  }
  if slot.handle is None {
    raise InvalidHostObjectToken(
      detail="Host Object token refers to a free slot",
    )
  }
  slot
}

///|
fn WasmHostObjects::handle(
  self : WasmHostObjects,
  token : Int64,
) -> @loisvm_runtime.HostObjectHandle raise WasmHostObjectFailure {
  match self.slot(token).handle {
    Some(handle) => handle
    None => abort("validated Host Object token has no handle")
  }
}

///|
fn WasmHostObjects::borrow(
  self : WasmHostObjects,
  token : Int64,
) -> @loisvm_runtime.BorrowedHostObject raise WasmHostObjectFailure {
  self.runtime.resolve_host_object(self.handle(token)) catch {
    @loisvm_runtime.HostObjectFailure::InvalidHostObjectHandle(detail~) =>
      raise HostObjectRuntimeFailure(detail~)
    _ =>
      raise HostObjectRuntimeFailure(
        detail="unexpected Host Object resolution failure",
      )
  }
}

///|
fn WasmHostObjects::remove(
  self : WasmHostObjects,
  token : Int64,
) -> @loisvm_runtime.HostObjectHandle raise WasmHostObjectFailure {
  let slot = self.slot(token)
  let handle = match slot.handle {
    Some(handle) => handle
    None => abort("validated Host Object token has no handle")
  }
  slot.handle = None
  slot.generation += 1
  handle
}

///|
fn WasmHostObjects::rollback(
  self : WasmHostObjects,
  token : Int64,
) -> Unit raise WasmHostObjectFailure {
  ignore(self.remove(token))
}

///|
fn WasmHostObjects::release(
  self : WasmHostObjects,
  token : Int64,
) -> Unit raise WasmHostObjectFailure {
  let handle = self.remove(token)
  self.runtime.release_host_object(handle) catch {
    InvalidHostObjectHandle(detail~) => raise HostObjectRuntimeFailure(detail~)
    _ =>
      raise HostObjectRuntimeFailure(
        detail="unexpected Host Object release failure",
      )
  }
}
