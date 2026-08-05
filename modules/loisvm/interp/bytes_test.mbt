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
  config? : @runtime.ExecutionConfig = @runtime.ExecutionConfig::defaults(),
  constants? : Array[Bytes] = [],
) -> Result[Unit, @runtime.ExecutionError] raise {
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(body)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants,
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  loaded.new_instance(config~).execute()
}

///|
test "Byte conversion uses the low eight bits for every signed I64 range" {
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
        ConstI64({ value: 0 }, case.0),
        I64ToByte({ value: 1 }, { value: 0 }),
        ByteToI64({ value: 2 }, { value: 1 }),
        ConstI64({ value: 3 }, case.1),
        I64Eq({ value: 4 }, { value: 2 }, { value: 3 }),
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
        ConstI64({ value: 0 }, 511L),
        I64ToByte({ value: 1 }, { value: 0 }),
        ByteToI64({ value: 2 }, { value: 1 }),
        ConstI64({ value: 15 }, 255L),
        I64Eq({ value: 14 }, { value: 2 }, { value: 15 }),
      ],
      BranchBool({ value: 14 }, edge(1), edge(5)),
    ),
    block(
      [
        ConstI64({ value: 3 }, 2L),
        ByteSequenceMake({ value: 4 }, { value: 3 }, { value: 1 }),
        ByteSequenceLength({ value: 16 }, { value: 4 }),
        I64Eq({ value: 14 }, { value: 16 }, { value: 3 }),
      ],
      BranchBool({ value: 14 }, edge(2), edge(5)),
    ),
    block(
      [
        RetainCopy({ value: 5 }, { value: 4 }),
        ConstI64({ value: 6 }, 1L),
        ConstI64({ value: 7 }, 0L),
        I64ToByte({ value: 8 }, { value: 7 }),
        ByteSequenceSet({ value: 9 }, { value: 4 }, { value: 6 }, { value: 8 }),
        ByteSequenceGet({ value: 10 }, { value: 5 }, { value: 6 }),
        ByteSequenceGet({ value: 11 }, { value: 9 }, { value: 6 }),
        ByteToI64({ value: 12 }, { value: 10 }),
        ByteToI64({ value: 13 }, { value: 11 }),
        I64Eq({ value: 14 }, { value: 12 }, { value: 15 }),
      ],
      BranchBool({ value: 14 }, edge(3), edge(5)),
    ),
    block(
      [I64Eq({ value: 14 }, { value: 13 }, { value: 7 })],
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
          ConstI64({ value: 0 }, 1L),
          ConstI64({ value: 1 }, 258L),
          ConstI64({ value: 9 }, 0L),
          I64ToByte({ value: 2 }, { value: 1 }),
          ByteSequenceMake({ value: 3 }, { value: 0 }, { value: 2 }),
          ByteSequenceSet({ value: 4 }, { value: 3 }, { value: 9 }, { value: 2 }),
          ByteSequenceGet({ value: 5 }, { value: 4 }, { value: 9 }),
          ByteToI64({ value: 6 }, { value: 5 }),
          ConstI64({ value: 7 }, 2L),
          I64Eq({ value: 8 }, { value: 6 }, { value: 7 }),
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
        ConstI64({ value: 0 }, -1L),
        I64ToByte({ value: 1 }, { value: 0 }),
        ByteSequenceMake({ value: 2 }, { value: 0 }, { value: 1 }),
      ],
      terminator: Unreachable,
    },
  ])
  assert_eq(
    execute_bytes_test(negative_length),
    Err(EngineTrap(detail="ByteSequence length is out of range")),
  )
  let invalid_index_body = fn(index : Int64, update : Bool) {
    let instructions : Array[@bytecode.Instruction] = [
      ConstI64({ value: 0 }, 1L),
      I64ToByte({ value: 1 }, { value: 0 }),
      ByteSequenceMake({ value: 2 }, { value: 0 }, { value: 1 }),
      ConstI64({ value: 3 }, index),
    ]
    if update {
      instructions.push(
        ByteSequenceSet({ value: 4 }, { value: 2 }, { value: 3 }, { value: 1 }),
      )
    } else {
      instructions.push(
        ByteSequenceGet({ value: 4 }, { value: 2 }, { value: 3 }),
      )
    }
    bytes_test_body([i64, i32, owned, i64, if update { owned } else { i32 }], [
      { parameters: [], instructions, terminator: Unreachable },
    ])
  }
  for case in [(-1L, false), (1L, false), (-1L, true), (1L, true)] {
    assert_eq(
      execute_bytes_test(invalid_index_body(case.0, case.1)),
      Err(EngineTrap(detail="ByteSequence index is out of bounds")),
    )
  }
}

