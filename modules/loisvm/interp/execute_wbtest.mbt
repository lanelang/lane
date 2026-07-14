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
  result~ : @bytecode.ResultRepresentation,
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
      invoke=fn(_context, _arguments) { String("abc") },
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
      StringLength({ value: 2 }, { value: 1 }),
      Release({ value: 1 }),
    ],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    functions: [
      BytecodeBody(entry),
      RuntimeImport({ abi_major: 1, user_arity: 0, symbol: "lane.test.string" }),
    ],
    layouts: [String],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(_) => fail("load failed")
  }
  let instance = loaded.new_instance(config={
    max_call_depth: None,
    max_live_heap_bytes: Some(16),
  })
  assert_eq(instance.execute(), Ok(()))
  assert_eq(instance.heap.live_bytes, 0)
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
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({ constructor_tag: 7, stored_witness_count: 0, members: [] }),
    ],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
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
      ConstInt({ value: 0 }, 42L),
      MakeData({ value: 1 }, { value: 0 }, Immediate({ value: 1 }), [], [
        { value: 0 },
      ]),
      ConstDouble({ value: 2 }, (0.0 / 0.0).reinterpret_as_int64()),
      DoubleToInt({ value: 3 }, { value: 2 }),
    ],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
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
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(),
    Err(EngineTrap(detail="invalid Double-to-Int conversion")),
  )
  assert_true(instance.heap.live_bytes > 0)
  assert_false(instance.frames.is_empty())
}

///|
