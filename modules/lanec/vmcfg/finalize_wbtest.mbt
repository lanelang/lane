///|
fn trivial_value(representation : @bytecode.Representation) -> ValueMetadata {
  {
    representation,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
fn owned_ref_value() -> ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn borrowed_ref_value() -> ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    ownership: Borrowed,
    erased_companion: None,
  }
}

///|
fn borrowed_erased_value(companion : ValueId) -> ValueMetadata {
  {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    ownership: Borrowed,
    erased_companion: Some(companion),
  }
}

///|
fn test_image(body : FunctionBody) -> Image {
  {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    functions: [Body(body)],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"Lane"],
  }
}

///|
test "finalize transfers global owners and promotes global borrows" {
  let body : FunctionBody = {
    values: [owned_ref_value(), borrowed_ref_value()],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0 }, { value: 0 }),
          InitGlobal({ value: 0 }, { value: 0 }),
          BorrowGlobal({ value: 1 }, { value: 0 }),
          CallDirect({ value: 2 }, None, [], [{ value: 1 }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = match
    finalize_without_bytecode_verification({
      ..test_image(body),
      initializer: Some({ value: 1 }),
      functions: [
        Body(body),
        RuntimeImport({
          abi_major: 1,
          parameters: [String],
          result: Unit,
          symbol: "lane.test.consume",
        }),
      ],
      globals: [
        {
          representation: I32,
          cleanup: OwnedRef,
          kind: ByteSequenceValue,
          erased_companion: None,
        },
      ],
    }) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(image.initializer, Some({ value: 1 }))
  assert_eq(image.globals, [
    {
      representation: I32,
      cleanup: OwnedRef,
      kind: ByteSequenceValue,
      erased_companion: None,
    },
  ])
  assert_eq(lowered.slots.length(), 2)
  assert_eq(lowered.blocks[0].instructions, [
    ConstString({ value: 0 }, { value: 0 }),
    InitGlobal({ value: 0 }, { value: 0 }),
    BorrowGlobal({ value: 1 }, { value: 0 }),
    RetainCopy({ value: 0 }, { value: 1 }),
    CallDirect({ value: 2 }, None, [], [{ value: 0 }], None),
  ])
}

///|
test "finalize preserves erased companions for promoted global borrows" {
  let body : FunctionBody = {
    values: [
      { ..trivial_value(I32), kind: LayoutValue },
      borrowed_erased_value({ value: 0 }),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0 }, { value: 1 }),
          BorrowGlobal({ value: 1 }, { value: 1 }),
          CallDirect({ value: 2 }, None, [], [{ value: 1 }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = match
    finalize_without_bytecode_verification({
      ..test_image(body),
      functions: [
        Body(body),
        RuntimeImport({
          abi_major: 1,
          parameters: [Opaque],
          result: Unit,
          symbol: "lane.test.consume_erased",
        }),
      ],
    }) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.slots, [
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
      erased_companion: Some({ value: 0 }),
    },
    {
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
      erased_companion: Some({ value: 0 }),
    },
  ])
  assert_eq(lowered.blocks[0].instructions, [
    ConstLayout({ value: 0 }, { value: 1 }),
    BorrowGlobal({ value: 1 }, { value: 1 }),
    RetainCopy({ value: 2 }, { value: 1 }),
    CallDirect({ value: 2 }, None, [], [{ value: 2 }], None),
  ])
}

///|
test "finalize promotes a borrowed call argument to an owner" {
  let body : FunctionBody = {
    values: [borrowed_ref_value()],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [CallDirect({ value: 2 }, None, [], [{ value: 0 }], None)],
        terminator: Return(None),
      },
    ],
  }
  let image = match
    finalize_without_bytecode_verification({
      ..test_image(body),
      functions: [
        Body(body),
        RuntimeImport({
          abi_major: 1,
          parameters: [String],
          result: Unit,
          symbol: "lane.test.consume",
        }),
      ],
    }) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.slots.length(), 2)
  assert_eq(lowered.blocks[0].instructions, [
    RetainCopy({ value: 1 }, { value: 0 }),
    CallDirect({ value: 2 }, None, [], [{ value: 1 }], None),
  ])
}

