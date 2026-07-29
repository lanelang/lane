///|
fn bytes_test_trivial_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, erased_companion: None }
}

///|
fn bytes_test_owned_slot() -> @bytecode.SlotMetadata {
  { representation: I32, cleanup: OwnedRef, erased_companion: None }
}

///|
fn bytes_test_body(
  slots : Array[@bytecode.SlotMetadata],
  blocks : Array[@bytecode.Block],
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks,
  }
}

///|
fn execute_bytes_test(
  body : @bytecode.FunctionBody,
) -> Result[Unit, @runtime.ExecutionError] raise {
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [BytecodeBody(body)],
    layouts: [Bytes],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  loaded.new_instance().execute()
}

///|
test "Byte conversion uses the low eight bits for every signed Int range" {
  let i32 = bytes_test_trivial_slot(I32)
  let i64 = bytes_test_trivial_slot(I64)
  let cases : Array[(Int64, Int64)] = [
    (0L, 0L),
    (1L, 1L),
    (255L, 255L),
    (256L, 0L),
    (257L, 1L),
    (-1L, 255L),
    (-255L, 1L),
    (-9223372036854775807L - 1L, 0L),
    (9223372036854775807L, 255L),
  ]
  let blocks : Array[@bytecode.Block] = []
  for index, case in cases {
    blocks.push({
      parameters: [],
      instructions: [
        ConstInt({ value: 0 }, case.0),
        IntToByte({ value: 1 }, { value: 0 }),
        ByteToInt({ value: 2 }, { value: 1 }),
        ConstInt({ value: 3 }, case.1),
        IntEq({ value: 4 }, { value: 2 }, { value: 3 }),
      ],
      terminator: BranchBool(
        { value: 4 },
        { target: { value: index + 1 }, arguments: [] },
        { target: { value: cases.length() + 1 }, arguments: [] },
      ),
    })
  }
  blocks.push({ parameters: [], instructions: [], terminator: Return(None) })
  blocks.push({ parameters: [], instructions: [], terminator: Unreachable })
  let body = bytes_test_body([i64, i32, i64, i64, i32], blocks)
  assert_eq(execute_bytes_test(body), Ok(()))
}

///|
test "Byte conversion and shared Bytes update preserve value semantics" {
  let i32 = bytes_test_trivial_slot(I32)
  let i64 = bytes_test_trivial_slot(I64)
  let owned = bytes_test_owned_slot()
  let slots = [
    i64, i32, i64, i64, owned, owned, i64, i64, i32, owned, i32, i32, i64, i64, i32,
    i64, i64,
  ]
  let block = fn(
    instructions : Array[@bytecode.Instruction],
    terminator : @bytecode.Terminator,
  ) -> @bytecode.Block {
    { parameters: [], instructions, terminator }
  }
  let edge = fn(target : Int) -> @bytecode.Edge {
    { target: { value: target }, arguments: [] }
  }
  let body = bytes_test_body(slots, [
    block(
      [
        ConstInt({ value: 0 }, 511L),
        IntToByte({ value: 1 }, { value: 0 }),
        ByteToInt({ value: 2 }, { value: 1 }),
        ConstInt({ value: 15 }, 255L),
        IntEq({ value: 14 }, { value: 2 }, { value: 15 }),
      ],
      BranchBool({ value: 14 }, edge(1), edge(5)),
    ),
    block(
      [
        ConstInt({ value: 3 }, 2L),
        BytesMake({ value: 4 }, { value: 3 }, { value: 1 }),
        BytesLength({ value: 16 }, { value: 4 }),
        IntEq({ value: 14 }, { value: 16 }, { value: 3 }),
      ],
      BranchBool({ value: 14 }, edge(2), edge(5)),
    ),
    block(
      [
        RetainCopy({ value: 5 }, { value: 4 }),
        ConstInt({ value: 6 }, 1L),
        ConstInt({ value: 7 }, 0L),
        IntToByte({ value: 8 }, { value: 7 }),
        BytesSet({ value: 9 }, { value: 4 }, { value: 6 }, { value: 8 }),
        BytesGet({ value: 10 }, { value: 5 }, { value: 6 }),
        BytesGet({ value: 11 }, { value: 9 }, { value: 6 }),
        ByteToInt({ value: 12 }, { value: 10 }),
        ByteToInt({ value: 13 }, { value: 11 }),
        IntEq({ value: 14 }, { value: 12 }, { value: 15 }),
      ],
      BranchBool({ value: 14 }, edge(3), edge(5)),
    ),
    block(
      [IntEq({ value: 14 }, { value: 13 }, { value: 7 })],
      BranchBool({ value: 14 }, edge(4), edge(5)),
    ),
    block([Release({ value: 5 }), Release({ value: 9 })], Return(None)),
    block([], Unreachable),
  ])
  assert_eq(execute_bytes_test(body), Ok(()))
}

