///|
fn wasm_bytes_trivial_slot(
  representation : @physical.Representation,
) -> @physical.SlotMetadata {
  {
    representation,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
}

///|
fn wasm_bytes_owned_slot() -> @physical.SlotMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
}

///|
enum BytesExecutionOutcome {
  Completed
  LiveHeapLimit
  Fatal
} derive(Debug, Eq)

///|
struct BytesBackendOutcomes {
  wasm_interpreter : BytesExecutionOutcome
  wasm_jit : BytesExecutionOutcome
} derive(Debug, Eq)

///|
fn wasm_bytes_body(
  slots : Array[@physical.SlotMetadata],
  blocks : Array[@physical.Block],
) -> @physical.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks,
  }
}

///|
fn wasm_bytes_image(
  body : @physical.FunctionBody,
  constants? : Array[Bytes] = [],
) -> @physical.PhysicalProgram {
  {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    globals: [],
    functions: [PhysicalBody(body)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants,
  }
}

///|
fn classify_bytes_execution(
  result : Result[Unit, @lane_runtime.ExecutionError],
) -> BytesExecutionOutcome raise {
  match result {
    Ok(_) => Completed
    Err(ExecutionResourceLimit(kind=LiveHeapBytes)) => LiveHeapLimit
    Err(EngineTrap(detail=_)) | Err(InternalRuntimeFailure(detail=_)) => Fatal
    Err(error) => fail("unexpected execution result: \{Repr(error)}")
  }
}

///|
fn execute_bytes_wasm(
  image : @physical.PhysicalProgram,
  config : @lane_runtime.ExecutionConfig,
  mode : @lane_wasm_runtime.ExecutionMode,
) -> BytesExecutionOutcome raise {
  let loaded = match load(image, mode~) {
    Ok(value) => value
    Err(error) => fail("Wasm load failed: \{Repr(error)}")
  }
  let instance = match loaded.new_instance(config~) {
    Ok(value) => value
    Err(error) => return classify_bytes_execution(Err(error))
  }
  classify_bytes_execution(instance.execute())
}

///|
fn execute_bytes_backends(
  body : @physical.FunctionBody,
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
  constants? : Array[Bytes] = [],
) -> BytesBackendOutcomes raise {
  execute_bytes_image_backends(wasm_bytes_image(body, constants~), config~)
}

///|
fn execute_bytes_image_backends(
  image : @physical.PhysicalProgram,
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
) -> BytesBackendOutcomes raise {
  {
    wasm_interpreter: execute_bytes_wasm(image, config, Interpreter),
    wasm_jit: execute_bytes_wasm(image, config, Jit),
  }
}

///|
fn assert_bytes_backends(
  body : @physical.FunctionBody,
  expected : BytesExecutionOutcome,
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
  constants? : Array[Bytes] = [],
) -> Unit raise {
  assert_eq(execute_bytes_backends(body, config~, constants~), {
    wasm_interpreter: expected,
    wasm_jit: expected,
  })
}

///|
test "complete-image verification rejects Data used as ByteSequence" {
  let data_slot : @physical.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 0, }),
    erased_companion: None,
  }
  let body = wasm_bytes_trapping_block(
    [data_slot, wasm_bytes_trivial_slot(I64)],
    [
      MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 2, }), [], []),
      ByteSequenceLength({ value: 1, }, { value: 0, }),
    ],
  )
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(body)],
    layouts: [ByteSequence, Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 7,
        stored_witness_count: 0,
        members: [],
      }),
    ],
    constants: [],
  }
  assert_true(
    @physical.verify_physical_program(image)
    is Err(
      InvalidPhysicalProgram(
        site=Instruction(_, _, _),
        detail="SlotId 0 must have ByteSequenceValue semantic kind, got DataValue({ value: 0 })"
      )
    ),
  )
}

