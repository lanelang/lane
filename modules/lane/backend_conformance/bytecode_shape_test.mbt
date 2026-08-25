///|
fn erased_reference_with_wrong_object_shape() -> @loisvm_bytecode.BytecodeImage {
  let slots : Array[@loisvm_bytecode.SlotMetadata] = [
    {
      representation: I32,
      cleanup: OwnedRef,
      kind: ByteSequenceValue,
      erased_companion: None,
    },
    {
      representation: I32,
      cleanup: Trivial,
      kind: LayoutValue,
      erased_companion: None,
    },
    {
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
      erased_companion: Some({ value: 1, }),
    },
    {
      representation: I32,
      cleanup: OwnedRef,
      kind: DataValue({ value: 0, }),
      erased_companion: None,
    },
  ]
  let body : @loisvm_bytecode.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          ConstLayout({ value: 1, }, { value: 3, }),
          EraseI32({ value: 2, }, { value: 0, }),
          UneraseI32({ value: 3, }, { value: 2, }),
          ConsumeFields({ value: 0, }, { value: 3, }, []),
        ],
        terminator: Return(None),
      },
    ],
  }
  {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 1,
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [ByteSequence, Data({ value: 0, }), Reference],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
    ],
    constants: [b"not data"],
  }
}

///|
test "unerasure validates recovered object shape across production backends" {
  let image = erased_reference_with_wrong_object_shape()
  assert_eq(@loisvm_bytecode.verify_bytecode_image(image), Ok(()))
  for backend in [DirectInterpreter, WasmInterpreter, WasmJit] {
    let outcome = execute_compiler_test_image(image, backend)
    assert_true(outcome.result is Err(EngineTrap(detail=_)))
  }
}