///|
test "indirect call ABI uses the finalized owned argument slot" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let body : FunctionBody = {
    values: [callable, borrowed_ref_value()],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [CallValue({ value: 0 }, [], [{ value: 1 }], None)],
        terminator: Return(None),
      },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(image.callable_abis, [
    {
      witnesses: [],
      parameters: [
        { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
      ],
      result: Unit,
    },
    {
      witnesses: [],
      parameters: [
        { representation: I64, cleanup: OwnedCallable, kind: CallableValue },
        { representation: I32, cleanup: Trivial, kind: ByteSequenceValue },
      ],
      result: Unit,
    },
  ])
  assert_eq(lowered.blocks[0].instructions, [
    RetainCopy({ value: 2 }, { value: 1 }),
    CallValue({ value: 0 }, { value: 0 }, [], [{ value: 2 }], None),
  ])
}

///|
test "finalize releases an owned value left live at return" {
  let body : FunctionBody = {
    values: [owned_ref_value()],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstString({ value: 0 }, { value: 0 })],
        terminator: Return(None),
      },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks[0].instructions, [
    ConstString({ value: 0 }, { value: 0 }),
    Release({ value: 0 }),
  ])
}

///|
test "finalize transfers an owned return without releasing it" {
  let body : FunctionBody = {
    values: [owned_ref_value()],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Value(I32, OwnedRef, ByteSequenceValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstString({ value: 0 }, { value: 0 })],
        terminator: Return(Some({ value: 0 })),
      },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks[0].instructions, [
    ConstString({ value: 0 }, { value: 0 }),
  ])
}

///|
test "finalize preserves object witness loads as non-consuming reads" {
  let body : FunctionBody = {
    values: [owned_ref_value(), trivial_value(I32)],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          LoadObjectWitness({ value: 1 }, { value: 0 }, { value: 0 }, 2),
        ],
        terminator: Return(Some({ value: 1 })),
      },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks[0].instructions, [
    LoadObjectWitness({ value: 1 }, { value: 0 }, { value: 0 }, 2),
    Release({ value: 0 }),
  ])
}

///|
test "finalize retains an owned call argument that is used afterward" {
  let body : FunctionBody = {
    values: [owned_ref_value(), trivial_value(I64)],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect({ value: 2 }, None, [], [{ value: 0 }], None),
          ByteSequenceLength({ value: 1 }, { value: 0 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = match
    finalize_without_bytecode_verification({
      ..test_image(body),
      functions: [
        Body(body),
        RuntimeImport({
          abi_major: 1,
          parameters: [String],
          result: Unit,
          symbol: "lane.test.consume",
        }),
      ],
    }) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.slots.length(), 3)
  assert_eq(lowered.blocks[0].instructions, [
    RetainCopy({ value: 2 }, { value: 0 }),
    CallDirect({ value: 2 }, None, [], [{ value: 2 }], None),
    ByteSequenceLength({ value: 1 }, { value: 0 }),
    Release({ value: 0 }),
  ])
}

///|
test "finalize inserts path-specific releases for owned values at a branch" {
  let body : FunctionBody = {
    values: [owned_ref_value(), trivial_value(I32)],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 1 }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstString({ value: 0 }, { value: 0 })],
        terminator: BranchBool(
          { value: 1 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 1 }, arguments: [] },
        ),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks.length(), 4)
  assert_eq(
    lowered.blocks[0].terminator,
    BranchBool({ value: 1 }, { target: { value: 2 }, arguments: [] }, {
      target: { value: 3 },
      arguments: [],
    }),
  )
  assert_eq(lowered.blocks[2], {
    parameters: [],
    instructions: [Release({ value: 0 })],
    terminator: Jump({ target: { value: 1 }, arguments: [] }),
  })
  assert_eq(lowered.blocks[3], {
    parameters: [],
    instructions: [Release({ value: 0 })],
    terminator: Jump({ target: { value: 1 }, arguments: [] }),
  })
}