///|
test "ByteSequence UTF-8 validation agrees across interpreter and Wasm backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let owned = wasm_bytes_owned_slot()
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
  for case in cases {
    let (bytes, expected) = case
    let instructions : Array[@physical.Instruction] = [
      ConstI64({ value: 0, }, bytes.length().to_int64()),
      ConstI64({ value: 1, }, 0L),
      I64ToByte({ value: 2, }, { value: 1, }),
      ByteSequenceMake({ value: 3, }, { value: 0, }, { value: 2, }),
    ]
    for index, byte in bytes {
      instructions.push(ConstI64({ value: 1, }, index.to_int64()))
      instructions.push(ConstI64({ value: 0, }, byte.to_int().to_int64()))
      instructions.push(I64ToByte({ value: 2, }, { value: 0, }))
      instructions.push(
        ByteSequenceSet({ value: 3, }, { value: 3, }, { value: 1, }, {
          value: 2,
        }),
      )
    }
    instructions.push(ByteSequenceIsValidUtf8({ value: 4, }, { value: 3, }))
    instructions.push(ConstBool({ value: 5, }, expected))
    instructions.push(BoolEq({ value: 6, }, { value: 4, }, { value: 5, }))
    instructions.push(Release({ value: 3, }))
    assert_bytes_backends(
      wasm_bytes_body(
        [
          wasm_bytes_trivial_slot(I64),
          wasm_bytes_trivial_slot(I64),
          i32,
          owned,
          i32,
          i32,
          i32,
        ],
        [
          {
            parameters: [],
            instructions,
            terminator: BranchBool(
              { value: 6, },
              { target: { value: 1, }, arguments: [], },
              { target: { value: 2, }, arguments: [], },
            ),
          },
          { parameters: [], instructions: [], terminator: Return(None), },
          { parameters: [], instructions: [], terminator: Unreachable, },
        ],
      ),
      Completed,
    )
  }
}

///|
test "ByteSequence equality concatenation and slicing agree across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_body([owned, owned, owned, i64, i64, owned, owned, i32], [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          ConstString({ value: 1, }, { value: 1, }),
          ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstI64({ value: 3, }, 1L),
          ConstI64({ value: 4, }, 4L),
          ByteSequenceSlice({ value: 5, }, { value: 2, }, { value: 3, }, {
            value: 4,
          }),
          ConstString({ value: 6, }, { value: 2, }),
          ByteSequenceEqual({ value: 7, }, { value: 5, }, { value: 6, }),
          Release({ value: 5, }),
          Release({ value: 6, }),
        ],
        terminator: BranchBool(
          { value: 7, },
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ]),
    Completed,
    constants=[
      Bytes::from_array([b'a', b'b']),
      Bytes::from_array([b'c', b'd', b'e']),
      Bytes::from_array([b'b', b'c', b'd', b'e']),
    ],
  )
}

