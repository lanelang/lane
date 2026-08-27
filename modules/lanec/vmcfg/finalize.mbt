///|
pub fn finalize(
  image : Image,
) -> Result[@physical.PhysicalProgram, FinalizeError] {
  match finalize_observed(image) {
    Err(error) => Err(error)
    Ok(finalized) => Ok(finalized.physical_program)
  }
}

///|
pub fn finalize_observed(image : Image) -> Result[Finalization, FinalizeError] {
  match prepare(image) {
    Err(error) => Err(error)
    Ok(prepared) =>
      match finalize_prepared(prepared) {
        Err(error) => Err(error)
        Ok(physical_program) =>
          match
            verify_indirect_call_observations(
              physical_program,
              prepared.indirect_calls,
            ) {
            Err(error) => Err(error)
            Ok(_) =>
              Ok({
                pre_arc_image: prepared.image,
                source_functions: prepared.source_functions,
                indirect_calls: prepared.indirect_calls,
                physical_program,
              })
          }
      }
  }
}

///|
fn verify_indirect_call_observations(
  program : @physical.PhysicalProgram,
  observations : Array[IndirectCallObservation],
) -> Result[Unit, FinalizeError] {
  let observed = Array::make(program.functions.length(), 0)
  for observation in observations {
    observed[observation.function.value - 1] += 1
  }
  for index, entry in program.functions {
    let physical = match entry {
      RuntimeImport(_) => 0
      PhysicalBody(body) =>
        body.blocks.fold(init=0, fn(total, block) {
          let calls = block.instructions.fold(init=0, fn(total, instruction) {
            if instruction is CallValue(_, _, _, _, _) {
              total + 1
            } else {
              total
            }
          })
          if block.terminator is TailCallValue(_, _, _, _) {
            total + calls + 1
          } else {
            total + calls
          }
        })
    }
    if observed[index] != physical {
      return Err(
        IndirectCallObservationMismatch(
          { value: index + 1, },
          observed[index],
          physical,
        ),
      )
    }
  }
  Ok(())
}

///|
fn prepare(image : Image) -> Result[CanonicalPreArcImage, FinalizeError] {
  Ok(prepare_or_raise(image)) catch {
    error => Err(error)
  }
}

///|
fn prepare_or_raise(image : Image) -> CanonicalPreArcImage raise FinalizeError {
  let devirtualized = devirtualize_image_with_direct_environments(image)
  let image = inline_single_use_direct_functions(
    devirtualized.image,
    devirtualized.direct_environment_targets,
  )
  let image = select_consuming_projections(image)
  let image = {
    ..image,
    functions: image.functions.map(entry => {
      match entry {
        Body(body) => Body(prepare_body(body))
        RuntimeImport(_) => entry
      }
    }),
  }
  let canonical = canonicalize_function_table_to_fixed_point(image) catch {
    error => raise FunctionTableCanonicalizationCompilerDefect(error)
  }
  {
    image: canonical.image,
    source_functions: canonical.source_functions,
    indirect_calls: observe_indirect_calls(canonical.image),
  }
}

///|
pub fn Finalization::pre_arc_image(self : Finalization) -> Image {
  self.pre_arc_image
}

///|
pub fn Finalization::source_functions(
  self : Finalization,
) -> Array[Array[@physical.FunctionId]] {
  self.source_functions.map(functions => functions.copy())
}

///|
pub fn Finalization::indirect_calls(
  self : Finalization,
) -> Array[IndirectCallObservation] {
  self.indirect_calls.map(observation => {
    ..observation,
    boundaries: observation.boundaries.copy(),
    resolution: match observation.resolution {
      ExactTarget(target, environment) => ExactTarget(target, environment)
      MultipleTargets(targets) => MultipleTargets(targets.copy())
      UnknownTargets(targets) => UnknownTargets(targets.copy())
    },
  })
}

///|
pub fn Finalization::physical_program(
  self : Finalization,
) -> @physical.PhysicalProgram {
  self.physical_program
}

///|
fn finalize_prepared(
  prepared : CanonicalPreArcImage,
) -> Result[@physical.PhysicalProgram, FinalizeError] {
  match finalize_prepared_without_physical_verification(prepared) {
    Err(error) => Err(error)
    Ok(finalized) =>
      match @physical.verify_physical_program(finalized) {
        Ok(_) => Ok(finalized)
        Err(error) => Err(PhysicalProgramVerificationCompilerDefect(error))
      }
  }
}

///|
priv struct CallableAbiInterner {
  entries : Array[@physical.CallableAbi]
}

///|
fn CallableAbiInterner::intern(
  self : CallableAbiInterner,
  abi : @physical.CallableAbi,
) -> @physical.CallableAbiId {
  for index, existing in self.entries {
    if existing == abi {
      return { value: index, }
    }
  }
  let id : @physical.CallableAbiId = { value: self.entries.length(), }
  self.entries.push(abi)
  id
}

///|
fn finalize_prepared_without_physical_verification(
  prepared : CanonicalPreArcImage,
) -> Result[@physical.PhysicalProgram, FinalizeError] {
  Ok(finalize_without_physical_verification_or_raise(prepared)) catch {
    error => Err(error)
  }
}

///|
fn finalize_without_physical_verification_or_raise(
  prepared : CanonicalPreArcImage,
) -> @physical.PhysicalProgram raise FinalizeError {
  let image = prepared.image
  let callable_abis = CallableAbiInterner::{ entries: [], }
  let finalized_functions : Array[@physical.FunctionEntry] = []
  for entry in image.functions {
    match entry {
      Body(body) =>
        finalized_functions.push(
          PhysicalBody(finalize_prepared_body(body, callable_abis)),
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
    validate_metadata({ value: index, }, metadata)
  }
  body
}

///|
fn finalize_prepared_body(
  body : FunctionBody,
  callable_abis : CallableAbiInterner,
) -> @physical.FunctionBody raise FinalizeError {
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
fn value_metadata_to_slot(metadata : ValueMetadata) -> @physical.SlotMetadata {
  if metadata.ownership is Borrowed && metadata.cleanup is OwnedErased {
    return {
      representation: metadata.representation,
      cleanup: OwnedErased,
      kind: metadata.kind,
      erased_companion: metadata.erased_companion.map(fn(value) {
        { value: value.value, }
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
        metadata.erased_companion.map(fn(value) { { value: value.value, } })
      _ => None
    },
  }
}
