///|
fn ExecutionInstance::initialize_global(
  self : ExecutionInstance,
  frame : Frame,
  global : @bytecode.GlobalId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  let metadata = self.loaded.image.globals[global.value]
  let value = frame.value(source)
  if metadata.cleanup is OwnedErased {
    let companion = metadata.erased_companion.unwrap()
    let source_companion = frame.body.slots[source.value].erased_companion.unwrap()
    self.globals[companion.value] = Some(I32(frame.i32(source_companion)))
  }
  frame.consume_owner(source)
  self.globals[global.value] = Some(value)
  let root_ordinal = self.loaded.global_lifecycle.root_ordinals[global.value]
  if self.loaded.global_lifecycle.roots[root_ordinal].owned_ordinal
    is Some(owned_ordinal) {
    self.initialized_owned_root_count = owned_ordinal + 1
  }
}

///|
fn ExecutionInstance::borrow_global(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  global : @bytecode.GlobalId,
) -> Unit raise ExecutionFailure {
  let metadata = self.loaded.image.globals[global.value]
  let value = self.globals[global.value].unwrap()
  if metadata.cleanup is OwnedErased {
    let global_companion = metadata.erased_companion.unwrap()
    let destination_companion = frame.body.slots[destination.value].erased_companion.unwrap()
    guard self.globals[global_companion.value] is Some(I32(layout)) else {
      raise InternalFailure(detail="erased companion representation mismatch")
    }
    frame.write(destination_companion, I32(layout))
  }
  frame.write_borrowed(destination, value)
}

///|
fn ExecutionInstance::cleanup_globals(
  self : ExecutionInstance,
) -> Unit raise ExecutionFailure {
  while self.initialized_owned_root_count > 0 {
    self.initialized_owned_root_count -= 1
    let root = self.loaded.global_lifecycle.owned_roots[self.initialized_owned_root_count]
    let global = root.global
    let value = self.globals[global.value].unwrap()
    self.globals[global.value] = None
    self.release_global(global, value)
  }
}

///|
fn ExecutionInstance::release_global(
  self : ExecutionInstance,
  global : @bytecode.GlobalId,
  value : VMValue,
) -> Unit raise ExecutionFailure {
  let metadata = self.loaded.image.globals[global.value]
  match (metadata.cleanup, value) {
    (Trivial, _) => ()
    (OwnedRef, I32(reference)) => self.heap.release_reference(reference)
    (OwnedCallable, I64(callable)) => self.heap.release_callable(callable)
    (OwnedErased, I64(payload)) => {
      let companion = metadata.erased_companion.unwrap()
      guard self.globals[companion.value] is Some(I32(layout)) else {
        raise InternalFailure(
          detail="erased companion cleanup representation mismatch",
        )
      }
      self.heap.release_erased(payload, { value: layout })
      self.globals[companion.value] = None
    }
    _ => raise InternalFailure(detail="global cleanup representation mismatch")
  }
}