///|
test "finalize inserts path-specific releases for every switch edge" {
  let body : FunctionBody = {
    values: [owned_ref_value(), trivial_value(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0 }, { value: 0 }),
          ConstBool({ value: 1 }, true),
        ],
        terminator: SwitchTag(
          { value: 1 },
          [
            { target: { value: 1 }, arguments: [] },
            { target: { value: 1 }, arguments: [] },
          ],
          { target: { value: 1 }, arguments: [] },
        ),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks.length(), 5)
  assert_eq(
    lowered.blocks[0].terminator,
    SwitchTag(
      { value: 1 },
      [
        { target: { value: 2 }, arguments: [] },
        { target: { value: 3 }, arguments: [] },
      ],
      { target: { value: 4 }, arguments: [] },
    ),
  )
  for block in lowered.blocks[2:] {
    assert_eq(block.instructions, [Release({ value: 0 })])
  }
}

///|
test "finalize threads an owned function input into its using branch" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let body : FunctionBody = {
    values: [trivial_value(I32), callable, trivial_value(I32)],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }],
    },
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool(
          { value: 0 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 2 }, arguments: [] },
        ),
      },
      {
        parameters: [],
        instructions: [],
        terminator: TailCallValue({ value: 1 }, [], []),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 2 }, false)],
        terminator: Return(Some({ value: 2 })),
      },
    ],
  }
  let image = match finalize_without_bytecode_verification(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks[1].parameters, [{ value: 1 }])
  assert_eq(
    lowered.blocks[0].terminator,
    BranchBool(
      { value: 0 },
      { target: { value: 1 }, arguments: [{ value: 1 }] },
      { target: { value: 3 }, arguments: [] },
    ),
  )
  assert_eq(lowered.blocks[3].instructions, [Release({ value: 1 })])
}

///|
test "finalize rejects a borrowed function input used across blocks" {
  let body : FunctionBody = {
    values: [
      trivial_value(I32),
      borrowed_ref_value(),
      trivial_value(I64),
      trivial_value(I64),
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool(
          { value: 0 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 2 }, arguments: [] },
        ),
      },
      {
        parameters: [],
        instructions: [ByteSequenceLength({ value: 2 }, { value: 1 })],
        terminator: Return(Some({ value: 2 })),
      },
      {
        parameters: [],
        instructions: [ConstI64({ value: 3 }, 0)],
        terminator: Return(Some({ value: 3 })),
      },
    ],
  }
  assert_eq(
    finalize_without_bytecode_verification(test_image(body)),
    Err(IllegalValueMetadata(value={ value: 1 })),
  )
}

///|
test "finalize promotes a borrowed global before it crosses a branch" {
  let borrowed_callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Borrowed,
    erased_companion: None,
  }
  let body : FunctionBody = {
    values: [trivial_value(I32), borrowed_callable],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [BorrowGlobal({ value: 1 }, { value: 0 })],
        terminator: BranchBool(
          { value: 0 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 2 }, arguments: [] },
        ),
      },
      {
        parameters: [],
        instructions: [],
        terminator: TailCallValue({ value: 1 }, [], []),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
    ],
  }
  let image = match
    finalize_without_bytecode_verification({
      ..test_image(body),
      globals: [
        {
          representation: I64,
          cleanup: OwnedCallable,
          kind: CallableValue,
          erased_companion: None,
        },
      ],
    }) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.blocks[0].instructions, [
    BorrowGlobal({ value: 2 }, { value: 0 }),
    RetainCopy({ value: 1 }, { value: 2 }),
  ])
  assert_eq(lowered.blocks[1].parameters, [{ value: 1 }])
  assert_eq(
    lowered.blocks[0].terminator,
    BranchBool(
      { value: 0 },
      { target: { value: 1 }, arguments: [{ value: 1 }] },
      { target: { value: 3 }, arguments: [] },
    ),
  )
  assert_eq(lowered.blocks[3], {
    parameters: [],
    instructions: [Release({ value: 1 })],
    terminator: Jump({ target: { value: 2 }, arguments: [] }),
  })
}
