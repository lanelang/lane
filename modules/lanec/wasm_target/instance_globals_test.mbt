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
test "Wasm start initializes instance globals before an export is called" {
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
    exports: [@physical.physical_export(function={ value: 2, }, name="_start")],
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
  let instance = match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  guard instance.store.get_global(instance.instance.global_addrs[1]).get()
    is I32(heap_base) else {
    fail("expected I32 heap base")
  }
  let memory = instance.store.get_mem(instance.instance.mem_addrs[0])
  assert_eq(memory.load_i64(heap_base - 8), 42L)
  assert_eq(observed, 0L)
  assert_eq(instance.execute(), Ok(Returned))
  assert_eq(observed, 42L)
}

///|
fn wasm_global_instance(
  image : @physical.PhysicalProgram,
) -> @lane_wasm_runtime.ExecutionInstance raise {
  let loaded = match load(image) {
    Ok(loaded) => loaded
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
}

///|
test "Wasm fatal control consumes the instance" {
  let image : @physical.PhysicalProgram = {
    exports: [@physical.physical_export(function={ value: 1, }, name="_start")],
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    functions: [
      PhysicalBody({
        ..wasm_global_body(
          [wasm_global_slot(I32, cleanup=OwnedRef, kind=ByteSequenceValue)],
          [ConstString({ value: 0, }, { value: 0, })],
        ),
        blocks: [
          {
            parameters: [],
            instructions: [ConstString({ value: 0, }, { value: 0, })],
            terminator: Fatal,
          },
        ],
      }),
    ],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"boom"],
  }
  let instance = wasm_global_instance(image)
  assert_true(instance.execute() is Err(EngineTrap(_)))
  assert_eq(instance.execute(), Err(InstanceNotReady))
}

///|
test "Wasm reports invalid instance-global initialization" {
  let trivial_i64 = wasm_global_slot(I64)
  let make_image = fn(initializer, entry) -> @physical.PhysicalProgram {
    {
      exports: [
        @physical.physical_export(function={ value: 2, }, name="_start"),
      ],
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
    exports: [@physical.physical_export(function={ value: 2, }, name="_start")],
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
fn boundary_function_scale(count : Int) -> (Int, Int) {
  let observed = @wasm_target.compile_observed(
    certify_physical_program_test(wasm_linear_global_image(count)),
  ).unwrap()
  let scale = observed.scale
  let mut initializer_size = -1
  let mut export_size = -1
  for provenance in observed.functions {
    let mut selected = false
    match provenance.origin {
      InitializerWrapper => {
        initializer_size = 0
        selected = true
      }
      ExportWrapper(_) => {
        export_size = 0
        selected = true
      }
      _ => ()
    }
    if selected {
      for function in scale.functions {
        if function.index == provenance.index {
          match provenance.origin {
            InitializerWrapper => initializer_size = function.instruction_count
            ExportWrapper(_) => export_size = function.instruction_count
            _ => ()
          }
        }
      }
    }
  }
  (initializer_size, export_size)
}

///|
test "Wasm initialization and export wrappers are independent of global count" {
  let one = boundary_function_scale(1)
  let many = boundary_function_scale(64)
  assert_eq(one, many)
  debug_inspect(one, content="(3, 3)")
}
