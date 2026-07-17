///|
fn trivial_value(representation : @bytecode.Representation) -> ValueMetadata {
  {
    representation,
    cleanup: Trivial,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
fn owned_ref_value() -> ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn borrowed_ref_value() -> ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    ownership: Borrowed,
    erased_companion: None,
  }
}

///|
fn borrowed_erased_value(companion : ValueId) -> ValueMetadata {
  {
    representation: I64,
    cleanup: OwnedErased,
    ownership: Borrowed,
    erased_companion: Some(companion),
  }
}

///|
fn test_image(body : FunctionBody) -> Image {
  {
    entry: { value: 1 },
    initializer: None,
    functions: [Body(body)],
    globals: [],
    layouts: [String],
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
    finalize({
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
        { representation: I32, cleanup: OwnedRef, erased_companion: None },
      ],
    }) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(image.initializer, Some({ value: 1 }))
  assert_eq(image.globals, [
    { representation: I32, cleanup: OwnedRef, erased_companion: None },
  ])
  assert_eq(lowered.slots.length(), 3)
  assert_eq(lowered.blocks[0].instructions, [
    ConstString({ value: 0 }, { value: 0 }),
    InitGlobal({ value: 0 }, { value: 0 }),
    BorrowGlobal({ value: 1 }, { value: 0 }),
    RetainCopy({ value: 2 }, { value: 1 }),
    CallDirect({ value: 2 }, None, [], [{ value: 2 }], None),
  ])
}

///|
test "finalize preserves erased companions for promoted global borrows" {
  let body : FunctionBody = {
    values: [trivial_value(I32), borrowed_erased_value({ value: 0 })],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowGlobal({ value: 1 }, { value: 1 }),
          CallDirect({ value: 2 }, None, [], [{ value: 1 }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = match
    finalize({
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
    Err(error) => fail("finalize failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.slots, [
    { representation: I32, cleanup: Trivial, erased_companion: None },
    {
      representation: I64,
      cleanup: OwnedErased,
      erased_companion: Some({ value: 0 }),
    },
    {
      representation: I64,
      cleanup: OwnedErased,
      erased_companion: Some({ value: 0 }),
    },
  ])
  assert_eq(lowered.blocks[0].instructions, [
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
    finalize({
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
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
  let image = match finalize(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
    result: I32,
    blocks: [
      {
        parameters: [],
        instructions: [ConstString({ value: 0 }, { value: 0 })],
        terminator: Return(Some({ value: 0 })),
      },
    ],
  }
  let image = match finalize(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
    result: I32,
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
  let image = match finalize(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
          StringLength({ value: 1 }, { value: 0 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = match
    finalize({
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
    Err(error) => fail("finalize failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  assert_eq(lowered.slots.length(), 3)
  assert_eq(lowered.blocks[0].instructions, [
    RetainCopy({ value: 2 }, { value: 0 }),
    CallDirect({ value: 2 }, None, [], [{ value: 2 }], None),
    StringLength({ value: 1 }, { value: 0 }),
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
  let image = match finalize(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
  let image = match finalize(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
    result: I32,
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
  let image = match finalize(test_image(body)) {
    Ok(value) => value
    Err(error) => fail("finalize failed: \{to_repr(error)}")
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
