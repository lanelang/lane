///|
fn owned_slot(
  representation : @bytecode.Representation,
  cleanup : @bytecode.Cleanup,
  erased_companion? : @bytecode.SlotId? = None,
) -> @bytecode.SlotMetadata {
  { representation, cleanup, erased_companion }
}

///|
fn lifecycle_initializer() -> @bytecode.FunctionBody {
  let owned_ref = owned_slot(I32, OwnedRef)
  {
    slots: [
      owned_ref,
      owned_ref,
      owned_ref,
      owned_ref,
      owned_slot(I64, OwnedCallable),
      trivial_slot(I32),
      owned_slot(I64, OwnedErased, erased_companion=Some({ value: 5 })),
      trivial_slot(I64),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstInt({ value: 7 }, 42L),
          InitGlobal({ value: 0 }, { value: 7 }),
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          StringConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          InitGlobal({ value: 1 }, { value: 2 }),
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          StringConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          MakeEnv({ value: 3 }, { value: 0 }, Immediate({ value: 2 }), [], [
            { value: 2 },
          ]),
          MakeClosure({ value: 4 }, { value: 2 }, { value: 3 }),
          InitGlobal({ value: 2 }, { value: 4 }),
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          StringConcat({ value: 2 }, { value: 0 }, { value: 1 }),
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
    instructions.push(BorrowGlobal({ value: 0 }, { value: 99 }))
  }
  {
    slots: [
      trivial_slot(I64),
      trivial_slot(I32),
      trivial_slot(I64),
      trivial_slot(I32),
      owned_slot(I64, OwnedErased, erased_companion=Some({ value: 3 })),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
fn lifecycle_image(entry : @bytecode.FunctionBody) -> @bytecode.BytecodeImage {
  {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    functions: [BytecodeBody(lifecycle_initializer()), BytecodeBody(entry)],
    globals: [
      { representation: I64, cleanup: Trivial, erased_companion: None },
      { representation: I32, cleanup: OwnedRef, erased_companion: None },
      { representation: I64, cleanup: OwnedCallable, erased_companion: None },
      { representation: I32, cleanup: Trivial, erased_companion: None },
      {
        representation: I64,
        cleanup: OwnedErased,
        erased_companion: Some({ value: 3 }),
      },
    ],
    layouts: [String, Environment({ value: 0 })],
    object_shapes: [
      Environment({
        stored_witness_count: 0,
        members: [
          { representation: I32, cleanup: OwnedRef, witness_ordinal: None },
        ],
      }),
    ],
    constants: [b"a", b"b"],
  }
}

///|
test "instance globals clean trivial reference callable and erased roots" {
  let loaded = match
    load(lifecycle_image(lifecycle_entry()), @runtime.RuntimeRegistry::new()) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{to_repr(error)}")
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
    load(
      lifecycle_image(lifecycle_entry(failing=true)),
      @runtime.RuntimeRegistry::new(),
    ) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(),
    Err(InternalRuntimeFailure(detail="GlobalId 99 is out of range")),
  )
  assert_eq(instance.heap.live_bytes, 0)
  assert_true(instance.globals.all(value => value is None))
  assert_true(instance.initialized_globals.is_empty())
}

///|
test "cleanup-capable initializer failures release initialized global roots" {
  let initializer = lifecycle_initializer()
  initializer.blocks[0].instructions.push(
    BorrowGlobal({ value: 7 }, { value: 99 }),
  )
  let image = lifecycle_image(lifecycle_entry())
  image.functions[0] = BytecodeBody(initializer)
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(),
    Err(InternalRuntimeFailure(detail="GlobalId 99 is out of range")),
  )
  assert_eq(instance.heap.live_bytes, 0)
  assert_true(instance.globals.all(value => value is None))
  assert_true(instance.initialized_globals.is_empty())
}
