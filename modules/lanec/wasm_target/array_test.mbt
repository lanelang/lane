///|
fn wasm_array_slot(
  representation : @physical.Representation,
  cleanup? : @physical.Cleanup = Trivial,
  kind? : @physical.SemanticValueKind = ScalarValue,
  erased_companion? : @physical.SlotId? = None,
) -> @physical.SlotMetadata {
  { representation, cleanup, kind, erased_companion, }
}

///|
fn wasm_array_body(
  slots : Array[@physical.SlotMetadata],
  instructions : Array[@physical.Instruction],
  condition : @physical.SlotId,
) -> @physical.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions,
        terminator: BranchBool(
          condition,
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
}

///|
fn wasm_array_image(
  body : @physical.FunctionBody,
  layouts : Array[@physical.LayoutRecipe],
  constants? : Array[Bytes] = [],
) -> @physical.PhysicalProgram {
  {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    data_family_count: 0,
    globals: [],
    functions: [PhysicalBody(body)],
    layouts,
    object_shapes: [],
    constants,
  }
}

///|
enum ArrayExecutionOutcome {
  ArrayCompleted
  ArrayLiveHeapLimit
  ArrayFatal
} derive(Debug, Eq)

///|
fn execute_array_image(
  image : @physical.PhysicalProgram,
  mode : @lane_wasm_runtime.ExecutionMode,
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
) -> (ArrayExecutionOutcome, Int) raise {
  let loaded = match load(image, mode~) {
    Ok(value) => value
    Err(error) => fail("Wasm load failed: \{Repr(error)}")
  }
  let instance = match loaded.new_instance(config~) {
    Ok(value) => value
    Err(ExecutionResourceLimit(kind=LiveHeapBytes)) =>
      return (ArrayLiveHeapLimit, 0)
    Err(error) => fail("Wasm instantiation failed: \{Repr(error)}")
  }
  let outcome = match instance.execute() {
    Ok(_) => ArrayCompleted
    Err(ExecutionResourceLimit(kind=LiveHeapBytes)) => ArrayLiveHeapLimit
    Err(EngineTrap(_)) | Err(InternalRuntimeFailure(_)) => ArrayFatal
    Err(error) => fail("unexpected execution result: \{Repr(error)}")
  }
  let live_heap = match
    instance.store.get_global(instance.instance.global_addrs[4]).get() {
    I32(value) => value
    value => fail("live heap global is not I32: \{Repr(value)}")
  }
  (outcome, live_heap)
}

///|
fn assert_array_backends(
  image : @physical.PhysicalProgram,
  expected : (ArrayExecutionOutcome, Int),
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
) -> Unit raise {
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    assert_eq(execute_array_image(image, mode, config~), expected)
  }
}

///|
test "generic scalar Array operations agree across Wasmoon modes" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let boolean = wasm_array_slot(I32)
  let body = wasm_array_body(
    [
      layout, scalar, scalar, erased, array, scalar, scalar, boolean, scalar, erased,
      scalar, scalar, boolean, boolean,
    ],
    [
      ConstLayout({ value: 0, }, { value: 1, }),
      ConstI64({ value: 1, }, 3L),
      ConstI64({ value: 2, }, 42L),
      EraseI64({ value: 3, }, { value: 2, }),
      ArrayMake({ value: 4, }, { value: 1, }, { value: 3, }),
      ArrayLength({ value: 5, }, { value: 4, }),
      ConstI64({ value: 6, }, 3L),
      I64Eq({ value: 7, }, { value: 5, }, { value: 6, }),
      ConstI64({ value: 8, }, 1L),
      ArrayGet({ value: 9, }, { value: 4, }, { value: 8, }),
      UneraseI64({ value: 10, }, { value: 9, }),
      ConstI64({ value: 11, }, 42L),
      I64Eq({ value: 12, }, { value: 10, }, { value: 11, }),
      I32Mul({ value: 13, }, { value: 7, }, { value: 12, }),
      Release({ value: 4, }),
    ],
    { value: 13, },
  )
  assert_array_backends(
    wasm_array_image(body, [I64, Array]),
    (ArrayCompleted, 0),
  )
}

///|
test "ArrayEmpty carries its element layout and has zero length" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let scalar = wasm_array_slot(I64)
  let boolean = wasm_array_slot(I32)
  let body = wasm_array_body(
    [layout, array, scalar, scalar, boolean],
    [
      ConstLayout({ value: 0, }, { value: 1, }),
      ArrayEmpty({ value: 1, }, Witness({ value: 0, })),
      ArrayLength({ value: 2, }, { value: 1, }),
      ConstI64({ value: 3, }, 0L),
      I64Eq({ value: 4, }, { value: 2, }, { value: 3, }),
      Release({ value: 1, }),
    ],
    { value: 4, },
  )
  assert_array_backends(
    wasm_array_image(body, [I64, Array]),
    (ArrayCompleted, 0),
    config={ max_call_depth: None, max_live_heap_bytes: Some(16), },
  )
}