///|
test "ByteSequence equality concatenation and slicing share one representation" {
  let i32 = bytes_test_trivial_slot(I32)
  let i64 = bytes_test_trivial_slot(I64)
  let owned = bytes_test_owned_slot()
  let body = bytes_test_body(
    [owned, owned, owned, i64, i64, owned, owned, i32],
    [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          ConstI64({ value: 3 }, 1L),
          ConstI64({ value: 4 }, 4L),
          ByteSequenceSlice({ value: 5 }, { value: 2 }, { value: 3 }, {
            value: 4,
          }),
          ConstString({ value: 6 }, { value: 2 }),
          ByteSequenceEqual({ value: 7 }, { value: 5 }, { value: 6 }),
          Release({ value: 5 }),
          Release({ value: 6 }),
        ],
        terminator: BranchBool(
          { value: 7 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 2 }, arguments: [] },
        ),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  )
  assert_eq(
    execute_bytes_test(body, constants=[
      Bytes::from_array([b'a', b'b']),
      Bytes::from_array([b'c', b'd', b'e']),
      Bytes::from_array([b'b', b'c', b'd', b'e']),
    ]),
    Ok(()),
  )
}

///|
test "ByteSequence UTF-8 validation rejects every malformed sequence class" {
  let i32 = bytes_test_trivial_slot(I32)
  let owned = bytes_test_owned_slot()
  let cases : Array[(Bytes, Bool)] = [
    (Bytes::from_array([]), true),
    (Bytes::from_array([b'a']), true),
    (Bytes::from_array([b'\xC2', b'\xA2']), true),
    (Bytes::from_array([b'\xE4', b'\xB8', b'\xAD']), true),
    (Bytes::from_array([b'\xF0', b'\x9F', b'\x98', b'\x80']), true),
    (Bytes::from_array([b'\x80']), false),
    (Bytes::from_array([b'\xC0', b'\x80']), false),
    (Bytes::from_array([b'\xC2']), false),
    (Bytes::from_array([b'\xE0', b'\x80', b'\x80']), false),
    (Bytes::from_array([b'\xED', b'\xA0', b'\x80']), false),
    (Bytes::from_array([b'\xF0', b'\x80', b'\x80', b'\x80']), false),
    (Bytes::from_array([b'\xF4', b'\x90', b'\x80', b'\x80']), false),
    (Bytes::from_array([b'\xF5', b'\x80', b'\x80', b'\x80']), false),
  ]
  let blocks : Array[@bytecode.Block] = []
  for index, case in cases {
    blocks.push({
      parameters: [],
      instructions: [
        ConstString({ value: 0 }, { value: index }),
        ByteSequenceIsValidUtf8({ value: 1 }, { value: 0 }),
        ConstBool({ value: 2 }, case.1),
        BoolEq({ value: 3 }, { value: 1 }, { value: 2 }),
        Release({ value: 0 }),
      ],
      terminator: BranchBool(
        { value: 3 },
        { target: { value: index + 1 }, arguments: [] },
        { target: { value: cases.length() + 1 }, arguments: [] },
      ),
    })
  }
  blocks.push({ parameters: [], instructions: [], terminator: Return(None) })
  blocks.push({ parameters: [], instructions: [], terminator: Unreachable })
  assert_eq(
    execute_bytes_test(
      bytes_test_body([owned, i32, i32, i32], blocks),
      constants=cases.map(case => case.0),
    ),
    Ok(()),
  )
}

///|
test "Bytes layout preflight determines the large length limit" {
  let i32 = bytes_test_trivial_slot(I32)
  let i64 = bytes_test_trivial_slot(I64)
  let owned = bytes_test_owned_slot()
  let body = bytes_test_body([i64, i32, owned], [
    {
      parameters: [],
      instructions: [
        ConstI64({ value: 0 }, 2147483636L),
        I64ToByte({ value: 1 }, { value: 0 }),
        ByteSequenceMake({ value: 2 }, { value: 0 }, { value: 1 }),
      ],
      terminator: Unreachable,
    },
  ])
  assert_eq(
    execute_bytes_test(body, config={
      max_call_depth: None,
      max_live_heap_bytes: Some(15),
      max_host_objects: None,
    }),
    Err(ExecutionResourceLimit(kind=LiveHeapBytes)),
  )
}
