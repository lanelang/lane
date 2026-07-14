///|
fn wasm_global_slot(
  representation : @bytecode.Representation,
  cleanup? : @bytecode.Cleanup = Trivial,
  erased_companion? : @bytecode.SlotId? = None,
) -> @bytecode.SlotMetadata {
  { representation, cleanup, erased_companion }
}

///|
fn wasm_global_body(
  slots : Array[@bytecode.SlotMetadata],
  instructions : Array[@bytecode.Instruction],
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
test "Wasm entry wrapper runs initializer before entry using linear roots" {
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_global",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let initializer = wasm_global_body([wasm_global_slot(I64)], [
    ConstInt({ value: 0 }, 42L),
    InitGlobal({ value: 0 }, { value: 0 }),
  ])
  let entry = wasm_global_body([wasm_global_slot(I64)], [
    BorrowGlobal({ value: 0 }, { value: 0 }),
    CallDirect({ value: 3 }, None, [], [{ value: 0 }], None),
  ])
  let image : @bytecode.BytecodeImage = {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    functions: [
      BytecodeBody(initializer),
      BytecodeBody(entry),
      RuntimeImport({
        abi_major: 1,
        user_arity: 1,
        symbol: "lane.test.observe_global",
      }),
    ],
    globals: [{ representation: I64, cleanup: Trivial, erased_companion: None }],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.wasm_module().globals.length(), 11)
  let instance = match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) => fail("instantiate failed: \{to_repr(error)}")
  }
  let heap_base = instance.store
    .get_global(instance.instance.global_addrs[1])
    .get()
  assert_eq(instance.execute(), Ok(()))
  assert_eq(observed, 42L)
  guard heap_base is I32(heap_base) else { fail("expected I32 heap base") }
  let memory = instance.store.get_mem(instance.instance.mem_addrs[0])
  assert_eq(memory.load_i32(heap_base - 16), 0)
}

///|
fn wasm_lifecycle_initializer() -> @bytecode.FunctionBody {
  let owned_ref = wasm_global_slot(I32, cleanup=OwnedRef)
  wasm_global_body(
    [
      owned_ref,
      owned_ref,
      owned_ref,
      owned_ref,
      wasm_global_slot(I64, cleanup=OwnedCallable),
      wasm_global_slot(I32),
      wasm_global_slot(
        I64,
        cleanup=OwnedErased,
        erased_companion=Some({ value: 5 }),
      ),
      wasm_global_slot(I64),
    ],
    [
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
  )
}

///|
fn wasm_lifecycle_entry() -> @bytecode.FunctionBody {
  wasm_global_body(
    [
      wasm_global_slot(I64),
      wasm_global_slot(I32),
      wasm_global_slot(I64),
      wasm_global_slot(I32),
      wasm_global_slot(
        I64,
        cleanup=OwnedErased,
        erased_companion=Some({ value: 3 }),
      ),
    ],
    [
      BorrowGlobal({ value: 0 }, { value: 0 }),
      BorrowGlobal({ value: 1 }, { value: 1 }),
      BorrowGlobal({ value: 2 }, { value: 2 }),
      BorrowGlobal({ value: 4 }, { value: 4 }),
    ],
  )
}

///|
fn wasm_lifecycle_image() -> @bytecode.BytecodeImage {
  {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    functions: [
      BytecodeBody(wasm_lifecycle_initializer()),
      BytecodeBody(wasm_lifecycle_entry()),
    ],
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
fn wasm_global_instance(
  image : @bytecode.BytecodeImage,
  config? : @loisvm_runtime.ExecutionConfig = @loisvm_runtime.ExecutionConfig::defaults(),
) -> ExecutionInstance raise {
  let loaded = match load(image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  match loaded.new_instance(config~) {
    Ok(instance) => instance
    Err(error) => fail("instantiate failed: \{to_repr(error)}")
  }
}

///|
test "Wasm global cleanup releases reference callable and erased roots" {
  let instance = wasm_global_instance(wasm_lifecycle_image())
  assert_eq(instance.execute(), Ok(()))
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
  guard instance.store.get_global(instance.instance.global_addrs[1]).get()
    is I32(heap_base) else {
    fail("expected I32 heap base")
  }
  let root_base = heap_base - 5 * 16
  let memory = instance.store.get_mem(instance.instance.mem_addrs[0])
  for index in 0..<5 {
    assert_eq(memory.load_i32(root_base + index * 16), 0)
  }
}

///|
test "Wasm initializer limits clean roots initialized before failure" {
  let instance = wasm_global_instance(wasm_lifecycle_image(), config={
    max_call_depth: None,
    max_live_heap_bytes: Some(16),
  })
  assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=LiveHeapBytes)))
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "Wasm entry failures clean initialized global roots" {
  let image = wasm_lifecycle_image()
  guard image.functions[1] is BytecodeBody(entry) else {
    fail("expected bytecode entry")
  }
  entry.blocks[0].instructions.push(InitGlobal({ value: 0 }, { value: 0 }))
  let instance = wasm_global_instance(image)
  assert_eq(
    instance.execute(),
    Err(InternalRuntimeFailure(detail="Wasm instance-global lifecycle failure")),
  )
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "Wasm reports invalid instance-global initialization" {
  let trivial_i64 = wasm_global_slot(I64)
  let make_image = fn(initializer, entry) -> @bytecode.BytecodeImage {
    {
      entry: { value: 2 },
      initializer: Some({ value: 1 }),
      functions: [BytecodeBody(initializer), BytecodeBody(entry)],
      globals: [
        { representation: I64, cleanup: Trivial, erased_companion: None },
      ],
      layouts: [],
      object_shapes: [],
      constants: [],
    }
  }
  let duplicate = make_image(
    wasm_global_body([trivial_i64], [
      ConstInt({ value: 0 }, 1L),
      InitGlobal({ value: 0 }, { value: 0 }),
      InitGlobal({ value: 0 }, { value: 0 }),
    ]),
    wasm_global_body([], []),
  )
  let incomplete = make_image(
    wasm_global_body([], []),
    wasm_global_body([], []),
  )
  let premature_read = make_image(
    wasm_global_body([trivial_i64], [BorrowGlobal({ value: 0 }, { value: 0 })]),
    wasm_global_body([], []),
  )
  for image in [duplicate, incomplete, premature_read] {
    assert_eq(
      wasm_global_instance(image).execute(),
      Err(
        InternalRuntimeFailure(detail="Wasm instance-global lifecycle failure"),
      ),
    )
  }
}
