///|
test "function catalog closes dependencies before allocating identities" {
  let callable_slot : @physical.SlotMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    erased_companion: None,
  }
  let physical_body = fn(
    instructions : Array[@physical.Instruction],
  ) -> @physical.FunctionEntry {
    PhysicalBody({
      slots: [callable_slot, callable_slot],
      inputs: { environment: None, witnesses: [], user_parameters: [], },
      result: Unit,
      blocks: [{ parameters: [], instructions, terminator: Return(None), }],
    })
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    functions: [
      physical_body([
        ConstFunction({ value: 0, }, { value: 3, }),
        ConstFunction({ value: 1, }, { value: 2, }),
        Release({ value: 0, }),
        Release({ value: 1, }),
      ]),
      physical_body([]),
      physical_body([]),
      physical_body([]),
    ],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => fail("verification failed: \{Repr(error)}")
  }
  let module_ = @wasm_types.Module::empty()
  let catalog = plan_wasm_function_catalog(
    image,
    verified.global_lifecycle,
    false,
    module_,
  )
  debug_inspect(
    (
      catalog.roots,
      catalog.required,
      catalog.entries.map(entry => (entry.origin, entry.table_slot)),
      catalog.table_entries,
    ),
    content=(
      #|(
      #|  [
      #|    PhysicalFunction(function={ value: 1 }),
      #|    PhysicalFunction(function={ value: 2 }),
      #|    PhysicalFunction(function={ value: 3 }),
      #|    PhysicalFunction(function={ value: 4 }),
      #|    RuntimeFunction(ByteSequenceNew),
      #|    RuntimeFunction(HostObjectNew),
      #|    EntryWrapper,
      #|  ],
      #|  [
      #|    PhysicalFunction(function={ value: 1 }),
      #|    PhysicalFunction(function={ value: 2 }),
      #|    PhysicalFunction(function={ value: 3 }),
      #|    PhysicalFunction(function={ value: 4 }),
      #|    RuntimeFunction(ByteSequenceNew),
      #|    RuntimeFunction(HostObjectNew),
      #|    EntryWrapper,
      #|    RuntimeFunction(ReleaseReference),
      #|    RuntimeFunction(Allocate),
      #|    RuntimeFunction(Free),
      #|  ],
      #|  [
      #|    (PhysicalFunction(function={ value: 1 }), None),
      #|    (PhysicalFunction(function={ value: 2 }), Some({ index: 1 })),
      #|    (PhysicalFunction(function={ value: 3 }), Some({ index: 2 })),
      #|    (PhysicalFunction(function={ value: 4 }), None),
      #|    (RuntimeFunction(Allocate), None),
      #|    (RuntimeFunction(Free), None),
      #|    (RuntimeFunction(ReleaseReference), None),
      #|    (RuntimeFunction(ByteSequenceNew), None),
      #|    (RuntimeFunction(HostObjectNew), None),
      #|    (EntryWrapper, None),
      #|  ],
      #|  [{ index: 1 }, { index: 2 }],
      #|)
    ),
  )
}

///|
test "function catalog rejects an omitted dependency before emission" {
  let body : @physical.FunctionBody = {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    functions: [PhysicalBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => fail("verification failed: \{Repr(error)}")
  }
  let module_ = @wasm_types.Module::empty()
  let catalog = plan_wasm_function_catalog(
    image,
    verified.global_lifecycle,
    false,
    module_,
  )
  let incomplete = {
    ..catalog,
    required: catalog.required.filter(origin => {
      origin != RuntimeFunction(Allocate)
    }),
    entries: catalog.entries.filter(entry => {
      entry.origin != RuntimeFunction(Allocate)
    }),
  }
  debug_inspect(
    try {
      incomplete.validate(image, verified.global_lifecycle, module_)
      Ok(())
    } catch {
      error => Err(error)
    },
    content=(
      #|Err(InvalidFunctionCatalog(detail="function dependency is absent from the closure: RuntimeFunction(ByteSequenceNew) -> RuntimeFunction(Allocate)"))
    ),
  )
}
