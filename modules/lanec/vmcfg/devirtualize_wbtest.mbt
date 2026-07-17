///|
test "devirtualize uniquely invoked known callables" {
  let body : FunctionBody = {
    values: [
      {
        representation: I64,
        cleanup: OwnedCallable,
        ownership: Owned,
        erased_companion: None,
      },
      {
        representation: I32,
        cleanup: OwnedRef,
        ownership: Owned,
        erased_companion: None,
      },
      scalar_metadata(),
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeClosure({ value: 0 }, { value: 4 }, { value: 1 }),
          CallValue({ value: 0 }, [], [{ value: 2 }], Some({ value: 3 })),
        ],
        terminator: Return(Some({ value: 3 })),
      },
    ],
  }
  debug_inspect(
    devirtualize_body_with_plans(body, []).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [
      #|      CallDirect(
      #|        { value: 4 },
      #|        Some({ value: 1 }),
      #|        [],
      #|        [{ value: 2 }],
      #|        Some({ value: 3 }),
      #|      ),
      #|    ],
      #|    terminator: Return(Some({ value: 3 })),
      #|  },
      #|]
    ),
  )
}

///|
test "devirtualize known tail calls but preserve escaping closures" {
  let body : FunctionBody = {
    values: [
      {
        representation: I64,
        cleanup: OwnedCallable,
        ownership: Owned,
        erased_companion: None,
      },
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [ConstFunction({ value: 0 }, { value: 3 })],
        terminator: TailCallValue({ value: 0 }, [], [{ value: 1 }]),
      },
    ],
  }
  debug_inspect(
    devirtualize_body_with_plans(body, []).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [],
      #|    terminator: TailCallDirect({ value: 3 }, None, [], [{ value: 1 }]),
      #|  },
      #|]
    ),
  )
  let escaping = {
    ..body,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstFunction({ value: 0 }, { value: 3 }),
          CallValue({ value: 0 }, [], [], None),
        ],
        terminator: TailCallValue({ value: 0 }, [], []),
      },
    ],
  }
  assert_eq(devirtualize_body_with_plans(escaping, []), escaping)
}

///|
test "devirtualize immediate closure environment into hidden direct arguments" {
  let owned_reference : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    ownership: Owned,
    erased_companion: None,
  }
  let borrowed_reference : ValueMetadata = {
    ..owned_reference,
    ownership: Borrowed,
  }
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    ownership: Owned,
    erased_companion: None,
  }
  let caller : FunctionBody = {
    values: [owned_reference, callable, owned_reference, scalar_metadata()],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 2 }],
    },
    result: I32,
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeEnv({ value: 0 }, { value: 0 }, Immediate({ value: 0 }), [], [
            { value: 2 },
          ]),
          MakeClosure({ value: 1 }, { value: 2 }, { value: 0 }),
          CallValue({ value: 1 }, [], [], Some({ value: 3 })),
        ],
        terminator: Return(Some({ value: 3 })),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [owned_reference, borrowed_reference],
    inputs: {
      environment: Some({ value: 0 }),
      witnesses: [],
      user_parameters: [],
    },
    result: I32,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowCapture({ value: 0 }, { value: 0 }, 0, {
            value_destination: { value: 1 },
            witness_destination: None,
          }),
        ],
        terminator: Return(Some({ value: 1 })),
      },
    ],
  }
  let image : Image = {
    entry: { value: 1 },
    initializer: None,
    functions: [Body(caller), Body(callee)],
    globals: [],
    layouts: [Environment({ value: 0 })],
    object_shapes: [
      Environment({
        stored_witness_count: 0,
        members: [
          { representation: I32, cleanup: OwnedRef, witness_ordinal: None },
        ],
      }),
    ],
    constants: [],
  }
  let optimized = devirtualize_image(image)
  inspect(optimized.functions.length(), content="2")
  guard optimized.functions[0] is Body(optimized_caller) &&
    optimized.functions[1] is Body(direct_callee) else {
    fail("expected caller and direct callee bodies")
  }
  debug_inspect(
    optimized_caller.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [CallDirect({ value: 2 }, None, [], [{ value: 2 }], Some({ value: 3 }))],
      #|    terminator: Return(Some({ value: 3 })),
      #|  },
      #|]
    ),
  )
  debug_inspect(
    (direct_callee.inputs, direct_callee.values[1], direct_callee.blocks),
    content=(
      #|(
      #|  { environment: None, witnesses: [], user_parameters: [{ value: 1 }] },
      #|  {
      #|    representation: I32,
      #|    cleanup: OwnedRef,
      #|    ownership: Owned,
      #|    erased_companion: None,
      #|  },
      #|  [
      #|    {
      #|      parameters: [],
      #|      instructions: [],
      #|      terminator: Return(Some({ value: 1 })),
      #|    },
      #|  ],
      #|)
    ),
  )
}