///|
test "erased String to Bytes aliases preserve copy-on-write across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_body([owned, owned, i64, i32, owned, owned, i32, owned, i32], [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          RetainCopy({ value: 1, }, { value: 0, }),
          ConstI64({ value: 2, }, 0L),
          I64ToByte({ value: 3, }, { value: 2, }),
          ByteSequenceSet({ value: 4, }, { value: 1, }, { value: 2, }, {
            value: 3,
          }),
          ConstString({ value: 5, }, { value: 1, }),
          ByteSequenceEqual({ value: 6, }, { value: 4, }, { value: 5, }),
        ],
        terminator: BranchBool(
          { value: 6, },
          { target: { value: 1, }, arguments: [], },
          { target: { value: 3, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [
          ConstString({ value: 7, }, { value: 0, }),
          ByteSequenceEqual({ value: 8, }, { value: 0, }, { value: 7, }),
        ],
        terminator: BranchBool(
          { value: 8, },
          { target: { value: 2, }, arguments: [], },
          { target: { value: 3, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [
          Release({ value: 0, }),
          Release({ value: 4, }),
          Release({ value: 5, }),
          Release({ value: 7, }),
        ],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ]),
    Completed,
    constants=[b"A", b"\x00"],
  )
}

///|
test "ByteSequence empty and full slices agree across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_body(
      [
        owned, owned, i64, i64, owned, owned, i32, owned, i64, i64, owned, owned,
        i32,
      ],
      [
        {
          parameters: [],
          instructions: [
            ConstString({ value: 0, }, { value: 0, }),
            RetainCopy({ value: 1, }, { value: 0, }),
            ConstI64({ value: 2, }, 0L),
            ConstI64({ value: 3, }, 3L),
            ByteSequenceSlice({ value: 4, }, { value: 1, }, { value: 2, }, {
              value: 3,
            }),
            ConstString({ value: 5, }, { value: 0, }),
            ByteSequenceEqual({ value: 6, }, { value: 4, }, { value: 5, }),
          ],
          terminator: BranchBool(
            { value: 6, },
            { target: { value: 1, }, arguments: [], },
            { target: { value: 3, }, arguments: [], },
          ),
        },
        {
          parameters: [],
          instructions: [
            RetainCopy({ value: 7, }, { value: 0, }),
            ConstI64({ value: 8, }, 3L),
            ConstI64({ value: 9, }, 0L),
            ByteSequenceSlice({ value: 10, }, { value: 7, }, { value: 8, }, {
              value: 9,
            }),
            ConstString({ value: 11, }, { value: 1, }),
            ByteSequenceEqual({ value: 12, }, { value: 10, }, { value: 11, }),
          ],
          terminator: BranchBool(
            { value: 12, },
            { target: { value: 2, }, arguments: [], },
            { target: { value: 3, }, arguments: [], },
          ),
        },
        {
          parameters: [],
          instructions: [
            Release({ value: 0, }),
            Release({ value: 4, }),
            Release({ value: 5, }),
            Release({ value: 10, }),
            Release({ value: 11, }),
          ],
          terminator: Return(None),
        },
        { parameters: [], instructions: [], terminator: Unreachable, },
      ],
    ),
    Completed,
    constants=[b"abc", b""],
  )
}

///|
test "ByteSequence slice overflow and addressability failures agree across backends" {
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  for
    case in [
      (-1L, 0L),
      (0L, -1L),
      (9223372036854775807L, 1L),
      (4294967296L, 0L),
      (3L, 1L),
    ] {
    assert_bytes_backends(
      wasm_bytes_trapping_block([owned, i64, i64, owned], [
        ConstString({ value: 0, }, { value: 0, }),
        ConstI64({ value: 1, }, case.0),
        ConstI64({ value: 2, }, case.1),
        ByteSequenceSlice({ value: 3, }, { value: 0, }, { value: 1, }, {
          value: 2,
        }),
      ]),
      Fatal,
      constants=[b"abc"],
    )
  }
}

///|
test "ByteSequence concat and slice resource failures agree across backends" {
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let config : @lane_runtime.ExecutionConfig = {
    max_call_depth: None,
    max_live_heap_bytes: Some(15),
  }
  assert_bytes_backends(
    wasm_bytes_trapping_block([owned, owned, owned], [
      ConstString({ value: 0, }, { value: 0, }),
      ConstString({ value: 1, }, { value: 1, }),
      ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
    ]),
    LiveHeapLimit,
    config~,
    constants=[b"a", b"b"],
  )
  assert_bytes_backends(
    wasm_bytes_trapping_block([owned, i64, i64, owned], [
      ConstString({ value: 0, }, { value: 0, }),
      ConstI64({ value: 1, }, 0L),
      ConstI64({ value: 2, }, 1L),
      ByteSequenceSlice({ value: 3, }, { value: 0, }, { value: 1, }, {
        value: 2,
      }),
    ]),
    LiveHeapLimit,
    config~,
    constants=[b"ab"],
  )
}

///|
fn wasm_bytes_single_block(
  slots : Array[@physical.SlotMetadata],
  instructions : Array[@physical.Instruction],
) -> @physical.FunctionBody {
  wasm_bytes_body(slots, [
    { parameters: [], instructions, terminator: Return(None), },
  ])
}

///|
fn wasm_bytes_trapping_block(
  slots : Array[@physical.SlotMetadata],
  instructions : Array[@physical.Instruction],
) -> @physical.FunctionBody {
  wasm_bytes_body(slots, [
    { parameters: [], instructions, terminator: Unreachable, },
  ])
}

