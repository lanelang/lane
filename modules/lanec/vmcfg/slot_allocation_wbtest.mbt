///|
test "physical slot plan follows peak compatible VM CFG liveness" {
  let scalar : ValueMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let plan = allocate_physical_slots({
    values: [scalar, scalar, scalar, scalar],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: @bytecode.Value(I64, Trivial, ScalarValue),
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
    (plan.slots, plan.values),
    content=(
      #|(
      #|  [
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
      #|  [
      #|    Some({ value: 0 }),
      #|    Some({ value: 0 }),
      #|    Some({ value: 1 }),
      #|    Some({ value: 0 }),
      #|  ],
      #|)
    ),
  )
}

///|
test "physical slot plan rejects an active value without a definition" {
  let scalar : ValueMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  try
    allocate_physical_slots({
      values: [scalar],
      inputs: { environment: None, witnesses: [], user_parameters: [] },
      result: @bytecode.Value(I64, Trivial, ScalarValue),
      blocks: [
        {
          parameters: [],
          instructions: [],
          terminator: Return(Some({ value: 0 })),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|PhysicalSlotAllocationCompilerDefect(MissingDefinition({ value: 0 }))
        ),
      )
  } noraise {
    _ => fail("expected an undefined-value compiler defect")
  }
}

///|
test "physical slot plan preserves simultaneous VM CFG definitions" {
  let scalar : ValueMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let plan = allocate_physical_slots({
    values: [scalar, scalar, scalar, scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }],
    },
    result: @bytecode.Unit,
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
    (plan.slots, plan.values),
    content=(
      #|(
      #|  [
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
      #|  [
      #|    Some({ value: 0 }),
      #|    Some({ value: 1 }),
      #|    Some({ value: 0 }),
      #|    Some({ value: 1 }),
      #|  ],
      #|)
    ),
  )
}

///|
test "physical slot plan consumes ARC-final VM CFG values" {
  let owned : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    ownership: Owned,
    erased_companion: None,
  }
  let body = insert_arc({
    values: [owned],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: @bytecode.Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect({ value: 1 }, None, [], [{ value: 0 }], None),
          CallDirect({ value: 1 }, None, [], [{ value: 0 }], None),
        ],
        terminator: Return(None),
      },
    ],
  })
  let plan = allocate_physical_slots(body)
  debug_inspect(
    (body, plan.slots, plan.values),
    content=(
      #|(
      #|  {
      #|    values: [
      #|      {
      #|        representation: I32,
      #|        cleanup: OwnedRef,
      #|        kind: ByteSequenceValue,
      #|        ownership: Owned,
      #|        erased_companion: None,
      #|      },
      #|      {
      #|        representation: I32,
      #|        cleanup: OwnedRef,
      #|        kind: ByteSequenceValue,
      #|        ownership: Owned,
      #|        erased_companion: None,
      #|      },
      #|    ],
      #|    inputs: { environment: None, witnesses: [], user_parameters: [{ value: 0 }] },
      #|    result: Unit,
      #|    blocks: [
      #|      {
      #|        parameters: [],
      #|        instructions: [
      #|          RetainCopy({ value: 1 }, { value: 0 }),
      #|          CallDirect({ value: 1 }, None, [], [{ value: 1 }], None),
      #|          CallDirect({ value: 1 }, None, [], [{ value: 0 }], None),
      #|        ],
      #|        terminator: Return(None),
      #|      },
      #|    ],
      #|  },
      #|  [
      #|    {
      #|      representation: I32,
      #|      cleanup: OwnedRef,
      #|      kind: ByteSequenceValue,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: I32,
      #|      cleanup: OwnedRef,
      #|      kind: ByteSequenceValue,
      #|      erased_companion: None,
      #|    },
      #|  ],
      #|  [Some({ value: 0 }), Some({ value: 1 })],
      #|)
    ),
  )
}
