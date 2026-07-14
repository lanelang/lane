///|
fn ExecutionInstance::initialize_global(
  self : ExecutionInstance,
  frame : Frame,
  global : @bytecode.GlobalId,
  source : @bytecode.SlotId,
) -> Unit raise ExecutionFailure {
  if !self.initializing {
    raise InternalFailure(detail="init_global executed outside initialization")
  }
  let metadata = self.global_metadata(global)
  if self.is_companion_global(global) {
    raise InternalFailure(detail="init_global targeted an erased companion")
  }
  if self.globals[global.value] is Some(_) {
    raise InternalFailure(
      detail="GlobalId \{global.value} was initialized twice",
    )
  }
  let value = frame.value(source)
  self.require_global_representation(metadata, value)
  if metadata.cleanup is OwnedErased {
    let companion = match metadata.erased_companion {
      Some(companion) => companion
      None => raise InternalFailure(detail="OwnedErased global lacks companion")
    }
    ignore(self.global_metadata(companion))
    if self.globals[companion.value] is Some(_) {
      raise InternalFailure(detail="erased companion was initialized twice")
    }
    let source_companion = match
      frame.body.slots[source.value].erased_companion {
      Some(companion) => companion
      None => raise InternalFailure(detail="OwnedErased source lacks companion")
    }
    self.globals[companion.value] = Some(I32(frame.i32(source_companion)))
  }
  frame.consume_owner(source)
  self.globals[global.value] = Some(value)
  self.initialized_globals.push(global)
}

///|
fn ExecutionInstance::borrow_global(
  self : ExecutionInstance,
  frame : Frame,
  destination : @bytecode.SlotId,
  global : @bytecode.GlobalId,
) -> Unit raise ExecutionFailure {
  let metadata = self.global_metadata(global)
  let value = match self.globals[global.value] {
    Some(value) => value
    None =>
      raise InternalFailure(
        detail="read from uninitialized GlobalId \{global.value}",
      )
  }
  self.require_global_representation(metadata, value)
  if metadata.cleanup is OwnedErased {
    let global_companion = match metadata.erased_companion {
      Some(companion) => companion
      None => raise InternalFailure(detail="OwnedErased global lacks companion")
    }
    let destination_companion = match
      frame.body.slots[destination.value].erased_companion {
      Some(companion) => companion
      None =>
        raise InternalFailure(
          detail="OwnedErased global borrow destination lacks companion",
        )
    }
    guard self.globals[global_companion.value] is Some(I32(layout)) else {
      raise InternalFailure(detail="erased companion is uninitialized")
    }
    frame.write(destination_companion, I32(layout))
  }
  frame.write_borrowed(destination, value)
}

///|
fn ExecutionInstance::validate_initialized_globals(
  self : ExecutionInstance,
) -> Unit raise ExecutionFailure {
  for index, value in self.globals {
    if value is None {
      raise InternalFailure(
        detail="initializer left GlobalId \{index} uninitialized",
      )
    }
  }
}

///|
fn ExecutionInstance::cleanup_globals(
  self : ExecutionInstance,
) -> Unit raise ExecutionFailure {
  while self.initialized_globals.pop() is Some(global) {
    guard self.globals[global.value] is Some(value) else {
      raise InternalFailure(detail="initialized global has no value")
    }
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
  let metadata = self.global_metadata(global)
  match (metadata.cleanup, value) {
    (Trivial, _) => ()
    (OwnedRef, I32(reference)) => self.heap.release_reference(reference)
    (OwnedCallable, I64(callable)) => self.heap.release_callable(callable)
    (OwnedErased, I64(payload)) => {
      let companion = match metadata.erased_companion {
        Some(companion) => companion
        None =>
          raise InternalFailure(detail="OwnedErased global lacks companion")
      }
      guard self.globals[companion.value] is Some(I32(layout)) else {
        raise InternalFailure(detail="erased companion is uninitialized")
      }
      self.heap.release_erased(payload, { value: layout })
      self.globals[companion.value] = None
    }
    _ => raise InternalFailure(detail="global cleanup representation mismatch")
  }
}

///|
fn ExecutionInstance::global_metadata(
  self : ExecutionInstance,
  global : @bytecode.GlobalId,
) -> @bytecode.GlobalMetadata raise ExecutionFailure {
  if global.value < 0 || global.value >= self.loaded.image.globals.length() {
    raise InternalFailure(detail="GlobalId \{global.value} is out of range")
  }
  self.loaded.image.globals[global.value]
}

///|
fn ExecutionInstance::is_companion_global(
  self : ExecutionInstance,
  global : @bytecode.GlobalId,
) -> Bool {
  self.loaded.image.globals.any(metadata => {
    metadata.erased_companion == Some(global)
  })
}

///|
fn ExecutionInstance::require_global_representation(
  self : ExecutionInstance,
  metadata : @bytecode.GlobalMetadata,
  value : VMValue,
) -> Unit raise ExecutionFailure {
  ignore(self)
  let matches = match (metadata.representation, value) {
    (I32, I32(_)) | (I64, I64(_)) | (F64, F64(_)) => true
    _ => false
  }
  if !matches {
    raise InternalFailure(detail="global representation mismatch")
  }
}
