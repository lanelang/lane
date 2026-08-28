///|
test "finalize rejects an invalid complete physical program" {
  let body : FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  assert_eq(
    finalize({
      entry: { value: 2, },
      initializer: None,
      functions: [Body(body)],
      data_family_count: 0,
      globals: [],
      layouts: [],
      object_shapes: [],
      constants: [],
    }),
    Err(
      FunctionTableCanonicalizationCompilerDefect(
        InvalidFunctionReference({ value: 2, }),
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
    erased_companion: Some({ value: 0, }),
  }
  let entry : FunctionBody = {
    values: [layout, borrowed_string, scalar, erased, erased],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0, }, { value: 1, }),
          BorrowGlobal({ value: 1, }, { value: 0, }),
          ConstI32({ value: 2, }, 42),
          EraseI32({ value: 3, }, { value: 2, }),
          CallDirect(
            { value: 2, },
            None,
            [{ value: 0, }],
            [{ value: 1, }, { value: 3, }],
            Some({ value: 4, }),
          ),
          Release({ value: 4, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [layout, { ..borrowed_string, ownership: Owned, }, erased],
    inputs: {
      environment: None,
      witnesses: [{ value: 0, }],
      user_parameters: [{ value: 1, }, { value: 2, }],
    },
    result: Value(I64, OwnedErased, ErasedValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  let initializer : FunctionBody = {
    values: [{ ..borrowed_string, ownership: Owned, }],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          InitGlobal({ value: 0, }, { value: 0, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = finalize({
    entry: { value: 1, },
    initializer: Some({ value: 3, }),
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
    fail("expected finalized physical program: \{Repr(image)}")
  }
  let image = image.image()
  assert_eq(image.callable_abis, [
    { witnesses: [], parameters: [], result: Unit, },
    {
      witnesses: [{ representation: I32, cleanup: Trivial, kind: LayoutValue, }],
      parameters: [
        { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue, },
        { representation: I64, cleanup: OwnedErased, kind: ErasedValue, },
      ],
      result: Value(I64, OwnedErased, ErasedValue),
    },
  ])
}

///|
test "finalize shares callable ABIs across every callable occurrence" {
  let scalar : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let unit_body : FunctionBody = {
    values: [scalar, scalar, callable, callable, callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI32({ value: 0, }, 42),
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 0, }],
            Some({ value: 1, }),
          ),
          ConstFunction({ value: 2, }, { value: 3, }),
          Release({ value: 2, }),
          ConstFunction({ value: 3, }, { value: 4, }),
          Release({ value: 3, }),
          ConstFunction({ value: 4, }, { value: 5, }),
          Release({ value: 4, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let target : FunctionBody = {
    values: [scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let indirect : FunctionBody = {
    values: [callable, scalar, scalar, scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }, { value: 1, }],
    },
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          CallValue({ value: 0, }, [], [{ value: 1, }], Some({ value: 3, })),
        ],
        terminator: Return(Some({ value: 3, })),
      },
    ],
  }
  let indirect_tail : FunctionBody = {
    values: [callable, scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }, { value: 1, }],
    },
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: TailCallValue({ value: 0, }, [], [{ value: 1, }]),
      },
    ],
  }
  let image = finalize({
    entry: { value: 1, },
    initializer: None,
    functions: [
      Body(unit_body),
      Body(target),
      Body(indirect),
      Body(indirect_tail),
      RuntimeImport({
        abi_major: 1,
        parameters: [I64],
        result: I64,
        symbol: "lane.test.i64",
      }),
    ],
    data_family_count: 0,
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  })
  guard image is Ok(image) else {
    fail("expected finalized physical program: \{Repr(image)}")
  }
  let image = image.image()
  guard image.functions[2]
    is PhysicalBody(
      { blocks: [{ instructions: [CallValue(_, call_abi, _, _, _)], .. }], .. }
    ) &&
    image.functions[3]
    is PhysicalBody(
      { blocks: [{ terminator: TailCallValue(_, tail_abi, _, _), .. }], .. }
    ) else {
    fail("expected finalized indirect calls: \{Repr(image.functions)}")
  }
  let expected_scalar_abi : @physical.CallableAbi = {
    witnesses: [],
    parameters: [{ representation: I32, cleanup: Trivial, kind: ScalarValue, }],
    result: Value(I32, Trivial, ScalarValue),
  }
  let expected_import_abi : @physical.CallableAbi = {
    witnesses: [],
    parameters: [{ representation: I64, cleanup: Trivial, kind: ScalarValue, }],
    result: Value(I64, Trivial, ScalarValue),
  }
  assert_eq(image.callable_abi(call_abi), Some(expected_scalar_abi))
  assert_eq(tail_abi, call_abi)
  assert_eq(image.function_callable_abi_id({ value: 2, }), Some(call_abi))
  assert_eq(
    image.function_callable_abi({ value: 5, }),
    Some(expected_import_abi),
  )
  assert_true(image.function_callable_abi_id({ value: 5, }) is Some(_))
}
