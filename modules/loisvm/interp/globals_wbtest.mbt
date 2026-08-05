///|
fn owned_slot(
  representation : @bytecode.Representation,
  cleanup : @bytecode.Cleanup,
  kind? : @bytecode.SemanticValueKind = match cleanup {
    OwnedCallable => CallableValue
    OwnedRef => ByteSequenceValue
    OwnedErased => ErasedValue
    Trivial => ScalarValue
  },
  erased_companion? : @bytecode.SlotId? = None,
) -> @bytecode.SlotMetadata {
  { representation, cleanup, kind, erased_companion }
}

///|
fn lifecycle_initializer() -> @bytecode.FunctionBody {
  let owned_ref = owned_slot(I32, OwnedRef)
  {
    slots: [
      owned_ref,
      owned_ref,
      owned_ref,
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0 })),
      owned_slot(I64, OwnedCallable),
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        erased_companion: None,
      },
      owned_slot(I64, OwnedErased, erased_companion=Some({ value: 5 })),
      trivial_slot(I64),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 7 }, 42L),
          InitGlobal({ value: 0 }, { value: 7 }),
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          InitGlobal({ value: 1 }, { value: 2 }),
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          MakeEnv({ value: 3 }, { value: 0 }, Immediate({ value: 2 }), [], [
            { value: 2 },
          ]),
          MakeClosure({ value: 4 }, { value: 3 }, { value: 3 }),
          InitGlobal({ value: 2 }, { value: 4 }),
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          ConstLayout({ value: 5 }, { value: 1 }),
          EraseI32({ value: 6 }, { value: 2 }),
          InitGlobal({ value: 4 }, { value: 6 }),
        ],
        terminator: Return(None),
      },
    ],
  }
}

///|
fn lifecycle_entry(failing? : Bool = false) -> @bytecode.FunctionBody {
  let instructions : Array[@bytecode.Instruction] = [
    BorrowGlobal({ value: 0 }, { value: 0 }),
    BorrowGlobal({ value: 1 }, { value: 1 }),
    BorrowGlobal({ value: 2 }, { value: 2 }),
    BorrowGlobal({ value: 4 }, { value: 4 }),
  ]
  if failing {
    instructions.push(CallDirect({ value: 4 }, None, [], [], None))
  }
  {
    slots: [
      trivial_slot(I64),
      {
        representation: I32,
        cleanup: Trivial,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
      {
        representation: I64,
        cleanup: Trivial,
        kind: CallableValue,
        erased_companion: None,
      },
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        erased_companion: None,
      },
      owned_slot(I64, OwnedErased, erased_companion=Some({ value: 3 })),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
fn lifecycle_closure_body() -> @bytecode.FunctionBody {
  {
    slots: [owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0 }))],
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
}

///|
fn lifecycle_image(entry : @bytecode.FunctionBody) -> @bytecode.BytecodeImage {
  {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    functions: [
      BytecodeBody(lifecycle_initializer()),
      BytecodeBody(entry),
      BytecodeBody(lifecycle_closure_body()),
      RuntimeImport({
        abi_major: 1,
        parameters: [],
        result: Unit,
        symbol: "lane.test.fail",
      }),
    ],
    globals: [
      {
        representation: I64,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
      {
        representation: I64,
        cleanup: OwnedCallable,
        kind: CallableValue,
        erased_companion: None,
      },
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
        erased_companion: Some({ value: 3 }),
      },
    ],
    layouts: [ByteSequence, Environment({ value: 0 })],
    object_shapes: [
      Environment({
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
    constants: [b"a", b"b"],
  }
}

///|
fn lifecycle_registry() -> @runtime.RuntimeRegistry {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.fail",
      abi_major=1,
      parameters=[],
      result=Unit,
      invoke=(_context, _arguments) => raise Failure(message="boom"),
    ),
  )
  registry
}

///|
test "instance globals clean trivial reference callable and erased roots" {
  let loaded = match
    load(lifecycle_image(lifecycle_entry()), lifecycle_registry()) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(instance.execute(), Ok(()))
  assert_eq(instance.heap.live_bytes, 0)
  assert_true(instance.globals.all(value => value is None))
  assert_true(instance.initialized_globals.is_empty())
}

///|
test "cleanup-capable entry failures release initialized global roots" {
  let loaded = match
    load(lifecycle_image(lifecycle_entry(failing=true)), lifecycle_registry()) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(),
    Err(RuntimeImportFailure(symbol="lane.test.fail", message="boom")),
  )
  assert_eq(instance.heap.live_bytes, 0)
  assert_true(instance.globals.all(value => value is None))
  assert_true(instance.initialized_globals.is_empty())
}

///|
test "cleanup-capable initializer failures release initialized global roots" {
  let initializer = lifecycle_initializer()
  initializer.blocks[0].instructions.push(
    CallDirect({ value: 4 }, None, [], [], None),
  )
  let image = lifecycle_image(lifecycle_entry())
  image.functions[0] = BytecodeBody(initializer)
  let loaded = match load(image, lifecycle_registry()) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(),
    Err(RuntimeImportFailure(symbol="lane.test.fail", message="boom")),
  )
  assert_eq(instance.heap.live_bytes, 0)
  assert_true(instance.globals.all(value => value is None))
  assert_true(instance.initialized_globals.is_empty())
}
