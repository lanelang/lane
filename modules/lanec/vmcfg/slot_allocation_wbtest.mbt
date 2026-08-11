///|
test "CFG slot allocation follows peak compatible liveness" {
  let scalar : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let allocated = allocate_finalized_slots({
    slots: [scalar, scalar, scalar, scalar],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstI64({ value: 0 }, 42L)],
        terminator: Jump({ target: { value: 1 }, arguments: [{ value: 0 }] }),
      },
      {
        parameters: [{ value: 1 }],
        instructions: [I64Neg({ value: 2 }, { value: 1 })],
        terminator: Jump({ target: { value: 2 }, arguments: [{ value: 2 }] }),
      },
      {
        parameters: [{ value: 3 }],
        instructions: [],
        terminator: Return(Some({ value: 3 })),
      },
    ],
  })
  debug_inspect(
    allocated,
    content=(
      #|{
      #|  slots: [
      #|    {
      #|      representation: I64,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: I64,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|  ],
      #|  inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|  result: Value(I64, Trivial, ScalarValue),
      #|  blocks: [
      #|    {
      #|      parameters: [],
      #|      instructions: [ConstI64({ value: 0 }, 42)],
      #|      terminator: Jump({ target: { value: 1 }, arguments: [{ value: 0 }] }),
      #|    },
      #|    {
      #|      parameters: [{ value: 0 }],
      #|      instructions: [I64Neg({ value: 1 }, { value: 0 })],
      #|      terminator: Jump({ target: { value: 2 }, arguments: [{ value: 1 }] }),
      #|    },
      #|    {
      #|      parameters: [{ value: 0 }],
      #|      instructions: [],
      #|      terminator: Return(Some({ value: 0 })),
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "CFG slot allocation preserves simultaneous input and block parameters" {
  let scalar : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let allocated = allocate_finalized_slots({
    slots: [scalar, scalar, scalar, scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Jump({
          target: { value: 1 },
          arguments: [{ value: 0 }, { value: 1 }],
        }),
      },
      {
        parameters: [{ value: 2 }, { value: 3 }],
        instructions: [],
        terminator: Return(None),
      },
    ],
  })
  debug_inspect(
    allocated,
    content=(
      #|{
      #|  slots: [
      #|    {
      #|      representation: I64,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: I64,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|  ],
      #|  inputs: {
      #|    environment: None,
      #|    witnesses: [],
      #|    user_parameters: [{ value: 0 }, { value: 1 }],
      #|  },
      #|  result: Unit,
      #|  blocks: [
      #|    {
      #|      parameters: [],
      #|      instructions: [],
      #|      terminator: Jump({ target: { value: 1 }, arguments: [{ value: 0 }, { value: 1 }] }),
      #|    },
      #|    {
      #|      parameters: [{ value: 0 }, { value: 1 }],
      #|      instructions: [],
      #|      terminator: Return(None),
      #|    },
      #|  ],
      #|}
    ),
  )
}