///|
test "unique Bytes update transfers the original owner" {
  let i32 = bytes_test_trivial_slot(I32)
  let i64 = bytes_test_trivial_slot(I64)
  let owned = bytes_test_owned_slot()
  let body = bytes_test_body(
    [i64, i64, i32, owned, owned, i32, i64, i64, i32, i64],
    [
      {
        parameters: [],
        instructions: [
          ConstInt({ value: 0 }, 1L),
          ConstInt({ value: 1 }, 258L),
          ConstInt({ value: 9 }, 0L),
          IntToByte({ value: 2 }, { value: 1 }),
          BytesMake({ value: 3 }, { value: 0 }, { value: 2 }),
          BytesSet({ value: 4 }, { value: 3 }, { value: 9 }, { value: 2 }),
          BytesGet({ value: 5 }, { value: 4 }, { value: 9 }),
          ByteToInt({ value: 6 }, { value: 5 }),
          ConstInt({ value: 7 }, 2L),
          IntEq({ value: 8 }, { value: 6 }, { value: 7 }),
        ],
        terminator: BranchBool(
          { value: 8 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 2 }, arguments: [] },
        ),
      },
      {
        parameters: [],
        instructions: [Release({ value: 4 })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  )
  assert_eq(execute_bytes_test(body), Ok(()))
}

///|
test "Bytes primitives trap on invalid length and index" {
  let i32 = bytes_test_trivial_slot(I32)
  let i64 = bytes_test_trivial_slot(I64)
  let owned = bytes_test_owned_slot()
  let negative_length = bytes_test_body([i64, i32, owned], [
    {
      parameters: [],
      instructions: [
        ConstInt({ value: 0 }, -1L),
        IntToByte({ value: 1 }, { value: 0 }),
        BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
      ],
      terminator: Return(None),
    },
  ])
  assert_eq(
    execute_bytes_test(negative_length),
    Err(EngineTrap(detail="Bytes length is out of range")),
  )
  let invalid_index_body = fn(index : Int64, update : Bool) {
    let instructions : Array[@bytecode.Instruction] = [
      ConstInt({ value: 0 }, 1L),
      IntToByte({ value: 1 }, { value: 0 }),
      BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
      ConstInt({ value: 3 }, index),
    ]
    if update {
      instructions.push(
        BytesSet({ value: 4 }, { value: 2 }, { value: 3 }, { value: 1 }),
      )
    } else {
      instructions.push(BytesGet({ value: 4 }, { value: 2 }, { value: 3 }))
    }
    bytes_test_body([i64, i32, owned, i64, if update { owned } else { i32 }], [
      { parameters: [], instructions, terminator: Return(None) },
    ])
  }
  for case in [(-1L, false), (1L, false), (-1L, true), (1L, true)] {
    assert_eq(
      execute_bytes_test(invalid_index_body(case.0, case.1)),
      Err(EngineTrap(detail="Bytes index is out of bounds")),
    )
  }
}
