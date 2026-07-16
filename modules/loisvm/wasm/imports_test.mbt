///|
fn import_test_slot(
  representation : @bytecode.Representation,
  cleanup? : @bytecode.Cleanup = Trivial,
) -> @bytecode.SlotMetadata {
  { representation, cleanup, erased_companion: None }
}

///|
fn import_test_body(
  slots : Array[@bytecode.SlotMetadata],
  instructions : Array[@bytecode.Instruction],
  terminator? : @bytecode.Terminator = Return(None),
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator }],
  }
}

///|
fn import_test_image(
  body : @bytecode.FunctionBody,
  import_ : @bytecode.RuntimeImport,
  layouts? : Array[@bytecode.LayoutRecipe] = [],
  constants? : Array[Bytes] = [],
) -> @bytecode.BytecodeImage {
  {
    entry: { value: 1 },
    initializer: None,
    functions: [BytecodeBody(body), RuntimeImport(import_)],
    globals: [],
    layouts,
    object_shapes: [],
    constants,
  }
}

///|
fn loaded_instance(
  image : @bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
  mode? : ExecutionMode = Jit,
) -> ExecutionInstance raise {
  let loaded = match load(image, registry, mode~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{to_repr(error)}")
  }
}

///|
test "JIT and interpreter modes execute the same scalar import" {
  for mode in [ExecutionMode::Jit, Interpreter] {
    let mut observed = 0L
    let registry = @loisvm_runtime.RuntimeRegistry::new()
    registry.register(
      @loisvm_runtime.RuntimeBinding::new(
        symbol="lane.test.observe_mode",
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
    let body = import_test_body([import_test_slot(I64)], [
      ConstInt({ value: 0 }, 42L),
      CallDirect({ value: 2 }, None, [], [{ value: 0 }], None),
    ])
    let instance = loaded_instance(
      import_test_image(body, {
        abi_major: 1,
        parameters: [Int],
        result: Unit,
        symbol: "lane.test.observe_mode",
      }),
      registry,
      mode~,
    )
    assert_eq(instance.execute(), Ok(()))
    assert_eq(observed, 42L)
  }
}

///|
test "registry-backed scalar import uses its generated adapter" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.add_one",
      abi_major=1,
      parameters=[Int],
      result=Int,
      invoke=fn(_context, arguments) {
        guard arguments is [Int(value)] else { return Int(0L) }
        Int(value + 1L)
      },
    ),
  )
  let body = import_test_body([import_test_slot(I64), import_test_slot(I64)], [
    ConstInt({ value: 0 }, 41L),
    CallDirect({ value: 2 }, None, [], [{ value: 0 }], Some({ value: 1 })),
  ])
  let instance = loaded_instance(
    import_test_image(body, {
      abi_major: 1,
      parameters: [Int],
      result: Int,
      symbol: "lane.test.add_one",
    }),
    registry,
  )
  assert_eq(instance.execute(), Ok(()))
  assert_eq(instance.execute(), Err(InstanceNotReady))
}

///|
test "Wasm adapters synthesize logical Unit runtime arguments" {
  let mut called = false
  let mut valid_arguments = false
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.unit_argument",
      abi_major=1,
      parameters=[Unit],
      result=Unit,
      invoke=(_context, arguments) => {
        valid_arguments = arguments is [Unit]
        called = true
        Unit
      },
    ),
  )
  let body = import_test_body([], [CallDirect({ value: 2 }, None, [], [], None)])
  let instance = loaded_instance(
    import_test_image(body, {
      abi_major: 1,
      parameters: [Unit],
      result: Unit,
      symbol: "lane.test.unit_argument",
    }),
    registry,
  )
  assert_eq(instance.execute(), Ok(()))
  assert_true(called)
  assert_true(valid_arguments)
}

///|
test "String import reads borrowed bytes and allocates its result in Lane memory" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.suffix",
      abi_major=1,
      parameters=[String],
      result=String,
      invoke=fn(_context, arguments) {
        guard arguments is [BorrowedString(value)] else { return String("") }
        String(value.to_string() + "!")
      },
    ),
  )
  let body = import_test_body(
    [
      import_test_slot(I32, cleanup=OwnedRef),
      import_test_slot(I32, cleanup=OwnedRef),
    ],
    [
      ConstString({ value: 0 }, { value: 0 }),
      CallDirect({ value: 2 }, None, [], [{ value: 0 }], Some({ value: 1 })),
      Release({ value: 1 }),
    ],
  )
  let instance = loaded_instance(
    import_test_image(
      body,
      {
        abi_major: 1,
        parameters: [String],
        result: String,
        symbol: "lane.test.suffix",
      },
      layouts=[String],
      constants=[b"Lane"],
    ),
    registry,
  )
  assert_eq(instance.execute(), Ok(()))
}

///|
test "runtime import failure is reported out of band" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.fail",
      abi_major=1,
      parameters=[],
      result=Unit,
      invoke=(_context, _arguments) => raise Failure(message="boom"),
    ),
  )
  let body = import_test_body([], [CallDirect({ value: 2 }, None, [], [], None)])
  let instance = loaded_instance(
    import_test_image(body, {
      abi_major: 1,
      parameters: [],
      result: Unit,
      symbol: "lane.test.fail",
    }),
    registry,
  )
  assert_eq(
    instance.execute(),
    Err(RuntimeImportFailure(symbol="lane.test.fail", message="boom")),
  )
}

