///|
pub fn finalize(
  image : Image,
) -> Result[@bytecode.BytecodeImage, FinalizeError] {
  match finalize_without_bytecode_verification(image) {
    Err(error) => Err(error)
    Ok(finalized) =>
      match @bytecode.verify_bytecode_image(finalized) {
        Ok(_) => Ok(finalized)
        Err(error) => Err(BytecodeVerificationCompilerDefect(error))
      }
  }
}

///|
priv struct CallableAbiInterner {
  entries : Array[@bytecode.CallableAbi]
}

///|
fn CallableAbiInterner::intern(
  self : CallableAbiInterner,
  abi : @bytecode.CallableAbi,
) -> @bytecode.CallableAbiId {
  for index, existing in self.entries {
    if existing == abi {
      return { value: index }
    }
  }
  let id : @bytecode.CallableAbiId = { value: self.entries.length() }
  self.entries.push(abi)
  id
}

///|
fn finalize_without_bytecode_verification(
  image : Image,
) -> Result[@bytecode.BytecodeImage, FinalizeError] {
  Ok(finalize_without_bytecode_verification_or_raise(image)) catch {
    error => Err(error)
  }
}

///|
fn finalize_without_bytecode_verification_or_raise(
  image : Image,
) -> @bytecode.BytecodeImage raise FinalizeError {
  let image = devirtualize_image(image)
  let image = select_consuming_projections(image)
  let functions = image.functions.map(entry => {
    match entry {
      Body(body) => Body(prepare_body(body))
      RuntimeImport(_) => entry
    }
  })
  let callable_abis = CallableAbiInterner::{ entries: [] }
  let finalized_functions : Array[@bytecode.FunctionEntry] = []
  for entry in functions {
    match entry {
      Body(body) =>
        finalized_functions.push(
          BytecodeBody(finalize_prepared_body(body, callable_abis)),
        )
      RuntimeImport(import_) => finalized_functions.push(RuntimeImport(import_))
    }
  }
  for entry in finalized_functions {
    if entry.callable_abi() is Some(abi) {
      ignore(callable_abis.intern(abi))
    }
  }
  {
    entry: image.entry,
    initializer: image.initializer,
    callable_abis: callable_abis.entries,
    data_family_count: image.data_family_count,
    functions: finalized_functions,
    globals: image.globals,
    layouts: image.layouts,
    object_shapes: image.object_shapes,
    constants: image.constants,
  }
}

///|
fn prepare_body(body : FunctionBody) -> FunctionBody raise FinalizeError {
  let body = simplify_body(body)
  let body = promote_cross_block_instruction_borrows(body)
  let body = thread_owned_block_values(body)
  for index, metadata in body.values {
    validate_metadata({ value: index }, metadata)
  }
  body
}

///|
fn finalize_prepared_body(
  body : FunctionBody,
  callable_abis : CallableAbiInterner,
) -> @bytecode.FunctionBody raise FinalizeError {
  let slots = allocate_physical_slots(insert_arc(body))
  let body = slots.arc_final.body
  {
    slots: slots.slots,
    inputs: {
      environment: body.inputs.environment.map(value => slots.slot(value)),
      witnesses: body.inputs.witnesses.map(value => slots.slot(value)),
      user_parameters: body.inputs.user_parameters.map(value => {
        slots.slot(value)
      }),
    },
    result: body.result,
    blocks: body.blocks.map(block => {
      emit_block(body.result, slots, callable_abis, block)
    }),
  }
}

///|
fn validate_metadata(
  value : ValueId,
  metadata : ValueMetadata,
) -> Unit raise FinalizeError {
  let valid = match (metadata.ownership, metadata.cleanup) {
    (Trivial, Trivial) => true
    (Owned, OwnedRef | OwnedCallable | OwnedErased) => true
    (Borrowed, OwnedRef | OwnedCallable | OwnedErased) => true
    _ => false
  }
  if !valid {
    raise IllegalValueMetadata(value~)
  }
}

///|
fn value_metadata_to_slot(metadata : ValueMetadata) -> @bytecode.SlotMetadata {
  if metadata.ownership is Borrowed && metadata.cleanup is OwnedErased {
    return {
      representation: metadata.representation,
      cleanup: OwnedErased,
      kind: metadata.kind,
      erased_companion: metadata.erased_companion.map(fn(value) {
        { value: value.value }
      }),
    }
  }
  {
    representation: metadata.representation,
    cleanup: match metadata.ownership {
      Trivial | Borrowed => Trivial
      Owned => metadata.cleanup
    },
    kind: metadata.kind,
    erased_companion: match metadata.ownership {
      Owned if metadata.cleanup is OwnedErased =>
        metadata.erased_companion.map(fn(value) { { value: value.value } })
      _ => None
    },
  }
}
