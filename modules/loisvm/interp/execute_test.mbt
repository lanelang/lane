///|
fn trivial_slot(
  representation : @bytecode.Representation,
  kind? : @bytecode.SemanticValueKind = ScalarValue,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, kind, erased_companion: None, }
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
    inputs: { environment: None, witnesses: [], user_parameters: parameters, },
    result,
    blocks: [{ parameters: [], instructions, terminator, }],
  }
}

///|
test "interpreter executes direct and runtime calls once" {
  let mut observed = 0L
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.observe",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        match arguments {
          [I64(value)] => {
            observed = value
            Unit
          }
          _ => Unit
        }
      },
    ),
  )
  let entry = body(
    slots=[trivial_slot(I64), trivial_slot(I64)],
    result=Unit,
    instructions=[
      ConstI64({ value: 0, }, 41L),
      CallDirect({ value: 2, }, None, [], [{ value: 0, }], Some({ value: 1, })),
      CallDirect({ value: 3, }, None, [], [{ value: 1, }], None),
    ],
    terminator=Return(None),
  )
  let add_one = body(
    slots=[trivial_slot(I64), trivial_slot(I64), trivial_slot(I64)],
    parameters=[{ value: 0, }],
    result=Value(I64, Trivial, ScalarValue),
    instructions=[
      ConstI64({ value: 1, }, 1L),
      I64Add({ value: 2, }, { value: 0, }, { value: 1, }),
    ],
    terminator=Return(Some({ value: 2, })),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [
          { representation: I64, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Value(I64, Trivial, ScalarValue),
      },
      {
        witnesses: [],
        parameters: [
          { representation: I64, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Unit,
      },
    ],
    globals: [],
    functions: [
      BytecodeBody(entry),
      BytecodeBody(add_one),
      RuntimeImport({
        abi_major: 1,
        parameters: [I64],
        result: Unit,
        symbol: "lane.test.observe",
      }),
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(_) => fail("load failed")
  }
  let instance = loaded.new_instance()
  assert_eq(instance.execute(), Ok(()))
  assert_eq(observed, 42L)
  assert_eq(instance.execute(), Err(InstanceNotReady))
}

///|
struct RuntimeContextObservation {
  import_call_count : Int
  identity_matrix : Array[Array[Bool]]
} derive(Debug)

///|
fn runtime_context_observation(
  contexts : Array[@runtime.RuntimeContext],
) -> RuntimeContextObservation {
  {
    import_call_count: contexts.length(),
    identity_matrix: contexts.map(fn(left) {
      contexts.map(fn(right) { physical_equal(left, right) })
    }),
  }
}

///|
test "interpreter initializer and entry share one runtime context" {
  let contexts : Array[@runtime.RuntimeContext] = []
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="lane.test.context",
      abi_major=1,
      parameters=[],
      result=Unit,
      invoke=fn(context, _arguments) {
        contexts.push(context)
        Unit
      },
    ),
  )
  let call_import = body(
    slots=[],
    result=Unit,
    instructions=[CallDirect({ value: 3, }, None, [], [], None)],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 2, },
    initializer: Some({ value: 1, }),
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [
      BytecodeBody(call_import),
      BytecodeBody(call_import),
      RuntimeImport({
        abi_major: 1,
        parameters: [],
        result: Unit,
        symbol: "lane.test.context",
      }),
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  debug_inspect(
    runtime_context_observation(contexts),
    content=(
      #|{
      #|  import_call_count: 2,
      #|  identity_matrix: [[true, true], [true, true]],
      #|}
    ),
  )
  assert_eq(loaded.new_instance().execute(), Ok(()))
  debug_inspect(
    runtime_context_observation(contexts),
    content=(
      #|{
      #|  import_call_count: 4,
      #|  identity_matrix: [
      #|    [true, true, false, false],
      #|    [true, true, false, false],
      #|    [false, false, true, true],
      #|    [false, false, true, true],
      #|  ],
      #|}
    ),
  )
}

///|
test "interpreter execution can be interrupted" {
  let entry = body(
    slots=[],
    result=Unit,
    instructions=[],
    terminator=TailCallDirect({ value: 1, }, None, [], []),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let polls = [0]
  let instance = loaded.new_instance()
  assert_eq(
    instance.execute(
      cancel=Some(fn() {
        polls[0] += 1
        polls[0] >= 4
      }),
    ),
    Err(Interrupted),
  )
  assert_eq(instance.execute(), Err(InstanceNotReady))
}

///|
test "interpreter rejects ownership-only CallValue ABI mismatch before dispatch" {
  let callable : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    erased_companion: None,
  }
  let entry = body(
    slots=[callable, trivial_slot(I32)],
    result=Unit,
    instructions=[
      ConstFunction({ value: 0, }, { value: 2, }),
      ConstBool({ value: 1, }, true),
      CallValue({ value: 0, }, { value: 1, }, [], [{ value: 1, }], None),
    ],
    terminator=Return(None),
  )
  let owned_ref : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let target = body(
    slots=[owned_ref],
    parameters=[{ value: 0, }],
    result=Unit,
    instructions=[Release({ value: 0, })],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [
          { representation: I32, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Unit,
      },
      {
        witnesses: [],
        parameters: [
          { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue, },
        ],
        result: Unit,
      },
    ],
    globals: [],
    functions: [BytecodeBody(entry), BytecodeBody(target)],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(
    loaded.new_instance().execute(),
    Err(
      InvalidCallableInvocation(
        AbiMismatch(function={ value: 2, }, expected={ value: 1, }, actual={
          value: 2,
        }),
      ),
    ),
  )
}

///|
test "interpreter synthesizes logical Unit runtime arguments" {
  let mut called = false
  let mut valid_arguments = false
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
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
  let entry = body(
    slots=[],
    result=Unit,
    instructions=[CallDirect({ value: 2, }, None, [], [], None)],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [
      BytecodeBody(entry),
      RuntimeImport({
        abi_major: 1,
        parameters: [Unit],
        result: Unit,
        symbol: "lane.test.unit_argument",
      }),
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_true(called)
  assert_true(valid_arguments)
}

///|
test "tail calls preserve logical call depth" {
  let entry = body(
    slots=[],
    result=Unit,
    instructions=[],
    terminator=TailCallDirect({ value: 2, }, None, [], []),
  )
  let target = body(
    slots=[],
    result=Unit,
    instructions=[],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [BytecodeBody(entry), BytecodeBody(target)],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(_) => fail("load failed")
  }
  let instance = loaded.new_instance(config={
    max_call_depth: Some(1),
    max_live_heap_bytes: None,
    max_host_objects: None,
  })
  assert_eq(instance.execute(), Ok(()))
}

///|
test "object witnesses load independently from data and environment members" {
  let data_ref : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 0, }),
    erased_companion: None,
  }
  let environment_ref : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: EnvironmentValue({ value: 1, }),
    erased_companion: None,
  }
  let entry = body(
    slots=[
      trivial_slot(I32, kind=LayoutValue),
      data_ref,
      trivial_slot(I32, kind=LayoutValue),
      environment_ref,
      trivial_slot(I32, kind=LayoutValue),
    ],
    result=Unit,
    instructions=[
      ConstLayout({ value: 0, }, { value: 1, }),
      MakeData(
        { value: 1, },
        { value: 0, },
        Immediate({ value: 2, }),
        [{ value: 0, }],
        [],
      ),
      LoadObjectWitness({ value: 2, }, { value: 0, }, { value: 1, }, 0),
      Release({ value: 1, }),
      MakeEnv(
        { value: 3, },
        { value: 1, },
        Immediate({ value: 3, }),
        [{ value: 0, }],
        [],
      ),
      LoadObjectWitness({ value: 4, }, { value: 1, }, { value: 3, }, 0),
      Release({ value: 3, }),
    ],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Bool, Data({ value: 0, }), Environment({ value: 1, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 1,
        members: [],
      }),
      Environment({ stored_witness_count: 1, members: [], }),
    ],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "returning calls enforce logical depth" {
  let entry = body(
    slots=[],
    result=Unit,
    instructions=[CallDirect({ value: 2, }, None, [], [], None)],
    terminator=Return(None),
  )
  let target = body(
    slots=[],
    result=Unit,
    instructions=[],
    terminator=Return(None),
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [BytecodeBody(entry), BytecodeBody(target)],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(_) => fail("load failed")
  }
  let instance = loaded.new_instance(config={
    max_call_depth: Some(1),
    max_live_heap_bytes: None,
    max_host_objects: None,
  })
  assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=CallDepth)))
}

