///|
priv enum FrameCleanupEntry {
  Reference(@physical.SlotId)
  Callable(@physical.SlotId)
  Erased(@physical.SlotId, @physical.SlotId)
}

///|
fn FrameCleanupEntry::helper(
  self : FrameCleanupEntry,
) -> WasmHelperFunctionRole {
  match self {
    Reference(_) => CleanupLiveReference
    Callable(_) => CleanupLiveCallable
    Erased(_, _) => CleanupLiveErased
  }
}

///|
fn plan_frame_cleanup(
  slots : Array[@physical.SlotMetadata],
) -> Array[FrameCleanupEntry] {
  let entries = []
  for index, metadata in slots {
    let slot : @physical.SlotId = { value: index, }
    match metadata.cleanup {
      Trivial => ()
      OwnedRef => entries.push(Reference(slot))
      OwnedCallable => entries.push(Callable(slot))
      OwnedErased =>
        entries.push(Erased(slot, metadata.erased_companion.unwrap()))
    }
  }
  entries
}
