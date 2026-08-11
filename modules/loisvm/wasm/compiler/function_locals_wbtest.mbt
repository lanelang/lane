///|
test "trivial functions omit frame liveness locals" {
  let trivial_slot : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let body : @bytecode.FunctionBody = {
    slots: [trivial_slot, trivial_slot, trivial_slot],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0 }, 40L),
          ConstI64({ value: 1 }, 2L),
          I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let wasm_module = match compile(image) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  debug_inspect(wasm_module.codes[0].locals, content="[I64, I64, I64]")
}

///|
test "CFG functions allocate only required transfer and liveness locals" {
  let trivial_i64 : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let owned_string : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let body : @bytecode.FunctionBody = {
    slots: [trivial_i64, owned_string, trivial_i64, owned_string],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0 }, 42L),
          ConstString({ value: 1 }, { value: 0 }),
        ],
        terminator: Jump({
          target: { value: 1 },
          arguments: [{ value: 0 }, { value: 1 }],
        }),
      },
      {
        parameters: [{ value: 2 }, { value: 3 }],
        instructions: [Release({ value: 3 })],
        terminator: Return(None),
      },
    ],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"Lane"],
  }
  let wasm_module = match compile(image) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  debug_inspect(
    wasm_module.codes[0].locals,
    content="[I64, I32, I64, I32, I64, I32, I32, I32]",
  )
}
