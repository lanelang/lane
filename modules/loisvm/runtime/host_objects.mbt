///|
fn[A, B] unchecked_host_cast(_value : A) -> B = "%identity"

///|
priv struct ErasedHostPayload {
  value : Ref[Unit]
}

///|
fn[T] erase_host_payload(value : T) -> ErasedHostPayload {
  { value: unchecked_host_cast(Ref(value)) }
}

///|
fn[T] project_host_payload(payload : ErasedHostPayload) -> T {
  let typed : Ref[T] = unchecked_host_cast(payload.value)
  typed.val
}

///|
struct BorrowedHostObject {
  payload : ErasedHostPayload
}

///|
pub fn[T] BorrowedHostObject::project(self : BorrowedHostObject) -> T {
  project_host_payload(self.payload)
}

///|
pub impl Debug for BorrowedHostObject with fn to_repr(
  _self : BorrowedHostObject,
) -> Repr {
  Repr::ctor("BorrowedHostObject", [])
}

///|
struct OwnedHostObject {
  mut payload : ErasedHostPayload?
  mut finalizer : ((ErasedHostPayload) -> Unit)?
}

///|
pub fn[T] OwnedHostObject::new(
  payload : T,
  finalizer~ : (T) -> Unit,
) -> OwnedHostObject {
  {
    payload: Some(erase_host_payload(payload)),
    finalizer: Some(erased => finalizer(project_host_payload(erased))),
  }
}

///|
fn OwnedHostObject::take(
  self : OwnedHostObject,
) -> (ErasedHostPayload, (ErasedHostPayload) -> Unit) raise HostObjectFailure {
  guard self.payload is Some(payload) && self.finalizer is Some(finalizer) else {
    raise InvalidOwnedResult(detail="owned Host Object was already adopted")
  }
  self.payload = None
  self.finalizer = None
  (payload, finalizer)
}

///|
pub impl Debug for OwnedHostObject with fn to_repr(self : OwnedHostObject) -> Repr {
  Repr::ctor("OwnedHostObject", [
    (
      Some("state"),
      Repr::string(if self.payload is Some(_) { "pending" } else { "adopted" }),
    ),
  ])
}

///|
priv struct HostObjectIdentity {
  nonce : Ref[Unit]
}

///|
struct HostObjectHandle {
  identity : HostObjectIdentity
  slot : Int
  generation : Int
}

///|
pub impl Debug for HostObjectHandle with fn to_repr(self : HostObjectHandle) -> Repr {
  Repr::record({
    "slot": Repr::integer(self.slot.to_string()),
    "generation": Repr::integer(self.generation.to_string()),
  })
}

///|
priv struct HostObjectEntry {
  payload : ErasedHostPayload
  finalizer : (ErasedHostPayload) -> Unit
}

///|
priv struct HostObjectSlot {
  mut generation : Int
  mut entry : HostObjectEntry?
}

///|
priv struct HostObjectTable {
  identity : HostObjectIdentity
  slots : Array[HostObjectSlot]
  max_live_objects : Int?
  mut live_objects : Int
}

///|
fn HostObjectTable::new(max_live_objects : Int?) -> HostObjectTable {
  {
    identity: { nonce: Ref(()) },
    slots: [],
    max_live_objects: match max_live_objects {
      None => None
      Some(value) => Some(if value > 0 { value } else { 0 })
    },
    live_objects: 0,
  }
}

///|
fn HostObjectTable::has_capacity(self : HostObjectTable) -> Bool {
  match self.max_live_objects {
    None => true
    Some(maximum) => self.live_objects < maximum
  }
}

///|
fn HostObjectTable::insert(
  self : HostObjectTable,
  payload : ErasedHostPayload,
  finalizer : (ErasedHostPayload) -> Unit,
) -> HostObjectHandle raise HostObjectFailure {
  if !self.has_capacity() {
    raise HostObjectLimitExceeded
  }
  for index, slot in self.slots {
    if slot.entry is None {
      slot.entry = Some({ payload, finalizer })
      self.live_objects += 1
      return {
        identity: self.identity,
        slot: index,
        generation: slot.generation,
      }
    }
  }
  let slot = { generation: 1, entry: Some({ payload, finalizer }) }
  self.slots.push(slot)
  self.live_objects += 1
  {
    identity: self.identity,
    slot: self.slots.length() - 1,
    generation: slot.generation,
  }
}

///|
fn HostObjectTable::entry(
  self : HostObjectTable,
  handle : HostObjectHandle,
) -> HostObjectEntry raise HostObjectFailure {
  if !physical_equal(self.identity.nonce, handle.identity.nonce) {
    raise InvalidHostObjectHandle(detail="handle belongs to another execution")
  }
  if handle.slot < 0 || handle.slot >= self.slots.length() {
    raise InvalidHostObjectHandle(detail="handle slot is out of range")
  }
  let slot = self.slots[handle.slot]
  if slot.generation != handle.generation {
    raise InvalidHostObjectHandle(detail="handle generation is stale")
  }
  match slot.entry {
    Some(entry) => entry
    None => raise InvalidHostObjectHandle(detail="handle refers to a free slot")
  }
}

///|
fn HostObjectTable::release(
  self : HostObjectTable,
  handle : HostObjectHandle,
) -> Unit raise HostObjectFailure {
  let entry = self.entry(handle)
  let slot = self.slots[handle.slot]
  slot.entry = None
  slot.generation += 1
  self.live_objects -= 1
  (entry.finalizer)(entry.payload)
}

///|
pub(all) suberror HostObjectFailure {
  HostObjectLimitExceeded
  InvalidHostObjectHandle(detail~ : String)
  InvalidOwnedResult(detail~ : String)
} derive(Debug, Eq)

///|
pub fn ExecutionRuntime::live_host_objects(self : ExecutionRuntime) -> Int {
  self.context.state.host_objects.live_objects
}

///|
pub fn ExecutionRuntime::resolve_host_object(
  self : ExecutionRuntime,
  handle : HostObjectHandle,
) -> BorrowedHostObject raise HostObjectFailure {
  { payload: self.context.state.host_objects.entry(handle).payload }
}

///|
pub fn ExecutionRuntime::release_host_object(
  self : ExecutionRuntime,
  handle : HostObjectHandle,
) -> Unit raise HostObjectFailure {
  self.context.state.host_objects.release(handle)
}

///|
pub fn[R, E] ExecutionRuntime::adopt_host_object(
  self : ExecutionRuntime,
  object : OwnedHostObject,
  initialize : (HostObjectHandle) -> Result[R, E],
) -> Result[R, E] raise HostObjectFailure {
  let (payload, finalizer) = object.take()
  let handle = self.context.state.host_objects.insert(payload, finalizer) catch {
    HostObjectLimitExceeded => {
      finalizer(payload)
      raise HostObjectLimitExceeded
    }
    error => raise error
  }
  match initialize(handle) {
    Ok(result) => Ok(result)
    Err(error) => {
      self.context.state.host_objects.release(handle)
      Err(error)
    }
  }
}