///|
test "failing String import releases its transferred argument" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.fail_string",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=(_context, _arguments) => raise Failure(message="boom"),
    ),
  )
  let body = import_test_body(
    [
      import_test_slot(I32, cleanup=OwnedRef),
      import_test_slot(I32, cleanup=OwnedRef),
      import_test_slot(I32, cleanup=OwnedRef),
    ],
    [
      ConstString({ value: 0 }, { value: 0 }),
      ConstString({ value: 1 }, { value: 1 }),
      StringConcat({ value: 2 }, { value: 0 }, { value: 1 }),
      CallDirect({ value: 2 }, None, [], [{ value: 2 }], None),
    ],
  )
  let instance = loaded_instance(
    import_test_image(
      body,
      {
        abi_major: 1,
        parameters: [String],
        result: Unit,
        symbol: "lane.test.fail_string",
      },
      layouts=[String],
      constants=[b"Lane", b"!"],
    ),
    registry,
  )
  assert_eq(
    instance.execute(),
    Err(RuntimeImportFailure(symbol="lane.test.fail_string", message="boom")),
  )
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "fatal import unwinding releases owners retained by the caller frame" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.fail_with_live_owner",
      abi_major=1,
      parameters=[],
      result=Unit,
      invoke=(_context, _arguments) => raise Failure(message="boom"),
    ),
  )
  let body = import_test_body(
    [
      import_test_slot(I32, cleanup=OwnedRef),
      import_test_slot(I32, cleanup=OwnedRef),
      import_test_slot(I32, cleanup=OwnedRef),
    ],
    [
      ConstString({ value: 0 }, { value: 0 }),
      ConstString({ value: 1 }, { value: 1 }),
      StringConcat({ value: 2 }, { value: 0 }, { value: 1 }),
      CallDirect({ value: 2 }, None, [], [], None),
      Release({ value: 2 }),
    ],
  )
  let instance = loaded_instance(
    import_test_image(
      body,
      {
        abi_major: 1,
        parameters: [],
        result: Unit,
        symbol: "lane.test.fail_with_live_owner",
      },
      layouts=[String],
      constants=[b"Lane", b"!"],
    ),
    registry,
  )
  assert_eq(
    instance.execute(),
    Err(
      RuntimeImportFailure(
        symbol="lane.test.fail_with_live_owner",
        message="boom",
      ),
    ),
  )
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "invalid host String results become runtime import failures" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.non_ascii",
      abi_major=1,
      parameters=[],
      result=String,
      invoke=fn(_context, _arguments) { String("é") },
    ),
  )
  let body = import_test_body([import_test_slot(I32, cleanup=OwnedRef)], [
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    Release({ value: 0 }),
  ])
  let instance = loaded_instance(
    import_test_image(
      body,
      {
        abi_major: 1,
        parameters: [],
        result: String,
        symbol: "lane.test.non_ascii",
      },
      layouts=[String],
    ),
    registry,
  )
  assert_true(
    instance.execute()
    is Err(RuntimeImportFailure(symbol="lane.test.non_ascii", message=_)),
  )
}

///|
test "host String allocation preserves live heap resource failures" {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.host_string",
      abi_major=1,
      parameters=[],
      result=String,
      invoke=fn(_context, _arguments) { String("Lane") },
    ),
  )
  let body = import_test_body([import_test_slot(I32, cleanup=OwnedRef)], [
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    Release({ value: 0 }),
  ])
  let loaded = match
    load(
      import_test_image(
        body,
        {
          abi_major: 1,
          parameters: [],
          result: String,
          symbol: "lane.test.host_string",
        },
        layouts=[String],
      ),
      registry,
    ) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  let instance = match
    loaded.new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: Some(8),
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{to_repr(error)}")
  }
  assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=LiveHeapBytes)))
}

///|
test "Wasm loading rejects missing and incompatible bindings before compilation" {
  let image = import_test_image(import_test_body([], []), {
    abi_major: 1,
    parameters: [],
    result: Unit,
    symbol: "lane.test.missing",
  })
  assert_true(
    load(image, @loisvm_runtime.RuntimeRegistry::new())
    is Err(
      RuntimeImportResolution(
        error=UnresolvedImport(symbol="lane.test.missing")
      )
    ),
  )
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.missing",
      abi_major=2,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, _arguments) { Unit },
    ),
  )
  assert_true(
    load(image, registry)
    is Err(
      RuntimeImportResolution(
        error=AbiMismatch(
          symbol="lane.test.missing",
          expected_major=1,
          actual_major=2
        )
      )
    ),
  )
  let wrong_parameter = @loisvm_runtime.RuntimeRegistry::new()
  wrong_parameter.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.missing",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, _arguments) { Unit },
    ),
  )
  assert_true(
    load(image, wrong_parameter)
    is Err(
      RuntimeImportResolution(
        error=ParameterKindsMismatch(
          symbol="lane.test.missing",
          expected=[],
          actual=[Int]
        )
      )
    ),
  )
  let wrong_result = @loisvm_runtime.RuntimeRegistry::new()
  wrong_result.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.missing",
      abi_major=1,
      parameters=[],
      result=Int,
      invoke=fn(_context, _arguments) { Int(0L) },
    ),
  )
  assert_true(
    load(image, wrong_result)
    is Err(
      RuntimeImportResolution(
        error=ResultKindMismatch(
          symbol="lane.test.missing",
          expected=Unit,
          actual=Int
        )
      )
    ),
  )
}
