///|
test "finalize rejects an invalid complete bytecode image" {
  let body : FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
  }
  assert_eq(
    finalize({
      entry: { value: 2 },
      initializer: None,
      functions: [Body(body)],
      data_family_count: 0,
      globals: [],
      layouts: [],
      object_shapes: [],
      constants: [],
    }),
    Err(
      BytecodeVerificationCompilerDefect(
        @bytecode.BytecodeVerificationError::InvalidBytecode(
          site=Image,
          detail="FunctionId 2 is out of range",
        ),
      ),
    ),
  )
}

///|
test "finalize derives definition and call ABIs from finalized value shapes" {
  let layout : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: LayoutValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let borrowed_string : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    ownership: Borrowed,
    erased_companion: None,
  }
  let scalar : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let erased : ValueMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    ownership: Owned,
    erased_companion: Some({ value: 0 }),
  }
  let entry : FunctionBody = {
    values: [layout, borrowed_string, scalar, erased, erased],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0 }, { value: 1 }),
          BorrowGlobal({ value: 1 }, { value: 0 }),
          ConstI32({ value: 2 }, 42),
          EraseI32({ value: 3 }, { value: 2 }),
          CallDirect(
            { value: 2 },
            None,
            [{ value: 0 }],
            [{ value: 1 }, { value: 3 }],
            Some({ value: 4 }),
          ),
          Release({ value: 4 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [layout, { ..borrowed_string, ownership: Owned }, erased],
    inputs: {
      environment: None,
      witnesses: [{ value: 0 }],
      user_parameters: [{ value: 1 }, { value: 2 }],
    },
    result: Value(I64, OwnedErased, ErasedValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 2 })),
      },
    ],
  }
  let initializer : FunctionBody = {
    values: [{ ..borrowed_string, ownership: Owned }],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0 }, { value: 0 }),
          InitGlobal({ value: 0 }, { value: 0 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = finalize({
    entry: { value: 1 },
    initializer: Some({ value: 3 }),
    functions: [Body(entry), Body(callee), Body(initializer)],
    data_family_count: 0,
    globals: [
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
    ],
    layouts: [Unit],
    object_shapes: [],
    constants: [b"Lane"],
  })
  guard image is Ok(image) else {
    fail("expected finalized bytecode: \{Repr(image)}")
  }
  assert_eq(image.callable_abis, [
    { witnesses: [], parameters: [], result: Unit },
    {
      witnesses: [{ representation: I32, cleanup: Trivial, kind: LayoutValue }],
      parameters: [
        { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
        { representation: I64, cleanup: OwnedErased, kind: ErasedValue },
      ],
      result: Value(I64, OwnedErased, ErasedValue),
    },
  ])
}