///|
test "Byte conversions agree across interpreter and Wasm backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
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
  let blocks : Array[@physical.Block] = []
  for index, case in cases {
    blocks.push({
      parameters: [],
      instructions: [
        ConstI64({ value: 0, }, case.0),
        I64ToByte({ value: 1, }, { value: 0, }),
        ByteToI64({ value: 2, }, { value: 1, }),
        ConstI64({ value: 3, }, case.1),
        I64Eq({ value: 4, }, { value: 2, }, { value: 3, }),
      ],
      terminator: BranchBool(
        { value: 4, },
        { target: { value: index + 1, }, arguments: [], },
        { target: { value: cases.length() + 1, }, arguments: [], },
      ),
    })
  }
  blocks.push({ parameters: [], instructions: [], terminator: Return(None), })
  blocks.push({ parameters: [], instructions: [], terminator: Unreachable, })
  assert_bytes_backends(
    wasm_bytes_body([i64, i32, i64, i64, i32], blocks),
    Completed,
  )
}

///|
test "Bytes zero length agrees across interpreter and Wasm backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let edge = fn(target : Int) -> @physical.Edge {
    { target: { value: target, }, arguments: [], }
  }
  assert_bytes_backends(
    wasm_bytes_body([i64, i32, owned, i64, i32], [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, 0L),
          I64ToByte({ value: 1, }, { value: 0, }),
          ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
          ByteSequenceLength({ value: 3, }, { value: 2, }),
          I64Eq({ value: 4, }, { value: 3, }, { value: 0, }),
        ],
        terminator: BranchBool({ value: 4, }, edge(1), edge(2)),
      },
      {
        parameters: [],
        instructions: [Release({ value: 2, })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ]),
    Completed,
  )
}

///|
test "Bytes make fills every position across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let edge = fn(target : Int) -> @physical.Edge {
    { target: { value: target, }, arguments: [], }
  }
  assert_bytes_backends(
    wasm_bytes_body(
      [
        i64, i32, owned, i64, i64, i64, i64, i32, i32, i32, i32, i64, i64, i64, i64,
        i64, i64, i64, i64, i32,
      ],
      [
        {
          parameters: [],
          instructions: [
            ConstI64({ value: 0, }, 4L),
            ConstI64({ value: 18, }, 255L),
            I64ToByte({ value: 1, }, { value: 18, }),
            ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
            ConstI64({ value: 3, }, 0L),
            ConstI64({ value: 4, }, 1L),
            ConstI64({ value: 5, }, 2L),
            ConstI64({ value: 6, }, 3L),
            ByteSequenceGet({ value: 7, }, { value: 2, }, { value: 3, }),
            ByteSequenceGet({ value: 8, }, { value: 2, }, { value: 4, }),
            ByteSequenceGet({ value: 9, }, { value: 2, }, { value: 5, }),
            ByteSequenceGet({ value: 10, }, { value: 2, }, { value: 6, }),
            ByteToI64({ value: 11, }, { value: 7, }),
            ByteToI64({ value: 12, }, { value: 8, }),
            ByteToI64({ value: 13, }, { value: 9, }),
            ByteToI64({ value: 14, }, { value: 10, }),
            I64Add({ value: 15, }, { value: 11, }, { value: 12, }),
            I64Add({ value: 16, }, { value: 13, }, { value: 14, }),
            I64Add({ value: 17, }, { value: 15, }, { value: 16, }),
            ConstI64({ value: 18, }, 1020L),
            I64Eq({ value: 19, }, { value: 17, }, { value: 18, }),
          ],
          terminator: BranchBool({ value: 19, }, edge(1), edge(2)),
        },
        {
          parameters: [],
          instructions: [Release({ value: 2, })],
          terminator: Return(None),
        },
        { parameters: [], instructions: [], terminator: Unreachable, },
      ],
    ),
    Completed,
  )
}