///|
test "non-positive execution limits provide zero budget" {
  let empty_entry = body(
    slots=[],
    result=Unit,
    instructions=[],
    terminator=Return(None),
  )
  let empty_image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [BytecodeBody(empty_entry)],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let empty_loaded = match load(empty_image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  for limit in [0, -1] {
    let instance = empty_loaded.new_instance(config={
      max_call_depth: Some(limit),
      max_live_heap_bytes: None,
      max_host_objects: None,
    })
    assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=CallDepth)))
  }
  let owned_string : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let allocating_entry = body(
    slots=[owned_string, owned_string, owned_string],
    result=Unit,
    instructions=[
      ConstString({ value: 0, }, { value: 0, }),
      ConstString({ value: 1, }, { value: 1, }),
      ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
      Release({ value: 2, }),
    ],
    terminator=Return(None),
  )
  let allocating_image : @bytecode.BytecodeImage = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [BytecodeBody(allocating_entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"a", b"b"],
  }
  let allocating_loaded = match
    load(allocating_image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  for limit in [0, -1] {
    let instance = allocating_loaded.new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: Some(limit),
      max_host_objects: None,
    })
    assert_eq(
      instance.execute(),
      Err(ExecutionResourceLimit(kind=LiveHeapBytes)),
    )
  }
}
