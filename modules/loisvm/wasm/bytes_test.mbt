///|
fn wasm_bytes_trivial_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, erased_companion: None }
}

///|
fn wasm_bytes_owned_slot() -> @bytecode.SlotMetadata {
  { representation: I32, cleanup: OwnedRef, erased_companion: None }
}

///|
enum BytesExecutionOutcome {
  Completed
  LiveHeapLimit
  Fatal
} derive(Debug, Eq)

///|
struct BytesBackendOutcomes {
  direct_interpreter : BytesExecutionOutcome
  wasm_interpreter : BytesExecutionOutcome
  wasm_jit : BytesExecutionOutcome
} derive(Debug, Eq)

///|
fn wasm_bytes_body(
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
fn wasm_bytes_image(body : @bytecode.FunctionBody) -> @bytecode.BytecodeImage {
  {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [BytecodeBody(body)],
    layouts: [Bytes],
    object_shapes: [],
    constants: [],
  }
}

///|
fn classify_bytes_execution(
  result : Result[Unit, @loisvm_runtime.ExecutionError],
) -> BytesExecutionOutcome raise {
  match result {
    Ok(_) => Completed
    Err(ExecutionResourceLimit(kind=LiveHeapBytes)) => LiveHeapLimit
    Err(EngineTrap(detail=_)) => Fatal
    Err(error) => fail("unexpected execution result: \{Repr(error)}")
  }
}

///|
fn execute_bytes_direct(
  image : @bytecode.BytecodeImage,
  config : @loisvm_runtime.ExecutionConfig,
) -> BytesExecutionOutcome raise {
  let loaded = match
    @loisvm_interp.load(image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("direct interpreter load failed: \{Repr(error)}")
  }
  classify_bytes_execution(loaded.new_instance(config~).execute())
}

///|
fn execute_bytes_wasm(
  image : @bytecode.BytecodeImage,
  config : @loisvm_runtime.ExecutionConfig,
  mode : ExecutionMode,
) -> BytesExecutionOutcome raise {
  let loaded = match
    load(image, @loisvm_runtime.RuntimeRegistry::new(), mode~) {
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
  body : @bytecode.FunctionBody,
  config? : @loisvm_runtime.ExecutionConfig = @loisvm_runtime.ExecutionConfig::defaults(),
) -> BytesBackendOutcomes raise {
  let image = wasm_bytes_image(body)
  {
    direct_interpreter: execute_bytes_direct(image, config),
    wasm_interpreter: execute_bytes_wasm(image, config, Interpreter),
    wasm_jit: execute_bytes_wasm(image, config, Jit),
  }
}

///|
fn assert_bytes_backends(
  body : @bytecode.FunctionBody,
  expected : BytesExecutionOutcome,
  config? : @loisvm_runtime.ExecutionConfig = @loisvm_runtime.ExecutionConfig::defaults(),
) -> Unit raise {
  assert_eq(execute_bytes_backends(body, config~), {
    direct_interpreter: expected,
    wasm_interpreter: expected,
    wasm_jit: expected,
  })
}

///|
fn wasm_bytes_single_block(
  slots : Array[@bytecode.SlotMetadata],
  instructions : Array[@bytecode.Instruction],
) -> @bytecode.FunctionBody {
  wasm_bytes_body(slots, [
    { parameters: [], instructions, terminator: Return(None) },
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
  let edge = fn(target : Int) -> @bytecode.Edge {
    { target: { value: target }, arguments: [] }
  }
  assert_bytes_backends(
    wasm_bytes_body([i64, i32, owned, i64, i32], [
      {
        parameters: [],
        instructions: [
          ConstInt({ value: 0 }, 0L),
          IntToByte({ value: 1 }, { value: 0 }),
          BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
          BytesLength({ value: 3 }, { value: 2 }),
          IntEq({ value: 4 }, { value: 3 }, { value: 0 }),
        ],
        terminator: BranchBool({ value: 4 }, edge(1), edge(2)),
      },
      {
        parameters: [],
        instructions: [Release({ value: 2 })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable },
    ]),
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
  let edge = fn(target : Int) -> @bytecode.Edge {
    { target: { value: target }, arguments: [] }
  }
  assert_bytes_backends(
    wasm_bytes_body(slots, [
      {
        parameters: [],
        instructions: [
          ConstInt({ value: 0 }, 3L),
          IntToByte({ value: 1 }, { value: 0 }),
          BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
          ConstInt({ value: 3 }, 0L),
          ConstInt({ value: 4 }, 1L),
          ConstInt({ value: 5 }, 2L),
          IntToByte({ value: 6 }, { value: 3 }),
          IntToByte({ value: 7 }, { value: 4 }),
          IntToByte({ value: 8 }, { value: 5 }),
          BytesSet({ value: 9 }, { value: 2 }, { value: 3 }, { value: 6 }),
          BytesSet({ value: 10 }, { value: 9 }, { value: 4 }, { value: 7 }),
          BytesSet({ value: 11 }, { value: 10 }, { value: 5 }, { value: 8 }),
          BytesGet({ value: 12 }, { value: 11 }, { value: 3 }),
          BytesGet({ value: 13 }, { value: 11 }, { value: 4 }),
          BytesGet({ value: 14 }, { value: 11 }, { value: 5 }),
          ByteToInt({ value: 15 }, { value: 12 }),
          ByteToInt({ value: 16 }, { value: 13 }),
          ByteToInt({ value: 17 }, { value: 14 }),
          IntEq({ value: 18 }, { value: 15 }, { value: 3 }),
        ],
        terminator: BranchBool({ value: 18 }, edge(1), edge(5)),
      },
      {
        parameters: [],
        instructions: [IntEq({ value: 18 }, { value: 16 }, { value: 4 })],
        terminator: BranchBool({ value: 18 }, edge(2), edge(5)),
      },
      {
        parameters: [],
        instructions: [IntEq({ value: 18 }, { value: 17 }, { value: 5 })],
        terminator: BranchBool({ value: 18 }, edge(3), edge(5)),
      },
      {
        parameters: [],
        instructions: [
          BytesLength({ value: 19 }, { value: 11 }),
          IntEq({ value: 18 }, { value: 19 }, { value: 0 }),
        ],
        terminator: BranchBool({ value: 18 }, edge(4), edge(5)),
      },
      {
        parameters: [],
        instructions: [Release({ value: 11 })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable },
    ]),
    Completed,
  )
}

///|
test "Bytes shared update preserves the retained alias across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let edge = fn(target : Int) -> @bytecode.Edge {
    { target: { value: target }, arguments: [] }
  }
  assert_bytes_backends(
    wasm_bytes_body(
      [i64, i32, owned, owned, i64, i32, owned, i32, i32, i64, i64, i64, i32],
      [
        {
          parameters: [],
          instructions: [
            ConstInt({ value: 0 }, 1L),
            IntToByte({ value: 1 }, { value: 0 }),
            BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
            RetainCopy({ value: 3 }, { value: 2 }),
            ConstInt({ value: 4 }, 0L),
            IntToByte({ value: 5 }, { value: 4 }),
            BytesSet({ value: 6 }, { value: 2 }, { value: 4 }, { value: 5 }),
            BytesGet({ value: 7 }, { value: 3 }, { value: 4 }),
            BytesGet({ value: 8 }, { value: 6 }, { value: 4 }),
            ByteToInt({ value: 9 }, { value: 7 }),
            ByteToInt({ value: 10 }, { value: 8 }),
            ConstInt({ value: 11 }, 1L),
            IntEq({ value: 12 }, { value: 9 }, { value: 11 }),
          ],
          terminator: BranchBool({ value: 12 }, edge(1), edge(3)),
        },
        {
          parameters: [],
          instructions: [IntEq({ value: 12 }, { value: 10 }, { value: 4 })],
          terminator: BranchBool({ value: 12 }, edge(2), edge(3)),
        },
        {
          parameters: [],
          instructions: [Release({ value: 3 }), Release({ value: 6 })],
          terminator: Return(None),
        },
        { parameters: [], instructions: [], terminator: Unreachable },
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
      ConstInt({ value: 0 }, 1L),
      IntToByte({ value: 1 }, { value: 0 }),
      BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
      ConstInt({ value: 3 }, 0L),
      BytesSet({ value: 4 }, { value: 2 }, { value: 3 }, { value: 1 }),
      Release({ value: 4 }),
    ]),
    Completed,
    config={
      max_call_depth: None,
      max_live_heap_bytes: Some(16),
      max_host_objects: None,
    },
  )
}

///|
test "Bytes shared update needs a second allocation across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_single_block([i64, i32, owned, owned, i64, owned], [
      ConstInt({ value: 0 }, 1L),
      IntToByte({ value: 1 }, { value: 0 }),
      BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
      RetainCopy({ value: 3 }, { value: 2 }),
      ConstInt({ value: 4 }, 0L),
      BytesSet({ value: 5 }, { value: 2 }, { value: 4 }, { value: 1 }),
    ]),
    LiveHeapLimit,
    config={
      max_call_depth: None,
      max_live_heap_bytes: Some(16),
      max_host_objects: None,
    },
  )
}

///|
test "Bytes allocation exhaustion agrees across interpreter and Wasm backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_single_block([i64, i32, owned], [
      ConstInt({ value: 0 }, 1L),
      IntToByte({ value: 1 }, { value: 0 }),
      BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
    ]),
    LiveHeapLimit,
    config={
      max_call_depth: None,
      max_live_heap_bytes: Some(15),
      max_host_objects: None,
    },
  )
}

///|
test "large Bytes allocation is rejected before materialization across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_single_block([i64, i32, owned], [
      ConstInt({ value: 0 }, 2147483636L),
      IntToByte({ value: 1 }, { value: 0 }),
      BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
    ]),
    LiveHeapLimit,
    config={
      max_call_depth: None,
      max_live_heap_bytes: Some(15),
      max_host_objects: None,
    },
  )
}

///|
test "Bytes invalid lengths and indices are fatal across backends" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  assert_bytes_backends(
    wasm_bytes_single_block([i64, i32, owned], [
      ConstInt({ value: 0 }, -1L),
      IntToByte({ value: 1 }, { value: 0 }),
      BytesMake({ value: 2 }, { value: 0 }, { value: 1 }),
    ]),
    Fatal,
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
    wasm_bytes_single_block(
      [i64, i32, owned, i64, if update { owned } else { i32 }],
      instructions,
    )
  }
  for case in [(-1L, false), (1L, false), (-1L, true), (1L, true)] {
    assert_bytes_backends(invalid_index_body(case.0, case.1), Fatal)
  }
}
