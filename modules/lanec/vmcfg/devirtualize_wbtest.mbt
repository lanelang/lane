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
      #|      instructions: [
      #|        CallPackedDirect(
      #|          { value: 2 },
      #|          { value: 6 },
      #|          [],
      #|          [],
      #|          Some({ value: 7 }),
      #|        ),
      #|      ],
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

///|
test "callable flow crosses direct function parameters" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let entry : FunctionBody = {
    values: [callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstFunction({ value: 0, }, { value: 3, }),
          CallDirect({ value: 2, }, None, [], [{ value: 0, }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let apply : FunctionBody = {
    values: [callable],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [CallValue({ value: 0, }, [], [], None)],
        terminator: Return(None),
      },
    ],
  }
  let target : FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let optimized = devirtualize_image({
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(entry), Body(apply), Body(target)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  })
  guard optimized.functions[1] is Body(apply) else {
    fail("expected apply body")
  }
  debug_inspect(
    apply.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [CallDirect({ value: 3 }, None, [], [], None)],
      #|    terminator: Return(None),
      #|  },
      #|]
    ),
  )
}

///|
test "exact packed callable parameter devirtualizes in tail position" {
  let environment : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: EnvironmentValue({ value: 0, }),
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
  let entry : FunctionBody = {
    values: [environment, callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
          MakeClosure({ value: 1, }, { value: 3, }, { value: 0, }),
          CallDirect({ value: 2, }, None, [], [{ value: 1, }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let apply : FunctionBody = {
    values: [callable],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: TailCallValue({ value: 0, }, [], []),
      },
    ],
  }
  let target : FunctionBody = {
    values: [environment],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
    ],
  }
  let image : Image = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(entry), Body(apply), Body(target)],
    globals: [],
    layouts: [Environment({ value: 0, })],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
    constants: [],
  }
  let optimized = devirtualize_image(image)
  guard optimized.functions[1] is Body(optimized_apply) &&
    optimized.functions[2] is Body(optimized_target) else {
    fail("expected apply and target bodies")
  }
  debug_inspect(
    (optimized_apply.blocks[0].terminator, optimized_target.inputs.environment),
    content=(
      #|(
      #|  TailCallPackedDirect({ value: 3 }, { value: 0 }, [], []),
      #|  Some({ value: 0 }),
      #|)
    ),
  )
  assert_true(finalize(image) is Ok(_))
}

///|
test "callable flow crosses direct function results" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let entry : FunctionBody = {
    values: [callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect({ value: 2, }, None, [], [], Some({ value: 0, })),
          CallValue({ value: 0, }, [], [], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let produce : FunctionBody = {
    values: [callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, OwnedCallable, CallableValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstFunction({ value: 0, }, { value: 3, })],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let target : FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let optimized = devirtualize_image({
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(entry), Body(produce), Body(target)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  })
  guard optimized.functions[0] is Body(entry) else {
    fail("expected entry body")
  }
  debug_inspect(
    entry.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [
      #|      CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      #|      CallDirect({ value: 3 }, None, [], [], None),
      #|    ],
      #|    terminator: Return(None),
      #|  },
      #|]
    ),
  )
}

///|
test "opaque calls prevent unsound parameter devirtualization" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let entry : FunctionBody = {
    values: [callable, callable, callable, callable],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }, { value: 1, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstFunction({ value: 2, }, { value: 2, }),
          ConstFunction({ value: 3, }, { value: 3, }),
          CallDirect({ value: 2, }, None, [], [{ value: 3, }], None),
          CallValue({ value: 0, }, [], [{ value: 1, }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let apply : FunctionBody = {
    values: [callable],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [CallValue({ value: 0, }, [], [], None)],
        terminator: Return(None),
      },
    ],
  }
  let target : FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let optimized = devirtualize_image({
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(entry), Body(apply), Body(target)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  })
  guard optimized.functions[1] is Body(apply) else {
    fail("expected apply body")
  }
  assert_eq(apply.blocks, [
    {
      parameters: [],
      instructions: [CallValue({ value: 0, }, [], [], None)],
      terminator: Return(None),
    },
  ])
}

///|
test "callable flow represents recursive data as a finite site graph" {
  let data : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 0, }),
    ownership: Owned,
    erased_companion: None,
  }
  let entry : FunctionBody = {
    values: [data, data],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 0, }), [], []),
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 0, }],
            Some({ value: 1, }),
          ),
        ],
        terminator: Return(None),
      },
    ],
  }
  let recursive : FunctionBody = {
    values: [data, data, data],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I32, OwnedRef, DataValue({ value: 0, })),
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeData({ value: 1, }, { value: 1, }, Immediate({ value: 1, }), [], [
            { value: 0, },
          ]),
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 1, }],
            Some({ value: 2, }),
          ),
        ],
        terminator: Return(Some({ value: 1, })),
      },
    ],
  }
  let flow = analyze_callable_flow({
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    functions: [Body(entry), Body(recursive)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  })
  assert_eq(flow.aggregate_sites.length(), 2)
  guard flow.body_facts(1) is Some(facts) &&
    facts.values[0] is KnownAggregates(parameter_sites, _) &&
    flow.results[1] is KnownAggregates(result_sites, _) else {
    fail("expected recursive parameter and result to retain aggregate sites")
  }
  assert_eq((parameter_sites.length(), result_sites.length()), (2, 1))
}

