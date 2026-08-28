///|
fn wasm_global_slot(
  representation : @physical.Representation,
  cleanup? : @physical.Cleanup = Trivial,
  kind? : @physical.SemanticValueKind = match cleanup {
    OwnedCallable => CallableValue
    OwnedRef => ByteSequenceValue
    OwnedErased => ErasedValue
    Trivial => ScalarValue
  },
  erased_companion? : @physical.SlotId? = None,
) -> @physical.SlotMetadata {
  { representation, cleanup, kind, erased_companion, }
}

///|
fn wasm_global_body(
  slots : Array[@physical.SlotMetadata],
  instructions : Array[@physical.Instruction],
) -> @physical.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None), }],
  }
}

///|
test "Wasm entry wrapper runs initializer before entry using linear roots" {
  let mut observed = 0L
  let initializer = wasm_global_body([wasm_global_slot(I64)], [
    ConstI64({ value: 0, }, 42L),
    InitGlobal({ value: 0, }, { value: 0, }),
  ])
  let entry = wasm_global_body([wasm_global_slot(I64)], [
    BorrowGlobal({ value: 0, }, { value: 0, }),
    CallDirect({ value: 3, }, None, [], [{ value: 0, }], None),
  ])
  let image : @physical.PhysicalProgram = {
    entry: { value: 2, },
    initializer: Some({ value: 1, }),
    data_family_count: 0,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [
          { representation: I64, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Unit,
      },
    ],
    functions: [
      PhysicalBody(initializer),
      PhysicalBody(entry),
      RuntimeImport({
        module_name: "lane.test",
        field_name: "observe_global",
        parameters: [Direct(I64)],
        result: Unit,
      }),
    ],
    globals: [
      {
        representation: I64,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match
    load(image, configure_host=(linker : @wasmoon_runtime.Linker) => {
      linker.add_host_func(
        "lane.test",
        "observe_global",
        values => {
          guard values is [I64(value)] else { raise TypeMismatch }
          observed = value
          []
        },
        func_type={ params: [I64], results: [], },
      )
    }) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.wasm_module().globals.length(), 10)
  let instance = match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) => fail("instantiate failed: \{Repr(error)}")
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
fn wasm_lifecycle_initializer() -> @physical.FunctionBody {
  let owned_ref = wasm_global_slot(I32, cleanup=OwnedRef)
  wasm_global_body(
    [
      owned_ref,
      owned_ref,
      owned_ref,
      wasm_global_slot(
        I32,
        cleanup=OwnedRef,
        kind=EnvironmentValue({ value: 0, }),
      ),
      wasm_global_slot(I64, cleanup=OwnedCallable),
      wasm_global_slot(I32, kind=LayoutValue),
      wasm_global_slot(
        I64,
        cleanup=OwnedErased,
        erased_companion=Some({ value: 5, }),
      ),
      wasm_global_slot(I64),
    ],
    [
      ConstI64({ value: 7, }, 42L),
      InitGlobal({ value: 0, }, { value: 7, }),
      ConstString({ value: 0, }, { value: 0, }),
      ConstString({ value: 1, }, { value: 1, }),
      ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
      InitGlobal({ value: 1, }, { value: 2, }),
      ConstString({ value: 0, }, { value: 0, }),
      ConstString({ value: 1, }, { value: 1, }),
      ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
      MakeEnv({ value: 3, }, { value: 0, }, Immediate({ value: 2, }), [], [
        { value: 2, },
      ]),
      MakeClosure({ value: 4, }, { value: 3, }, { value: 3, }),
      InitGlobal({ value: 2, }, { value: 4, }),
      ConstString({ value: 0, }, { value: 0, }),
      ConstString({ value: 1, }, { value: 1, }),
      ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
      ConstLayout({ value: 5, }, { value: 1, }),
      EraseI32({ value: 6, }, { value: 2, }),
      InitGlobal({ value: 4, }, { value: 6, }),
    ],
  )
}

///|
fn wasm_lifecycle_entry() -> @physical.FunctionBody {
  wasm_global_body(
    [
      wasm_global_slot(I64),
      wasm_global_slot(I32, kind=ByteSequenceValue),
      wasm_global_slot(I64, kind=CallableValue),
      wasm_global_slot(I32, kind=LayoutValue),
      wasm_global_slot(
        I64,
        cleanup=OwnedErased,
        erased_companion=Some({ value: 3, }),
      ),
    ],
    [
      BorrowGlobal({ value: 0, }, { value: 0, }),
      BorrowGlobal({ value: 1, }, { value: 1, }),
      BorrowGlobal({ value: 2, }, { value: 2, }),
      BorrowGlobal({ value: 4, }, { value: 4, }),
    ],
  )
}

///|
fn wasm_lifecycle_closure_body() -> @physical.FunctionBody {
  {
    slots: [
      wasm_global_slot(
        I32,
        cleanup=OwnedRef,
        kind=EnvironmentValue({ value: 0, }),
      ),
    ],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
    ],
  }
}

///|
fn wasm_lifecycle_image() -> @physical.PhysicalProgram {
  {
    entry: { value: 2, },
    initializer: Some({ value: 1, }),
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    functions: [
      PhysicalBody(wasm_lifecycle_initializer()),
      PhysicalBody(wasm_lifecycle_entry()),
      PhysicalBody(wasm_lifecycle_closure_body()),
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
        erased_companion: Some({ value: 3, }),
      },
    ],
    layouts: [ByteSequence, Environment({ value: 0, })],
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
fn wasm_global_instance(
  image : @physical.PhysicalProgram,
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
) -> @lane_wasm_runtime.ExecutionInstance raise {
  let loaded = match load(image) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  match loaded.new_instance(config~) {
    Ok(instance) => instance
    Err(error) => fail("instantiate failed: \{Repr(error)}")
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
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[9]).get(),
    I32(0),
  )
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
test "Wasm fatal control cleans initialized global roots" {
  let image = wasm_lifecycle_image()
  guard image.functions[1] is PhysicalBody(entry) else {
    fail("expected physical entry")
  }
  entry.slots.push(
    wasm_global_slot(I32, cleanup=OwnedRef, kind=ByteSequenceValue),
  )
  entry.blocks[0].instructions.push(ConstString({ value: 5, }, { value: 0, }))
  entry.blocks[0] = { ..entry.blocks[0], terminator: Fatal({ value: 5, }), }
  let instance = wasm_global_instance(image)
  assert_eq(instance.execute(), Err(Fatal(message="a")))
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "Wasm reports invalid instance-global initialization" {
  let trivial_i64 = wasm_global_slot(I64)
  let make_image = fn(initializer, entry) -> @physical.PhysicalProgram {
    {
      entry: { value: 2, },
      initializer: Some({ value: 1, }),
      data_family_count: 0,
      callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
      functions: [PhysicalBody(initializer), PhysicalBody(entry)],
      globals: [
        {
          representation: I64,
          cleanup: Trivial,
          kind: ScalarValue,
          erased_companion: None,
        },
      ],
      layouts: [],
      object_shapes: [],
      constants: [],
    }
  }
  let duplicate = make_image(
    wasm_global_body([trivial_i64], [
      ConstI64({ value: 0, }, 1L),
      InitGlobal({ value: 0, }, { value: 0, }),
      InitGlobal({ value: 0, }, { value: 0, }),
    ]),
    wasm_global_body([], []),
  )
  let incomplete = make_image(
    wasm_global_body([], []),
    wasm_global_body([], []),
  )
  let premature_read = make_image(
    wasm_global_body([trivial_i64], [BorrowGlobal({ value: 0, }, { value: 0, })]),
    wasm_global_body([], []),
  )
  for image in [duplicate, incomplete, premature_read] {
    assert_true(load(image) is Err(InvalidPhysicalProgram(_)))
  }
}

///|
fn wasm_linear_global_image(count : Int) -> @physical.PhysicalProgram {
  let slots = Array::make(count, wasm_global_slot(I64, cleanup=OwnedCallable))
  let instructions : Array[@physical.Instruction] = []
  let globals : Array[@physical.GlobalMetadata] = []
  for index in 0..<count {
    instructions.push(ConstFunction({ value: index, }, { value: 2, }))
    instructions.push(InitGlobal({ value: index, }, { value: index, }))
    globals.push({
      representation: I64,
      cleanup: OwnedCallable,
      kind: CallableValue,
      erased_companion: None,
    })
  }
  {
    entry: { value: 2, },
    initializer: Some({ value: 1, }),
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    functions: [
      PhysicalBody(wasm_global_body(slots, instructions)),
      PhysicalBody(wasm_global_body([], [])),
    ],
    globals,
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
fn lifecycle_function_scale(count : Int) -> (Int, Int) {
  let observed = @wasm_target.compile_observed(
    certify_physical_program_test(wasm_linear_global_image(count)),
  ).unwrap()
  let scale = observed.scale
  let mut cleanup_size = -1
  let mut entry_size = -1
  for provenance in observed.functions {
    let mut selected = false
    match provenance.origin {
      RuntimeFunction(InstanceGlobalCleanup) => {
        cleanup_size = 0
        selected = true
      }
      EntryWrapper => {
        entry_size = 0
        selected = true
      }
      _ => ()
    }
    if selected {
      for function in scale.functions {
        if function.index == provenance.index {
          match provenance.origin {
            RuntimeFunction(InstanceGlobalCleanup) =>
              cleanup_size = function.instruction_count
            EntryWrapper => entry_size = function.instruction_count
            _ => ()
          }
        }
      }
    }
  }
  (cleanup_size, entry_size)
}

///|
test "Wasm instance-global lifecycle code is independent of global count" {
  let one = lifecycle_function_scale(1)
  let many = lifecycle_function_scale(64)
  assert_eq(one, many)
  debug_inspect(one, content="(65, 11)")
}
