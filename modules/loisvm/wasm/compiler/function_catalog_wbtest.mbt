///|
test "function catalog owns complete function and table identity" {
  let trivial_slot : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    erased_companion: None,
  }
  let body = fn(
    instructions : Array[@bytecode.Instruction],
  ) -> @bytecode.FunctionEntry {
    BytecodeBody({
      slots: [trivial_slot, trivial_slot],
      inputs: { environment: None, witnesses: [], user_parameters: [], },
      result: Unit,
      blocks: [{ parameters: [], instructions, terminator: Return(None), }],
    })
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    functions: [
      body([
        ConstFunction({ value: 0, }, { value: 3, }),
        ConstFunction({ value: 1, }, { value: 2, }),
        Release({ value: 0, }),
        Release({ value: 1, }),
      ]),
      body([]),
      body([]),
      body([]),
    ],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let verified = match @bytecode.verify_bytecode_image_for_execution(image) {
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
    (catalog.entries, catalog.table_entries),
    content=(
      #|(
      #|  [
      #|    {
      #|      handle: { index: 0 },
      #|      origin: BytecodeFunction(function={ value: 1 }),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 1 },
      #|      origin: BytecodeFunction(function={ value: 2 }),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 1 }),
      #|    },
      #|    {
      #|      handle: { index: 2 },
      #|      origin: BytecodeFunction(function={ value: 3 }),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 2 }),
      #|    },
      #|    {
      #|      handle: { index: 3 },
      #|      origin: BytecodeFunction(function={ value: 4 }),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 4 },
      #|      origin: RuntimeFunction(Allocate),
      #|      type_: { parameters: [I32], results: [I32] },
      #|      type_index: 1,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 5 },
      #|      origin: RuntimeFunction(Free),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 6 },
      #|      origin: RuntimeFunction(RetainReference),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 7 },
      #|      origin: RuntimeFunction(ReleaseReference),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 8 },
      #|      origin: RuntimeFunction(ByteSequenceNew),
      #|      type_: { parameters: [I32], results: [I32] },
      #|      type_index: 1,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 9 },
      #|      origin: RuntimeFunction(RequireByteSequenceLayout),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 10 },
      #|      origin: RuntimeFunction(ByteSequenceEqual),
      #|      type_: { parameters: [I32, I32], results: [I32] },
      #|      type_index: 2,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 11 },
      #|      origin: RuntimeFunction(ByteSequenceConcat),
      #|      type_: { parameters: [I32, I32], results: [I32] },
      #|      type_index: 2,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 12 },
      #|      origin: RuntimeFunction(ByteSequenceSlice),
      #|      type_: { parameters: [I32, I64, I64], results: [I32] },
      #|      type_index: 3,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 13 },
      #|      origin: RuntimeFunction(HostObjectNew),
      #|      type_: { parameters: [I64], results: [I32] },
      #|      type_index: 4,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 14 },
      #|      origin: RuntimeFunction(ByteSequenceMake),
      #|      type_: { parameters: [I64, I32], results: [I32] },
      #|      type_index: 5,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 15 },
      #|      origin: RuntimeFunction(ByteSequenceIndex),
      #|      type_: { parameters: [I32, I64], results: [I32] },
      #|      type_index: 6,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 16 },
      #|      origin: RuntimeFunction(ByteSequenceGet),
      #|      type_: { parameters: [I32, I64], results: [I32] },
      #|      type_index: 6,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 17 },
      #|      origin: RuntimeFunction(ByteSequenceSet),
      #|      type_: { parameters: [I32, I64, I32], results: [I32] },
      #|      type_index: 7,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 18 },
      #|      origin: RuntimeFunction(ByteSequenceIsValidUtf8),
      #|      type_: { parameters: [I32], results: [I32] },
      #|      type_index: 1,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|    {
      #|      handle: { index: 19 },
      #|      origin: HelperFunction(NoopErased),
      #|      type_: { parameters: [I64], results: [] },
      #|      type_index: 8,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 3 }),
      #|    },
      #|    {
      #|      handle: { index: 20 },
      #|      origin: HelperFunction(RetainReferenceErased),
      #|      type_: { parameters: [I64], results: [] },
      #|      type_index: 8,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 4 }),
      #|    },
      #|    {
      #|      handle: { index: 21 },
      #|      origin: HelperFunction(ReleaseReferenceErased),
      #|      type_: { parameters: [I64], results: [] },
      #|      type_index: 8,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 5 }),
      #|    },
      #|    {
      #|      handle: { index: 22 },
      #|      origin: HelperFunction(RetainCallable),
      #|      type_: { parameters: [I64], results: [] },
      #|      type_index: 8,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 6 }),
      #|    },
      #|    {
      #|      handle: { index: 23 },
      #|      origin: HelperFunction(ReleaseCallable),
      #|      type_: { parameters: [I64], results: [] },
      #|      type_index: 8,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 7 }),
      #|    },
      #|    {
      #|      handle: { index: 24 },
      #|      origin: HelperFunction(DestroyNoop),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 8 }),
      #|    },
      #|    {
      #|      handle: { index: 25 },
      #|      origin: HelperFunction(DestroyHostObject),
      #|      type_: { parameters: [I32], results: [] },
      #|      type_index: 0,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 9 }),
      #|    },
      #|    {
      #|      handle: { index: 26 },
      #|      origin: HelperFunction(ByteSequenceSizer),
      #|      type_: { parameters: [I32], results: [I32] },
      #|      type_index: 1,
      #|      declaration: Defined,
      #|      table_slot: Some({ index: 10 }),
      #|    },
      #|    {
      #|      handle: { index: 27 },
      #|      origin: EntryWrapper,
      #|      type_: { parameters: [], results: [] },
      #|      type_index: 9,
      #|      declaration: Defined,
      #|      table_slot: None,
      #|    },
      #|  ],
      #|  [
      #|    { index: 1 },
      #|    { index: 2 },
      #|    { index: 19 },
      #|    { index: 20 },
      #|    { index: 21 },
      #|    { index: 22 },
      #|    { index: 23 },
      #|    { index: 24 },
      #|    { index: 25 },
      #|    { index: 26 },
      #|  ],
      #|)
    ),
  )
  let errors : Array[WasmCompileError] = []
  let duplicate_catalog = {
    ..catalog,
    entries: catalog.entries.map(entry => entry),
  }
  duplicate_catalog.entries[1] = {
    ..duplicate_catalog.entries[1],
    origin: duplicate_catalog.entries[0].origin,
  }
  try
    duplicate_catalog.validate(image, verified.global_lifecycle, false, module_)
  catch {
    error => errors.push(error)
  } noraise {
    _ => fail("expected duplicate role rejection")
  }
  let incompatible_catalog = {
    ..catalog,
    entries: catalog.entries.map(entry => entry),
  }
  incompatible_catalog.entries[0] = {
    ..incompatible_catalog.entries[0],
    type_: wasm_function_type([], []),
  }
  try
    incompatible_catalog.validate(
      image,
      verified.global_lifecycle,
      false,
      module_,
    )
  catch {
    error => errors.push(error)
  } noraise {
    _ => fail("expected incompatible type rejection")
  }
  let missing_catalog = {
    ..catalog,
    entries: catalog.entries.filter(entry => !(entry.origin is EntryWrapper)),
  }
  try
    missing_catalog.validate(image, verified.global_lifecycle, false, module_)
  catch {
    error => errors.push(error)
  } noraise {
    _ => fail("expected missing role rejection")
  }
  let table_import_catalog = WasmFunctionCatalog::new(image)
  try
    table_import_catalog.add_entry(
      module_,
      BytecodeFunction(function={ value: 1, }),
      wasm_function_type([I32], []),
      Import(module_name="test", name="callable"),
      true,
    )
  catch {
    error => errors.push(error)
  } noraise {
    _ => fail("expected table import rejection")
  }
  debug_inspect(
    errors,
    content=(
      #|[
      #|  InvalidFunctionCatalog(detail="duplicate function role: BytecodeFunction(function={ value: 1 })"),
      #|  InvalidFunctionCatalog(detail="function type does not match role: BytecodeFunction(function={ value: 1 })"),
      #|  InvalidFunctionCatalog(detail="missing entry wrapper"),
      #|  InvalidFunctionCatalog(detail="callable table entry is not a defined body"),
      #|]
    ),
  )
}
