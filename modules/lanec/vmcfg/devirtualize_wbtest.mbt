///|
fn devirtualize_test_body(
  body : FunctionBody,
) -> FunctionBody raise FinalizeError {
  let image = devirtualize_image({
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  })
  guard image.functions[0] is Body(body) else {
    abort("expected devirtualized function body")
  }
  body
}

///|
test "devirtualize uniquely invoked known callables" {
  let body : FunctionBody = {
    values: [
      {
        representation: I64,
        cleanup: OwnedCallable,
        kind: CallableValue,
        ownership: Owned,
        erased_companion: None,
      },
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: EnvironmentValue({ value: 0, }),
        ownership: Owned,
        erased_companion: None,
      },
      scalar_metadata(),
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeClosure({ value: 0, }, { value: 4, }, { value: 1, }),
          CallValue({ value: 0, }, [], [{ value: 2, }], Some({ value: 3, })),
        ],
        terminator: Return(Some({ value: 3, })),
      },
    ],
  }
  debug_inspect(
    devirtualize_test_body(body).blocks,
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
test "devirtualize known callables across multiple invocation sites" {
  let body : FunctionBody = {
    values: [
      {
        representation: I64,
        cleanup: OwnedCallable,
        kind: CallableValue,
        ownership: Owned,
        erased_companion: None,
      },
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstFunction({ value: 0, }, { value: 3, })],
        terminator: TailCallValue({ value: 0, }, [], [{ value: 1, }]),
      },
    ],
  }
  debug_inspect(
    devirtualize_test_body(body).blocks,
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
          ConstFunction({ value: 0, }, { value: 3, }),
          CallValue({ value: 0, }, [], [], None),
        ],
        terminator: TailCallValue({ value: 0, }, [], []),
      },
    ],
  }
  debug_inspect(
    devirtualize_test_body(escaping).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [CallDirect({ value: 3 }, None, [], [], None)],
      #|    terminator: TailCallDirect({ value: 3 }, None, [], []),
      #|  },
      #|]
    ),
  )
}