///|
test "ArraySet preserves shared aliases across Wasmoon modes" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let boolean = wasm_array_slot(I32)
  let body = wasm_array_body(
    [
      layout, scalar, scalar, erased, array, array, scalar, scalar, erased, array,
      erased, scalar, scalar, boolean, erased, scalar, boolean, boolean,
    ],
    [
      ConstLayout({ value: 0, }, { value: 1, }),
      ConstI64({ value: 1, }, 2L),
      ConstI64({ value: 2, }, 1L),
      EraseI64({ value: 3, }, { value: 2, }),
      ArrayMake({ value: 4, }, { value: 1, }, { value: 3, }),
      RetainCopy({ value: 5, }, { value: 4, }),
      ConstI64({ value: 6, }, 0L),
      ConstI64({ value: 7, }, 9L),
      EraseI64({ value: 8, }, { value: 7, }),
      ArraySet({ value: 9, }, { value: 4, }, { value: 6, }, { value: 8, }),
      ArrayGet({ value: 10, }, { value: 5, }, { value: 6, }),
      UneraseI64({ value: 11, }, { value: 10, }),
      ConstI64({ value: 12, }, 1L),
      I64Eq({ value: 13, }, { value: 11, }, { value: 12, }),
      ArrayGet({ value: 14, }, { value: 9, }, { value: 6, }),
      UneraseI64({ value: 15, }, { value: 14, }),
      I64Eq({ value: 16, }, { value: 15, }, { value: 7, }),
      I32Mul({ value: 17, }, { value: 13, }, { value: 16, }),
      Release({ value: 5, }),
      Release({ value: 9, }),
    ],
    { value: 17, },
  )
  assert_array_backends(
    wasm_array_image(body, [I64, Array]),
    (ArrayCompleted, 0),
    config={ max_call_depth: None, max_live_heap_bytes: Some(64), },
  )
}

///|
test "ArraySet reuses a uniquely owned Array" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let boolean = wasm_array_slot(I32)
  let body = wasm_array_body(
    [
      layout, scalar, scalar, erased, array, scalar, scalar, erased, array, erased,
      scalar, boolean,
    ],
    [
      ConstLayout({ value: 0, }, { value: 1, }),
      ConstI64({ value: 1, }, 1L),
      ConstI64({ value: 2, }, 4L),
      EraseI64({ value: 3, }, { value: 2, }),
      ArrayMake({ value: 4, }, { value: 1, }, { value: 3, }),
      ConstI64({ value: 5, }, 0L),
      ConstI64({ value: 6, }, 9L),
      EraseI64({ value: 7, }, { value: 6, }),
      ArraySet({ value: 8, }, { value: 4, }, { value: 5, }, { value: 7, }),
      ArrayGet({ value: 9, }, { value: 8, }, { value: 5, }),
      UneraseI64({ value: 10, }, { value: 9, }),
      I64Eq({ value: 11, }, { value: 10, }, { value: 6, }),
      Release({ value: 8, }),
    ],
    { value: 11, },
  )
  assert_array_backends(
    wasm_array_image(body, [I64, Array]),
    (ArrayCompleted, 0),
    config={ max_call_depth: None, max_live_heap_bytes: Some(24), },
  )
}

///|
test "ArrayGet owns a reference element independently of its Array" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let byte = wasm_array_slot(I32)
  let bytes = wasm_array_slot(I32, cleanup=OwnedRef, kind=ByteSequenceValue)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let boolean = wasm_array_slot(I32)
  let body = wasm_array_body(
    [
      layout, scalar, byte, bytes, erased, scalar, array, scalar, erased, bytes,
      scalar, scalar, boolean,
    ],
    [
      ConstLayout({ value: 0, }, { value: 1, }),
      ConstI64({ value: 1, }, 3L),
      ConstI32({ value: 2, }, 97),
      ByteSequenceMake({ value: 3, }, { value: 1, }, { value: 2, }),
      EraseI32({ value: 4, }, { value: 3, }),
      ConstI64({ value: 5, }, 1L),
      ArrayMake({ value: 6, }, { value: 5, }, { value: 4, }),
      ConstI64({ value: 7, }, 0L),
      ArrayGet({ value: 8, }, { value: 6, }, { value: 7, }),
      Release({ value: 6, }),
      UneraseI32({ value: 9, }, { value: 8, }),
      ByteSequenceLength({ value: 10, }, { value: 9, }),
      ConstI64({ value: 11, }, 3L),
      I64Eq({ value: 12, }, { value: 10, }, { value: 11, }),
      Release({ value: 9, }),
    ],
    { value: 12, },
  )
  assert_array_backends(
    wasm_array_image(body, [ByteSequence, Array]),
    (ArrayCompleted, 0),
  )
}