///|
test "stored closures keep their packed environment owner" {
  let string : ValueMetadata = {
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
      string,
      { ..string, kind: EnvironmentValue({ value: 0, }), },
      callable,
      { ..string, kind: DataValue({ value: 0, }), },
      { ..callable, ownership: Borrowed, },
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          MakeEnv({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], [
            { value: 0, },
          ]),
          MakeClosure({ value: 2, }, { value: 2, }, { value: 1, }),
          MakeData({ value: 3, }, { value: 1, }, Immediate({ value: 2, }), [], [
            { value: 2, },
          ]),
          BorrowField({ value: 1, }, { value: 3, }, 0, {
            value_destination: { value: 4, },
            witness_destination: None,
          }),
          CallValue({ value: 4, }, [], [], None),
          Release({ value: 3, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [{ ..string, kind: EnvironmentValue({ value: 0, }), }, string],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConsumeCaptures({ value: 0, }, { value: 0, }, [
            {
              member_index: 0,
              result: {
                value_destination: { value: 1, },
                witness_destination: None,
              },
            },
          ]),
          Release({ value: 1, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image : Image = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    functions: [Body(caller), Body(callee)],
    globals: [],
    layouts: [Environment({ value: 0, }), Data({ value: 1, })],
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
    constants: [b"capture"],
  }
  let optimized = devirtualize_image(image)
  guard optimized.functions[0] is Body(caller) &&
    optimized.functions[1] is Body(callee) else {
    fail("expected caller and callee bodies")
  }
  debug_inspect(
    (caller.blocks[0].instructions[5], callee.inputs.environment),
    content=(
      #|(
      #|  CallPackedDirect({ value: 2 }, { value: 4 }, [], [], None),
      #|  Some({ value: 0 }),
      #|)
    ),
  )
  let finalized = match finalize(image) {
    Ok(program) => program.image()
    Err(error) => fail("finalization failed: \{Repr(error)}")
  }
  guard finalized.functions[0] is PhysicalBody(finalized_caller) else {
    fail("expected finalized caller body")
  }
  debug_inspect(
    finalized_caller.blocks[0].instructions,
    content=(
      #|[
      #|  ConstString({ value: 0 }, { value: 0 }),
      #|  MakeEnv(
      #|    { value: 1 },
      #|    { value: 0 },
      #|    Immediate({ value: 1 }),
      #|    [],
      #|    [{ value: 0 }],
      #|  ),
      #|  MakeClosure({ value: 2 }, { value: 2 }, { value: 1 }),
      #|  MakeData(
      #|    { value: 3 },
      #|    { value: 1 },
      #|    Immediate({ value: 2 }),
      #|    [],
      #|    [{ value: 2 }],
      #|  ),
      #|  BorrowField(
      #|    { value: 1 },
      #|    { value: 3 },
      #|    0,
      #|    { value_destination: { value: 4 }, witness_destination: None },
      #|  ),
      #|  RetainCopy({ value: 2 }, { value: 4 }),
      #|  CallPackedDirect({ value: 2 }, { value: 2 }, [], [], None),
      #|  Release({ value: 3 }),
      #|]
    ),
  )
}