///|
test "devirtualize immediate closure environment into hidden direct arguments" {
  let owned_reference : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
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
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let caller : FunctionBody = {
    values: [
      { ..owned_reference, kind: EnvironmentValue({ value: 0, }), },
      callable,
      owned_reference,
      owned_reference,
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 2, }],
    },
    result: Value(I32, OwnedRef, ByteSequenceValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 0, }), [], [
            { value: 2, },
          ]),
          MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
          CallValue({ value: 1, }, [], [], Some({ value: 3, })),
        ],
        terminator: Return(Some({ value: 3, })),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [
      { ..owned_reference, kind: EnvironmentValue({ value: 0, }), },
      borrowed_reference,
    ],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Value(I32, OwnedRef, ByteSequenceValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowCapture({ value: 0, }, { value: 0, }, 0, {
            value_destination: { value: 1, },
            witness_destination: None,
          }),
        ],
        terminator: Return(Some({ value: 1, })),
      },
    ],
  }
  let image : Image = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(caller), Body(callee)],
    globals: [],
    layouts: [Environment({ value: 0, })],
    object_shapes: [
      Environment({
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
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
      #|    kind: ByteSequenceValue,
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

///|
test "environment ABI remains packed when one target has multiple environments" {
  let owned_reference : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    ownership: Owned,
    erased_companion: None,
  }
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let caller : FunctionBody = {
    values: [
      owned_reference,
      { ..owned_reference, kind: EnvironmentValue({ value: 0, }), },
      callable,
      { ..owned_reference, kind: EnvironmentValue({ value: 0, }), },
      callable,
      scalar_metadata(),
      callable,
      owned_reference,
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }, { value: 5, }],
    },
    result: Value(I32, OwnedRef, ByteSequenceValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeEnv({ value: 1, }, { value: 0, }, Immediate({ value: 0, }), [], [
            { value: 0, },
          ]),
          MakeClosure({ value: 2, }, { value: 2, }, { value: 1, }),
          MakeEnv({ value: 3, }, { value: 0, }, Immediate({ value: 0, }), [], [
            { value: 0, },
          ]),
          MakeClosure({ value: 4, }, { value: 2, }, { value: 3, }),
        ],
        terminator: BranchBool(
          { value: 5, },
          { target: { value: 1, }, arguments: [{ value: 2, }], },
          { target: { value: 1, }, arguments: [{ value: 4, }], },
        ),
      },
      {
        parameters: [{ value: 6, }],
        instructions: [CallValue({ value: 6, }, [], [], Some({ value: 7, }))],
        terminator: Return(Some({ value: 7, })),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [
      { ..owned_reference, kind: EnvironmentValue({ value: 0, }), },
      { ..owned_reference, ownership: Borrowed, },
    ],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Value(I32, OwnedRef, ByteSequenceValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowCapture({ value: 0, }, { value: 0, }, 0, {
            value_destination: { value: 1, },
            witness_destination: None,
          }),
        ],
        terminator: Return(Some({ value: 1, })),
      },
    ],
  }
  let optimized = devirtualize_image({
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(caller), Body(callee)],
    globals: [],
    layouts: [Environment({ value: 0, })],
    object_shapes: [
      Environment({
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
    constants: [],
  })
  guard optimized.functions[0] is Body(optimized_caller) &&
    optimized.functions[1] is Body(optimized_callee) else {
    fail("expected caller and callee bodies")
  }
  debug_inspect(
    (optimized_caller.blocks, optimized_callee.inputs),
    content=(
      #|(
      #|  [
      #|    {
      #|      parameters: [],
      #|      instructions: [
      #|        MakeEnv(
      #|          { value: 1 },
      #|          { value: 0 },
      #|          Immediate({ value: 0 }),
      #|          [],
      #|          [{ value: 0 }],
      #|        ),
      #|        MakeClosure({ value: 2 }, { value: 2 }, { value: 1 }),
      #|        MakeEnv(
      #|          { value: 3 },
      #|          { value: 0 },
      #|          Immediate({ value: 0 }),
      #|          [],
      #|          [{ value: 0 }],
      #|        ),
      #|        MakeClosure({ value: 4 }, { value: 2 }, { value: 3 }),
      #|      ],
      #|      terminator: BranchBool(
      #|        { value: 5 },
      #|        { target: { value: 1 }, arguments: [{ value: 2 }] },
      #|        { target: { value: 1 }, arguments: [{ value: 4 }] },
      #|      ),
      #|    },
      #|    {
      #|      parameters: [{ value: 6 }],
      #|      instructions: [CallValue({ value: 6 }, [], [], Some({ value: 7 }))],
      #|      terminator: Return(Some({ value: 7 })),
      #|    },
      #|  ],
      #|  {
      #|    environment: Some({ value: 0 }),
      #|    witnesses: [],
      #|    user_parameters: [],
      #|  },
      #|)
    ),
  )
}

///|
test "callable flow crosses block parameters without adjacency" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let body : FunctionBody = {
    values: [callable, callable, scalar_metadata(), callable, callable],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 2, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstFunction({ value: 0, }, { value: 7, })],
        terminator: BranchBool(
          { value: 2, },
          { target: { value: 1, }, arguments: [{ value: 0, }], },
          { target: { value: 2, }, arguments: [{ value: 0, }], },
        ),
      },
      {
        parameters: [{ value: 1, }],
        instructions: [],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [{ value: 3, }],
        instructions: [],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 3, }], }),
      },
      {
        parameters: [{ value: 4, }],
        instructions: [CallValue({ value: 4, }, [], [], None)],
        terminator: Return(None),
      },
    ],
  }
  debug_inspect(
    devirtualize_test_body(body).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [ConstFunction({ value: 0 }, { value: 7 })],
      #|    terminator: BranchBool(
      #|      { value: 2 },
      #|      { target: { value: 1 }, arguments: [{ value: 0 }] },
      #|      { target: { value: 2 }, arguments: [{ value: 0 }] },
      #|    ),
      #|  },
      #|  {
      #|    parameters: [{ value: 1 }],
      #|    instructions: [],
      #|    terminator: Jump({ target: { value: 3 }, arguments: [{ value: 1 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 3 }],
      #|    instructions: [],
      #|    terminator: Jump({ target: { value: 3 }, arguments: [{ value: 3 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 4 }],
      #|    instructions: [CallDirect({ value: 7 }, None, [], [], None)],
      #|    terminator: Return(None),
      #|  },
      #|]
    ),
  )
}

///|
test "callable flow crosses immutable aggregate globals" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let data : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 0, }),
    ownership: Owned,
    erased_companion: None,
  }
  let borrowed_data = { ..data, ownership: Borrowed, }
  let borrowed_callable = { ..callable, ownership: Borrowed, }
  let initializer : FunctionBody = {
    values: [callable, data],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstFunction({ value: 0, }, { value: 5, }),
          MakeData({ value: 1, }, { value: 0, }, Immediate({ value: 0, }), [], [
            { value: 0, },
          ]),
          InitGlobal({ value: 0, }, { value: 1, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let consumer : FunctionBody = {
    values: [borrowed_data, borrowed_callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowGlobal({ value: 0, }, { value: 0, }),
          BorrowField({ value: 0, }, { value: 0, }, 0, {
            value_destination: { value: 1, },
            witness_destination: None,
          }),
          CallValue({ value: 1, }, [], [], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let optimized = devirtualize_image({
    entry: { value: 2, },
    initializer: Some({ value: 1, }),
    data_family_count: 1,
    functions: [Body(initializer), Body(consumer)],
    globals: [
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: DataValue({ value: 0, }),
        erased_companion: None,
      },
    ],
    layouts: [Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          {
            representation: I64,
            cleanup: OwnedCallable,
            kind: CallableValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
    constants: [],
  })
  guard optimized.functions[1] is Body(consumer) else {
    fail("expected consumer body")
  }
  debug_inspect(
    consumer.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [
      #|      BorrowGlobal({ value: 0 }, { value: 0 }),
      #|      BorrowField(
      #|        { value: 0 },
      #|        { value: 0 },
      #|        0,
      #|        { value_destination: { value: 1 }, witness_destination: None },
      #|      ),
      #|      CallDirect({ value: 5 }, None, [], [], None),
      #|    ],
      #|    terminator: Return(None),
      #|  },
      #|]
    ),
  )
}
