///|
priv struct HostObjectStoreIdentity {
  nonce : Ref[Unit]
}

///|
priv struct HostObjectStoreKey {
  slot : Int
  generation : Int
}

///|
priv struct HostObjectStoreEntry[T] {
  value : T
  finalizer : (T) -> Unit
}

///|
priv struct HostObjectStoreSlot[T] {
  mut generation : Int
  mut entry : HostObjectStoreEntry[T]?
}

///|
struct HostObjectStore[T] {
  identity : HostObjectStoreIdentity
  slots : Array[HostObjectStoreSlot[T]]
}

///|
pub fn[T] HostObjectStore::new() -> HostObjectStore[T] {
  { identity: { nonce: Ref(()) }, slots: [] }
}

///|
struct BorrowedHostObject {
  store_identity : HostObjectStoreIdentity
  key : HostObjectStoreKey
}

///|
fn[T] HostObjectStore::insert(
  self : HostObjectStore[T],
  value : T,
  finalizer : (T) -> Unit,
) -> BorrowedHostObject {
  for index, slot in self.slots {
    if slot.entry is None {
      slot.entry = Some({ value, finalizer })
      return {
        store_identity: self.identity,
        key: { slot: index, generation: slot.generation },
      }
    }
  }
  let slot : HostObjectStoreSlot[T] = {
    generation: 1,
    entry: Some({ value, finalizer }),
  }
  self.slots.push(slot)
  {
    store_identity: self.identity,
    key: { slot: self.slots.length() - 1, generation: slot.generation },
  }
}

///|
fn[T] HostObjectStore::entry(
  self : HostObjectStore[T],
  object : BorrowedHostObject,
) -> HostObjectStoreEntry[T] {
  if !physical_equal(self.identity.nonce, object.store_identity.nonce) {
    abort("Host Object belongs to a different typed store")
  }
  let key = object.key
  if key.slot < 0 || key.slot >= self.slots.length() {
    abort("Host Object store slot is out of range")
  }
  let slot = self.slots[key.slot]
  if slot.generation != key.generation {
    abort("Host Object store generation is stale")
  }
  match slot.entry {
    Some(entry) => entry
    None => abort("Host Object store slot is empty")
  }
}

///|
pub fn[T] HostObjectStore::project(
  self : HostObjectStore[T],
  object : BorrowedHostObject,
) -> T {
  self.entry(object).value
}

///|
fn[T] HostObjectStore::release(
  self : HostObjectStore[T],
  object : BorrowedHostObject,
) -> Unit {
  let entry = self.entry(object)
  let slot = self.slots[object.key.slot]
  slot.entry = None
  slot.generation += 1
  (entry.finalizer)(entry.value)
}

///|
pub impl Debug for BorrowedHostObject with fn to_repr(
  _self : BorrowedHostObject,
) -> Repr {
  Repr::ctor("BorrowedHostObject", [])
}

///|
struct OwnedHostObject {
  mut materialize : (() -> HostObjectEntry)?
  mut discard : (() -> Unit)?
}

///|
pub fn[T] OwnedHostObject::new(
  store : HostObjectStore[T],
  value : T,
  finalizer~ : (T) -> Unit,
) -> OwnedHostObject {
  let pending = Ref(Some(value))
  let take = () => {
    guard pending.val is Some(value) else {
      abort("owned Host Object payload was already consumed")
    }
    pending.val = None
    value
  }
  {
    materialize: Some(() => {
      let object = store.insert(take(), finalizer)
      { object, release: () => store.release(object) }
    }),
    discard: Some(() => finalizer(take())),
  }
}

///|
fn OwnedHostObject::take(
  self : OwnedHostObject,
) -> (() -> HostObjectEntry, () -> Unit) raise HostObjectFailure {
  guard self.materialize is Some(materialize) && self.discard is Some(discard) else {
    raise InvalidOwnedResult(detail="owned Host Object was already adopted")
  }
  self.materialize = None
  self.discard = None
  (materialize, discard)
}

///|
pub impl Debug for OwnedHostObject with fn to_repr(self : OwnedHostObject) -> Repr {
  Repr::ctor("OwnedHostObject", [
    (
      Some("state"),
      Repr::string(
        if self.materialize is Some(_) {
          "pending"
        } else {
          "adopted"
        },
      ),
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
  object : BorrowedHostObject
  release : () -> Unit
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
  entry : HostObjectEntry,
) -> HostObjectHandle {
  for index, slot in self.slots {
    if slot.entry is None {
      slot.entry = Some(entry)
      self.live_objects += 1
      return {
        identity: self.identity,
        slot: index,
        generation: slot.generation,
      }
    }
  }
  let slot : HostObjectSlot = { generation: 1, entry: Some(entry) }
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
  (entry.release)()
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
  self.context.state.host_objects.entry(handle).object
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
  let (materialize, discard) = object.take()
  if !self.context.state.host_objects.has_capacity() {
    discard()
    raise HostObjectLimitExceeded
  }
  let handle = self.context.state.host_objects.insert(materialize())
  match initialize(handle) {
    Ok(result) => Ok(result)
    Err(error) => {
      self.context.state.host_objects.release(handle)
      Err(error)
    }
  }
}