///|
test "Bytes first middle and final updates agree across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let slots = [
    i64, i32, owned, i64, i64, i64, i32, i32, i32, owned, owned, owned, i32, i32,
    i32, i64, i64, i64, i32, i64,
  ]
  let edge = fn(target : Int) -> @physical.Edge {
    { target: { value: target, }, arguments: [], }
  }
  assert_bytes_backends(
    wasm_bytes_body(slots, [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, 3L),
          I64ToByte({ value: 1, }, { value: 0, }),
          ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstI64({ value: 3, }, 0L),
          ConstI64({ value: 4, }, 1L),
          ConstI64({ value: 5, }, 2L),
          I64ToByte({ value: 6, }, { value: 3, }),
          I64ToByte({ value: 7, }, { value: 4, }),
          I64ToByte({ value: 8, }, { value: 5, }),
          ByteSequenceSet({ value: 9, }, { value: 2, }, { value: 3, }, {
            value: 6,
          }),
          ByteSequenceSet({ value: 10, }, { value: 9, }, { value: 4, }, {
            value: 7,
          }),
          ByteSequenceSet({ value: 11, }, { value: 10, }, { value: 5, }, {
            value: 8,
          }),
          ByteSequenceGet({ value: 12, }, { value: 11, }, { value: 3, }),
          ByteSequenceGet({ value: 13, }, { value: 11, }, { value: 4, }),
          ByteSequenceGet({ value: 14, }, { value: 11, }, { value: 5, }),
          ByteToI64({ value: 15, }, { value: 12, }),
          ByteToI64({ value: 16, }, { value: 13, }),
          ByteToI64({ value: 17, }, { value: 14, }),
          I64Eq({ value: 18, }, { value: 15, }, { value: 3, }),
        ],
        terminator: BranchBool({ value: 18, }, edge(1), edge(5)),
      },
      {
        parameters: [],
        instructions: [I64Eq({ value: 18, }, { value: 16, }, { value: 4, })],
        terminator: BranchBool({ value: 18, }, edge(2), edge(5)),
      },
      {
        parameters: [],
        instructions: [I64Eq({ value: 18, }, { value: 17, }, { value: 5, })],
        terminator: BranchBool({ value: 18, }, edge(3), edge(5)),
      },
      {
        parameters: [],
        instructions: [
          ByteSequenceLength({ value: 19, }, { value: 11, }),
          I64Eq({ value: 18, }, { value: 19, }, { value: 0, }),
        ],
        terminator: BranchBool({ value: 18, }, edge(4), edge(5)),
      },
      {
        parameters: [],
        instructions: [Release({ value: 11, })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ]),
    Completed,
  )
}

///|
test "Bytes shared update preserves the retained alias across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let edge = fn(target : Int) -> @physical.Edge {
    { target: { value: target, }, arguments: [], }
  }
  assert_bytes_backends(
    wasm_bytes_body(
      [i64, i32, owned, owned, i64, i32, owned, i32, i32, i64, i64, i64, i32],
      [
        {
          parameters: [],
          instructions: [
            ConstI64({ value: 0, }, 1L),
            I64ToByte({ value: 1, }, { value: 0, }),
            ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
            RetainCopy({ value: 3, }, { value: 2, }),
            ConstI64({ value: 4, }, 0L),
            I64ToByte({ value: 5, }, { value: 4, }),
            ByteSequenceSet({ value: 6, }, { value: 2, }, { value: 4, }, {
              value: 5,
            }),
            ByteSequenceGet({ value: 7, }, { value: 3, }, { value: 4, }),
            ByteSequenceGet({ value: 8, }, { value: 6, }, { value: 4, }),
            ByteToI64({ value: 9, }, { value: 7, }),
            ByteToI64({ value: 10, }, { value: 8, }),
            ConstI64({ value: 11, }, 1L),
            I64Eq({ value: 12, }, { value: 9, }, { value: 11, }),
          ],
          terminator: BranchBool({ value: 12, }, edge(1), edge(3)),
        },
        {
          parameters: [],
          instructions: [I64Eq({ value: 12, }, { value: 10, }, { value: 4, })],
          terminator: BranchBool({ value: 12, }, edge(2), edge(3)),
        },
        {
          parameters: [],
          instructions: [Release({ value: 3, }), Release({ value: 6, })],
          terminator: Return(None),
        },
        { parameters: [], instructions: [], terminator: Unreachable, },
      ],
    ),
    Completed,
  )
}