///|
test "zero-length ArrayMake consumes its owned fill" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let byte = wasm_array_slot(I32)
  let bytes = wasm_array_slot(I32, cleanup=OwnedRef, kind=ByteSequenceValue)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let boolean = wasm_array_slot(I32)
  let body = wasm_array_body(
    [layout, scalar, byte, bytes, erased, array, boolean],
    [
      ConstLayout({ value: 0, }, { value: 1, }),
      ConstI64({ value: 1, }, 0L),
      ConstI32({ value: 2, }, 7),
      ByteSequenceMake({ value: 3, }, { value: 1, }, { value: 2, }),
      EraseI32({ value: 4, }, { value: 3, }),
      ArrayMake({ value: 5, }, { value: 1, }, { value: 4, }),
      Release({ value: 5, }),
      ConstBool({ value: 6, }, true),
    ],
    { value: 6, },
  )
  assert_array_backends(
    wasm_array_image(body, [ByteSequence, Array]),
    (ArrayCompleted, 0),
  )
}

///|
test "Array allocation failure leaves the consumed fill owned by its frame" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let byte = wasm_array_slot(I32)
  let bytes = wasm_array_slot(I32, cleanup=OwnedRef, kind=ByteSequenceValue)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let body : @physical.FunctionBody = {
    slots: [layout, scalar, byte, bytes, erased, array],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0, }, { value: 1, }),
          ConstI64({ value: 1, }, 1L),
          ConstI32({ value: 2, }, 7),
          ByteSequenceMake({ value: 3, }, { value: 1, }, { value: 2, }),
          EraseI32({ value: 4, }, { value: 3, }),
          ArrayMake({ value: 5, }, { value: 1, }, { value: 4, }),
          Release({ value: 5, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  assert_array_backends(
    wasm_array_image(body, [ByteSequence, Array]),
    (ArrayLiveHeapLimit, 0),
    config={ max_call_depth: None, max_live_heap_bytes: Some(16), },
  )
}

///|
fn array_invalid_index_image(index : Int64) -> @physical.PhysicalProgram {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let erased = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let body : @physical.FunctionBody = {
    slots: [layout, scalar, scalar, erased, array, scalar, erased],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0, }, { value: 1, }),
          ConstI64({ value: 1, }, 1L),
          ConstI64({ value: 2, }, 42L),
          EraseI64({ value: 3, }, { value: 2, }),
          ArrayMake({ value: 4, }, { value: 1, }, { value: 3, }),
          ConstI64({ value: 5, }, index),
          ArrayGet({ value: 6, }, { value: 4, }, { value: 5, }),
          Release({ value: 6, }),
          Release({ value: 4, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  wasm_array_image(body, [I64, Array])
}

///|
test "Array indices are checked before address arithmetic" {
  for index in [-1L, 1L] {
    let image = array_invalid_index_image(index)
    for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
      assert_eq(execute_array_image(image, mode).0, ArrayFatal)
    }
  }
}

///|
test "Array companion disagreement traps in both Wasmoon modes" {
  let layout = wasm_array_slot(I32, kind=LayoutValue)
  let scalar = wasm_array_slot(I64)
  let erased_i64 = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 0, }),
  )
  let erased_f64 = wasm_array_slot(
    I64,
    cleanup=OwnedErased,
    kind=ErasedValue,
    erased_companion=Some({ value: 5, }),
  )
  let array = wasm_array_slot(I32, cleanup=OwnedRef, kind=ArrayValue)
  let body : @physical.FunctionBody = {
    slots: [layout, scalar, scalar, erased_i64, array, layout, erased_f64],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0, }, { value: 1, }),
          ConstI64({ value: 1, }, 1L),
          ConstI64({ value: 2, }, 42L),
          EraseI64({ value: 3, }, { value: 2, }),
          ArrayMake({ value: 4, }, { value: 1, }, { value: 3, }),
          ConstLayout({ value: 5, }, { value: 2, }),
          ArrayGet({ value: 6, }, { value: 4, }, { value: 1, }),
          Release({ value: 6, }),
          Release({ value: 4, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = wasm_array_image(body, [I64, F64, Array])
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    assert_eq(execute_array_image(image, mode).0, ArrayFatal)
  }
}
