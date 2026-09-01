///|
test "Wasm compilation records every function at its emission boundary" {
  let f32_slot : @physical.SlotMetadata = {
    representation: F32,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let string_slot : @physical.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let body : @physical.FunctionBody = {
    slots: [f32_slot, string_slot],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstF32({ value: 0, }, 0),
          F32ToString({ value: 1, }, { value: 0, }),
          Release({ value: 1, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let import_ : @wasm_abi.ImportContract = {
    module_name: "lane.test",
    field_name: "lane.test.observe",
    parameters: [],
    result: Unit,
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    functions: [PhysicalBody(body), RuntimeImport(import_)],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
    constants: [],
  }
  let observed = match compile_observed(certify_physical_program_test(image)) {
    Ok(observed) => observed
    Err(error) => fail("observed compile failed: \{Repr(error)}")
  }
  let ordinary = match compile(certify_physical_program_test(image)) {
    Ok(module_) => module_
    Err(error) => fail("ordinary compile failed: \{Repr(error)}")
  }
  assert_eq(module_to_wat(observed.module_), module_to_wat(ordinary))
  debug_inspect(runtime_service_exports(observed.module_), content="[]")
  debug_inspect(
    observed.functions,
    content=(
      #|[
      #|  {
      #|    index: 0,
      #|    origin: PhysicalRuntimeImport(
      #|      function={ value: 2 },
      #|      module_name="lane.test",
      #|      field_name="lane.test.observe",
      #|    ),
      #|  },
      #|  { index: 1, origin: PhysicalFunction(function={ value: 1 }) },
      #|  {
      #|    index: 2,
      #|    origin: RuntimeImportAdapter(
      #|      function={ value: 2 },
      #|      module_name="lane.test",
      #|      field_name="lane.test.observe",
      #|    ),
      #|  },
      #|  { index: 3, origin: BuiltinFunction(FloatMemcpy) },
      #|  { index: 4, origin: BuiltinFunction(FormatF32) },
      #|  { index: 5, origin: BuiltinFunction(CanonicalizeFloatText) },
      #|  { index: 6, origin: RuntimeFunction(Allocate) },
      #|  { index: 7, origin: RuntimeFunction(Free) },
      #|  { index: 8, origin: RuntimeFunction(RetainReference) },
      #|  { index: 9, origin: RuntimeFunction(ReleaseReference) },
      #|  { index: 10, origin: RuntimeFunction(ByteSequenceNew) },
      #|  { index: 11, origin: HelperFunction(RetainReferenceErased) },
      #|  { index: 12, origin: HelperFunction(ReleaseReferenceErased) },
      #|  { index: 13, origin: HelperFunction(DestroyNoop) },
      #|  { index: 14, origin: HelperFunction(ByteStorageSizer) },
      #|  { index: 15, origin: EntryWrapper },
      #|]
    ),
  )
  assert_eq(observed.scale.unreachable_support_role_count, 0)
  assert_eq(
    observed.scale.functions.map(function => function.index),
    observed.functions[observed.scale.imported_function_count:].map(function => {
      function.index
    }),
  )
}

///|
test "Wasm compilation emits only required byte-buffer support" {
  let scalar_i64 : @physical.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let scalar_i32 : @physical.SlotMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let buffer : @physical.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteBufferValue,
    erased_companion: None,
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    functions: [
      PhysicalBody({
        slots: [scalar_i64, buffer, scalar_i64, scalar_i32, scalar_i32],
        inputs: { environment: None, witnesses: [], user_parameters: [], },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstI64({ value: 0, }, 4),
              ByteBufferMake({ value: 1, }, { value: 0, }),
              ConstI64({ value: 2, }, 0),
              ConstI32({ value: 3, }, 42),
              ByteBufferWriteI32({ value: 1, }, { value: 2, }, { value: 3, }),
              ByteBufferReadI32({ value: 4, }, { value: 1, }, { value: 2, }),
              Release({ value: 1, }),
            ],
            terminator: Return(None),
          },
        ],
      }),
    ],
    globals: [],
    layouts: [ByteBuffer],
    object_shapes: [],
    constants: [],
  }
  let observed = match compile_observed(certify_physical_program_test(image)) {
    Ok(observed) => observed
    Err(error) => fail("observed compile failed: \{Repr(error)}")
  }
  debug_inspect(
    observed.functions.map(function => function.origin),
    content=(
      #|[
      #|  PhysicalFunction(function={ value: 1 }),
      #|  RuntimeFunction(Allocate),
      #|  RuntimeFunction(Free),
      #|  RuntimeFunction(RetainReference),
      #|  RuntimeFunction(ReleaseReference),
      #|  RuntimeFunction(ByteBufferMake),
      #|  RuntimeFunction(RequireByteBufferLayout),
      #|  RuntimeFunction(ByteBufferWriteI32),
      #|  RuntimeFunction(ByteBufferReadI32),
      #|  HelperFunction(RetainReferenceErased),
      #|  HelperFunction(ReleaseReferenceErased),
      #|  HelperFunction(DestroyNoop),
      #|  HelperFunction(ByteStorageSizer),
      #|  EntryWrapper,
      #|]
    ),
  )
  assert_eq(observed.scale.unreachable_support_role_count, 0)
}