///|
test "Bytes unique update reuses its allocation across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_single_block([i64, i32, owned, i64, owned], [
      ConstI64({ value: 0, }, 1L),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
      ConstI64({ value: 3, }, 0L),
      ByteSequenceSet({ value: 4, }, { value: 2, }, { value: 3, }, { value: 1, }),
      Release({ value: 4, }),
    ]),
    Completed,
    config={ max_call_depth: None, max_live_heap_bytes: Some(16), },
  )
}

///|
test "Bytes shared update needs a second allocation across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_trapping_block([i64, i32, owned, owned, i64, owned], [
      ConstI64({ value: 0, }, 1L),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
      RetainCopy({ value: 3, }, { value: 2, }),
      ConstI64({ value: 4, }, 0L),
      ByteSequenceSet({ value: 5, }, { value: 2, }, { value: 4, }, { value: 1, }),
    ]),
    LiveHeapLimit,
    config={ max_call_depth: None, max_live_heap_bytes: Some(16), },
  )
}

///|
test "Bytes allocation exhaustion agrees across interpreter and Wasm backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_trapping_block([i64, i32, owned], [
      ConstI64({ value: 0, }, 1L),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
    ]),
    LiveHeapLimit,
    config={ max_call_depth: None, max_live_heap_bytes: Some(15), },
  )
}

///|
test "Bytes allocation accounting follows the aligned object size" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let body = fn(length : Int64) {
    wasm_bytes_single_block([i64, i32, owned], [
      ConstI64({ value: 0, }, length),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
      Release({ value: 2, }),
    ])
  }
  let config : @lane_runtime.ExecutionConfig = {
    max_call_depth: None,
    max_live_heap_bytes: Some(16),
  }
  assert_bytes_backends(body(4L), Completed, config~)
  assert_bytes_backends(body(5L), LiveHeapLimit, config~)
}

///|
test "large Bytes allocation is rejected before materialization across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_trapping_block([i64, i32, owned], [
      ConstI64({ value: 0, }, 2147483636L),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
    ]),
    LiveHeapLimit,
    config={ max_call_depth: None, max_live_heap_bytes: Some(15), },
  )
}

///|
test "unaddressable Bytes allocation is safely rejected across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let outcomes = execute_bytes_backends(
    wasm_bytes_trapping_block([i64, i32, owned], [
      ConstI64({ value: 0, }, 4294967295L),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
    ]),
    config={ max_call_depth: None, max_live_heap_bytes: Some(15), },
  )
  assert_eq(outcomes, { wasm_interpreter: Fatal, wasm_jit: Fatal, })
}

///|
test "Bytes invalid lengths and indices are fatal across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let invalid_length_body = fn(length : Int64) {
    wasm_bytes_trapping_block([i64, i32, owned], [
      ConstI64({ value: 0, }, length),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
    ])
  }
  for length in [-1L, 4294967296L, 9223372036854775807L] {
    assert_bytes_backends(invalid_length_body(length), Fatal)
  }
  let invalid_index_body = fn(length : Int64, index : Int64, update : Bool) {
    let instructions : Array[@physical.Instruction] = [
      ConstI64({ value: 0, }, length),
      I64ToByte({ value: 1, }, { value: 0, }),
      ByteSequenceMake({ value: 2, }, { value: 0, }, { value: 1, }),
      ConstI64({ value: 3, }, index),
    ]
    if update {
      instructions.push(
        ByteSequenceSet({ value: 4, }, { value: 2, }, { value: 3, }, {
          value: 1,
        }),
      )
    } else {
      instructions.push(
        ByteSequenceGet({ value: 4, }, { value: 2, }, { value: 3, }),
      )
    }
    wasm_bytes_trapping_block(
      [i64, i32, owned, i64, if update { owned } else { i32 }],
      instructions,
    )
  }
  for
    case in [
      (1L, -1L, false),
      (1L, 1L, false),
      (1L, -1L, true),
      (1L, 1L, true),
      (0L, 0L, false),
      (0L, 0L, true),
    ] {
    assert_bytes_backends(invalid_index_body(case.0, case.1, case.2), Fatal)
  }
}
