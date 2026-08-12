///|
test "Wasm compilation records every function at its emission boundary" {
  let f32_slot : @bytecode.SlotMetadata = {
    representation: F32,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let string_slot : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let body : @bytecode.FunctionBody = {
    slots: [f32_slot, string_slot],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstF32({ value: 0 }, 0),
          F32ToString({ value: 1 }, { value: 0 }),
          Release({ value: 1 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let import_ : @bytecode.RuntimeImport = {
    abi_major: 1,
    parameters: [],
    result: Unit,
    symbol: "lane.test.observe",
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [BytecodeBody(body), RuntimeImport(import_)],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [Environment({ stored_witness_count: 0, members: [] })],
    constants: [],
  }
  let observed = match compile_observed(image) {
    Ok(observed) => observed
    Err(error) => fail("observed compile failed: \{Repr(error)}")
  }
  let ordinary = match compile(image) {
    Ok(module_) => module_
    Err(error) => fail("ordinary compile failed: \{Repr(error)}")
  }
  assert_eq(module_to_wat(observed.module_), module_to_wat(ordinary))
  debug_inspect(
    observed.functions,
    content=(
      #|[
      #|  { index: 0, origin: InternalRuntimeImport(F32ToString) },
      #|  {
      #|    index: 1,
      #|    origin: PhysicalRuntimeImport(
      #|      function={ value: 2 },
      #|      symbol="lane.test.observe",
      #|    ),
      #|  },
      #|  { index: 2, origin: BytecodeFunction(function={ value: 1 }) },
      #|  {
      #|    index: 3,
      #|    origin: RuntimeImportAdapter(
      #|      function={ value: 2 },
      #|      symbol="lane.test.observe",
      #|    ),
      #|  },
      #|  { index: 4, origin: RuntimeFunction(Allocate) },
      #|  { index: 5, origin: RuntimeFunction(Free) },
      #|  { index: 6, origin: RuntimeFunction(RetainReference) },
      #|  { index: 7, origin: RuntimeFunction(ReleaseReference) },
      #|  { index: 8, origin: RuntimeFunction(ByteSequenceNew) },
      #|  { index: 9, origin: RuntimeFunction(RequireByteSequenceLayout) },
      #|  { index: 10, origin: RuntimeFunction(ByteSequenceEqual) },
      #|  { index: 11, origin: RuntimeFunction(ByteSequenceConcat) },
      #|  { index: 12, origin: RuntimeFunction(ByteSequenceSlice) },
      #|  { index: 13, origin: RuntimeFunction(HostObjectNew) },
      #|  { index: 14, origin: RuntimeFunction(ByteSequenceMake) },
      #|  { index: 15, origin: RuntimeFunction(ByteSequenceIndex) },
      #|  { index: 16, origin: RuntimeFunction(ByteSequenceGet) },
      #|  { index: 17, origin: RuntimeFunction(ByteSequenceSet) },
      #|  { index: 18, origin: RuntimeFunction(ByteSequenceIsValidUtf8) },
      #|  { index: 19, origin: HelperFunction(NoopErased) },
      #|  { index: 20, origin: HelperFunction(RetainReferenceErased) },
      #|  { index: 21, origin: HelperFunction(ReleaseReferenceErased) },
      #|  { index: 22, origin: HelperFunction(RetainCallable) },
      #|  { index: 23, origin: HelperFunction(ReleaseCallable) },
      #|  { index: 24, origin: HelperFunction(DestroyNoop) },
      #|  { index: 25, origin: HelperFunction(DestroyHostObject) },
      #|  { index: 26, origin: HelperFunction(DestroyShape(shape=0)) },
      #|  { index: 27, origin: HelperFunction(ByteSequenceSizer) },
      #|  { index: 28, origin: EntryWrapper },
      #|]
    ),
  )
  assert_eq(
    observed.scale.functions.map(function => function.index),
    observed.functions[observed.scale.imported_function_count:].map(function => {
      function.index
    }),
  )
}
