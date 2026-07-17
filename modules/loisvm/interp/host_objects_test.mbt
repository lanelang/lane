///|
priv struct InterpreterHostObject {
  id : Int
  mut closed : Bool
}

///|
fn host_owned_ref_slot() -> @bytecode.SlotMetadata {
  { representation: I32, cleanup: OwnedRef, erased_companion: None }
}

///|
fn host_unit_body(
  slots~ : Array[@bytecode.SlotMetadata],
  instructions~ : Array[@bytecode.Instruction],
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
fn host_object_new_binding(
  store : @runtime.HostObjectStore[InterpreterHostObject],
  next_id : Ref[Int],
  finalized : Ref[Int],
) -> @runtime.RuntimeBinding {
  @runtime.RuntimeBinding::typed(
    symbol="lane.test.host_object_new",
    abi_major=1,
    parameters=@runtime.HostParameters::none(),
    result=@runtime.HostResult::host_object(store, finalizer=_object => {
      finalized.val += 1
    }),
    invoke=fn(_context, _arguments) {
      next_id.val += 1
      { id: next_id.val, closed: false }
    },
  )
}

///|
fn host_object_runtime_import(
  symbol : String,
  parameters : Array[@bytecode.RuntimeValueKind],
  result : @bytecode.RuntimeValueKind,
) -> @bytecode.FunctionEntry {
  RuntimeImport({ abi_major: 1, parameters, result, symbol })
}

///|
test "interpreter stores shared Host Objects in data and environments" {
  let store : @runtime.HostObjectStore[InterpreterHostObject] = @runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let observed : Array[Int] = []
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(host_object_new_binding(store, next_id, finalized))
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="lane.test.host_object_observe",
      abi_major=1,
      parameters=@runtime.HostParameters::one(
        @runtime.HostParameter::host_object(store),
      ),
      result=@runtime.HostResult::unit(),
      invoke=fn(_context, object : InterpreterHostObject) {
        observed.push(object.id)
      },
    ),
  )
  let owned_ref = host_owned_ref_slot()
  let entry = host_unit_body(
    slots=[owned_ref, owned_ref, owned_ref, owned_ref, owned_ref],
    instructions=[
      CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      MakeData({ value: 1 }, { value: 0 }, Immediate({ value: 2 }), [], [
        { value: 0 },
      ]),
      ConsumeFields({ value: 0 }, { value: 1 }, [
        {
          member_index: 0,
          result: { value_destination: { value: 2 }, witness_destination: None },
        },
      ]),
      CallDirect({ value: 3 }, None, [], [{ value: 2 }], None),
      CallDirect({ value: 2 }, None, [], [], Some({ value: 3 })),
      MakeEnv({ value: 4 }, { value: 1 }, Immediate({ value: 3 }), [], [
        { value: 3 },
      ]),
      Release({ value: 4 }),
    ],
  )
  let owned_member : @bytecode.MemberSchema = {
    representation: I32,
    cleanup: OwnedRef,
    witness_ordinal: None,
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(entry),
      host_object_runtime_import("lane.test.host_object_new", [], Opaque),
      host_object_runtime_import(
        "lane.test.host_object_observe",
        [Opaque],
        Unit,
      ),
    ],
    layouts: [Reference, Data({ value: 0 }), Environment({ value: 1 })],
    object_shapes: [
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [owned_member],
      }),
      Environment({ stored_witness_count: 0, members: [owned_member] }),
    ],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  let result = loaded.new_instance().execute()
  debug_inspect((result, observed, finalized.val), content="(Ok(()), [1], 2)")
}

///|
test "interpreter finalizes Host Object globals during normal shutdown" {
  let store : @runtime.HostObjectStore[InterpreterHostObject] = @runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(host_object_new_binding(store, next_id, finalized))
  let initializer = host_unit_body(slots=[host_owned_ref_slot()], instructions=[
    CallDirect({ value: 3 }, None, [], [], Some({ value: 0 })),
    InitGlobal({ value: 0 }, { value: 0 }),
  ])
  let entry = host_unit_body(slots=[], instructions=[])
  let image : @bytecode.BytecodeImage = {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    globals: [
      { representation: I32, cleanup: OwnedRef, erased_companion: None },
    ],
    functions: [
      BytecodeBody(initializer),
      BytecodeBody(entry),
      host_object_runtime_import("lane.test.host_object_new", [], Opaque),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  debug_inspect(
    (loaded.new_instance().execute(), finalized.val),
    content="(Ok(()), 1)",
  )
}

///|
test "interpreter rolls back rejected Host Object results" {
  let store : @runtime.HostObjectStore[InterpreterHostObject] = @runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(host_object_new_binding(store, next_id, finalized))
  let entry = host_unit_body(slots=[host_owned_ref_slot()], instructions=[
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    Release({ value: 0 }),
  ])
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(entry),
      host_object_runtime_import("lane.test.host_object_new", [], Opaque),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  let object_limit = loaded
    .new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: None,
      max_host_objects: Some(0),
    })
    .execute()
  let heap_limit = loaded
    .new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: Some(0),
      max_host_objects: None,
    })
    .execute()
  debug_inspect(
    (object_limit, heap_limit, finalized.val),
    content=(
      #|(
      #|  Err(ExecutionResourceLimit(kind=HostObjects)),
      #|  Err(ExecutionResourceLimit(kind=LiveHeapBytes)),
      #|  2,
      #|)
    ),
  )
}

///|
test "interpreter reports Host Object use after explicit close" {
  let store : @runtime.HostObjectStore[InterpreterHostObject] = @runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(host_object_new_binding(store, next_id, finalized))
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="lane.test.host_object_close",
      abi_major=1,
      parameters=@runtime.HostParameters::one(
        @runtime.HostParameter::host_object(store),
      ),
      result=@runtime.HostResult::unit(),
      invoke=fn(_context, object : InterpreterHostObject) {
        object.closed = true
      },
    ),
  )
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="lane.test.host_object_read",
      abi_major=1,
      parameters=@runtime.HostParameters::one(
        @runtime.HostParameter::host_object(store),
      ),
      result=@runtime.HostResult::int(),
      invoke=(_context, object : InterpreterHostObject) => {
        if object.closed {
          raise Failure(message="Host Object is closed")
        }
        object.id.to_int64()
      },
    ),
  )
  let owned_ref = host_owned_ref_slot()
  let entry = host_unit_body(
    slots=[
      owned_ref,
      owned_ref,
      { representation: I64, cleanup: Trivial, erased_companion: None },
    ],
    instructions=[
      CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      RetainCopy({ value: 1 }, { value: 0 }),
      CallDirect({ value: 3 }, None, [], [{ value: 0 }], None),
      CallDirect({ value: 4 }, None, [], [{ value: 1 }], Some({ value: 2 })),
    ],
  )
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(entry),
      host_object_runtime_import("lane.test.host_object_new", [], Opaque),
      host_object_runtime_import("lane.test.host_object_close", [Opaque], Unit),
      host_object_runtime_import("lane.test.host_object_read", [Opaque], Int),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  debug_inspect(
    (loaded.new_instance().execute(), finalized.val),
    content=(
      #|(
      #|  Err(
      #|    RuntimeImportFailure(
      #|      symbol="lane.test.host_object_read",
      #|      message="Host Object is closed",
      #|    ),
      #|  ),
      #|  1,
      #|)
    ),
  )
}
