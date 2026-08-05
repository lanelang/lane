///|
fn trivial_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, erased_companion: None }
}

///|
fn body(
  slots~ : Array[@bytecode.SlotMetadata],
  parameters? : Array[@bytecode.SlotId] = [],
  result~ : @bytecode.ResultAbi,
  instructions~ : Array[@bytecode.Instruction],
  terminator~ : @bytecode.Terminator,
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: parameters },
    result,
    blocks: [{ parameters: [], instructions, terminator }],
  }
}

///|
test "ARC releases dynamic runtime String owners" {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.string",
      abi_major=1,
      parameters=[],
      result=String,
      invoke=fn(_context, _arguments) { String(@utf8.encode("中\u{0}🙂")) },
    ),
  )
  let owned_string : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    erased_companion: None,
  }
  let entry = body(
    slots=[owned_string, owned_string, trivial_slot(I64)],
    result=Unit,
    instructions=[
      CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      RetainCopy({ value: 1 }, { value: 0 }),
      Release({ value: 0 }),
      ByteSequenceLength({ value: 2 }, { value: 1 }),
      Release({ value: 1 }),
    ],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [
      { witness_count: 0, parameters: [], result: Unit },
      { witness_count: 0, parameters: [], result: Value(I32, OwnedRef) },
    ],
    globals: [],
    functions: [
      BytecodeBody(entry),
      RuntimeImport({
        abi_major: 1,
        parameters: [],
        result: String,
        symbol: "lane.test.string",
      }),
    ],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(_) => fail("load failed")
  }
  let instance = loaded.new_instance(config={
    max_call_depth: None,
    max_live_heap_bytes: Some(24),
    max_host_objects: None,
  })
  assert_eq(instance.execute(), Ok(()))
  assert_eq(instance.heap.live_bytes, 0)
}

///|
test "interpreter rejects invalid host String UTF-8" {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.invalid_string",
      abi_major=1,
      parameters=[],
      result=String,
      invoke=fn(_context, _arguments) { String(Bytes::from_array([b'\xFF'])) },
    ),
  )
  let owned_string : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    erased_companion: None,
  }
  let entry = body(
    slots=[owned_string],
    result=Unit,
    instructions=[
      CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      Release({ value: 0 }),
    ],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [
      { witness_count: 0, parameters: [], result: Unit },
      { witness_count: 0, parameters: [], result: Value(I32, OwnedRef) },
    ],
    globals: [],
    functions: [
      BytecodeBody(entry),
      RuntimeImport({
        abi_major: 1,
        parameters: [],
        result: String,
        symbol: "lane.test.invalid_string",
      }),
    ],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(
    loaded.new_instance().execute(),
    Err(
      RuntimeImportFailure(
        symbol="lane.test.invalid_string",
        message="runtime import returned invalid UTF-8 String",
      ),
    ),
  )
}

///|
test "fieldless data construction reuses an immortal image singleton" {
  let owned_ref : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    erased_companion: None,
  }
  let entry = body(
    slots=[owned_ref],
    result=Unit,
    instructions=[
      MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
      Release({ value: 0 }),
      MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
      Release({ value: 0 }),
    ],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({ constructor_tag: 7, stored_witness_count: 0, members: [] }),
    ],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(instance.execute(), Ok(()))
  assert_eq(instance.heap.objects.length(), 2)
  assert_eq(instance.heap.live_bytes, 0)
}

///|
test "engine traps discard the instance without ARC unwinding" {
  let owned_ref : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    erased_companion: None,
  }
  let entry = body(
    slots=[trivial_slot(I64), owned_ref, trivial_slot(F64), trivial_slot(I64)],
    result=Unit,
    instructions=[
      ConstI64({ value: 0 }, 42L),
      MakeData({ value: 1 }, { value: 0 }, Immediate({ value: 1 }), [], [
        { value: 0 },
      ]),
      ConstF64({ value: 2 }, (0.0 / 0.0).reinterpret_as_int64()),
      F64ToI64({ value: 3 }, { value: 2 }),
    ],
    terminator=Unreachable,
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          { representation: I64, cleanup: Trivial, witness_ordinal: None },
        ],
      }),
    ],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(),
    Err(EngineTrap(detail="invalid F64-to-I64 conversion")),
  )
  assert_true(instance.heap.live_bytes > 0)
  assert_false(instance.frames.is_empty())
}

///|
test "CallValue validates dynamic target and environment before consumption" {
  let callable_slot : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    erased_companion: None,
  }
  let entry = body(
    slots=[callable_slot],
    result=Unit,
    instructions=[],
    terminator=Return(None),
  )
  let capturing_target : @bytecode.FunctionBody = {
    slots: [{ representation: I32, cleanup: OwnedRef, erased_companion: None }],
    inputs: {
      environment: Some({ value: 0 }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0 })],
        terminator: Return(None),
      },
    ],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    functions: [BytecodeBody(entry), BytecodeBody(capturing_target)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = LoadedImage::{ image, bindings: [None, None] }
  let instance = loaded.new_instance()
  let frame = make_frame(entry, None, [], [], None)
  frame.write({ value: 0 }, I64(callable({ value: 99 }, 0)))
  let error : ExecutionFailure? = try {
    instance.call_value(
      frame,
      { value: 0 },
      { value: 0 },
      [],
      [],
      None,
      tail=false,
    )
    None
  } catch {
    error => Some(error)
  }
  assert_true(
    error is Some(InvalidCallable(InvalidTarget(function={ value: 99 }))),
  )
  assert_eq(frame.owned_live, [true])
  let missing_environment = make_frame(entry, None, [], [], None)
  missing_environment.write({ value: 0 }, I64(callable({ value: 2 }, 0)))
  let environment_error : ExecutionFailure? = try {
    instance.call_value(
      missing_environment,
      { value: 0 },
      { value: 0 },
      [],
      [],
      None,
      tail=false,
    )
    None
  } catch {
    error => Some(error)
  }
  assert_true(
    environment_error
    is Some(
      InvalidCallable(
        EnvironmentMismatch(function={ value: 2 }, expected=true, actual=false)
      )
    ),
  )
  assert_eq(missing_environment.owned_live, [true])
}

///|
