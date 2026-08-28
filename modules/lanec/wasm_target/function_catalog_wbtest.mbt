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
    verified.global_lifecycle(),
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
      #|    EntryWrapper,
      #|  ],
      #|  [
      #|    PhysicalFunction(function={ value: 1 }),
      #|    PhysicalFunction(function={ value: 2 }),
      #|    PhysicalFunction(function={ value: 3 }),
      #|    PhysicalFunction(function={ value: 4 }),
      #|    EntryWrapper,
      #|    RuntimeFunction(ReleaseReference),
      #|    RuntimeFunction(Free),
      #|  ],
      #|  [
      #|    (PhysicalFunction(function={ value: 1 }), None),
      #|    (PhysicalFunction(function={ value: 2 }), Some({ index: 1 })),
      #|    (PhysicalFunction(function={ value: 3 }), Some({ index: 2 })),
      #|    (PhysicalFunction(function={ value: 4 }), None),
      #|    (RuntimeFunction(Free), None),
      #|    (RuntimeFunction(ReleaseReference), None),
      #|    (EntryWrapper, None),
      #|  ],
      #|  [{ index: 1 }, { index: 2 }],
      #|)
    ),
  )
}

///|
test "function catalog rejects an omitted dependency before emission" {
  let reference_slot : @physical.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let body : @physical.FunctionBody = {
    slots: [reference_slot],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          Release({ value: 0, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    functions: [PhysicalBody(body)],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b""],
  }
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => fail("verification failed: \{Repr(error)}")
  }
  let module_ = @wasm_types.Module::empty()
  let catalog = plan_wasm_function_catalog(
    image,
    verified.global_lifecycle(),
    false,
    module_,
  )
  let incomplete = {
    ..catalog,
    required: catalog.required.filter(origin => origin != RuntimeFunction(Free)),
    entries: catalog.entries.filter(entry => {
      entry.origin != RuntimeFunction(Free)
    }),
  }
  debug_inspect(
    try {
      incomplete.validate(image, verified.global_lifecycle(), module_)
      Ok(())
    } catch {
      error => Err(error)
    },
    content=(
      #|Err(InvalidFunctionCatalog(detail="function dependency is absent from the closure: RuntimeFunction(ReleaseReference) -> RuntimeFunction(Free)"))
    ),
  )
}

///|
test "function catalog certifies runtime services against physical layouts" {
  let body : @physical.FunctionBody = {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let string_import : @lane_runtime.RuntimeImport = {
    abi_major: 1,
    parameters: [],
    result: String,
    symbol: "lane.test.string_result",
  }
  let opaque_import : @lane_runtime.RuntimeImport = {
    abi_major: 1,
    parameters: [],
    result: Opaque,
    symbol: "lane.test.opaque_result",
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      @physical.runtime_import_callable_abi(string_import),
      @physical.runtime_import_callable_abi(opaque_import),
    ],
    data_family_count: 0,
    functions: [
      PhysicalBody(body),
      RuntimeImport(string_import),
      RuntimeImport(opaque_import),
    ],
    globals: [],
    layouts: [Reference, ByteSequence],
    object_shapes: [],
    constants: [],
  }
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => fail("verification failed: \{Repr(error)}")
  }
  let catalog = plan_wasm_function_catalog(
    image,
    verified.global_lifecycle(),
    true,
    @wasm_types.Module::empty(),
  )
  debug_inspect(
    (
      catalog.runtime_services.map(capability => {
        (capability.service, capability.layout_id)
      }),
      catalog.required.filter(origin => {
        origin == RuntimeFunction(ByteSequenceNew) ||
        origin == RuntimeFunction(HostObjectNew)
      }),
    ),
    content=(
      #|(
      #|  [(StringNew, 2), (HostObjectNew, 1)],
      #|  [RuntimeFunction(ByteSequenceNew), RuntimeFunction(HostObjectNew)],
      #|)
    ),
  )
}
