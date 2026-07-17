///|
priv struct WasmTestHostObject {
  id : Int
  mut closed : Bool
}

///|
fn wasm_host_owned_ref_slot() -> @bytecode.SlotMetadata {
  { representation: I32, cleanup: OwnedRef, erased_companion: None }
}

///|
fn wasm_host_body(
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
fn wasm_host_import(
  symbol : String,
  parameters : Array[@bytecode.RuntimeValueKind],
  result : @bytecode.RuntimeValueKind,
) -> @bytecode.FunctionEntry {
  RuntimeImport({ abi_major: 1, parameters, result, symbol })
}

///|
fn wasm_host_new_binding(
  store : @loisvm_runtime.HostObjectStore[WasmTestHostObject],
  next_id : Ref[Int],
  finalized : Ref[Int],
) -> @loisvm_runtime.RuntimeBinding {
  @loisvm_runtime.RuntimeBinding::typed(
    symbol="lane.test.wasm_host_new",
    abi_major=1,
    parameters=@loisvm_runtime.HostParameters::none(),
    result=@loisvm_runtime.HostResult::host_object(store, finalizer=_object => {
      finalized.val += 1
    }),
    invoke=fn(_context, _arguments) {
      next_id.val += 1
      { id: next_id.val, closed: false }
    },
  )
}

///|
fn load_wasm_host_instance(
  image : @bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
  config? : @loisvm_runtime.ExecutionConfig = @loisvm_runtime.ExecutionConfig::defaults(),
) -> ExecutionInstance raise {
  let loaded = match load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  match loaded.new_instance(config~) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{to_repr(error)}")
  }
}

///|
test "Wasm adapters preserve shared Host Object wrappers" {
  let store : @loisvm_runtime.HostObjectStore[WasmTestHostObject] = @loisvm_runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let observed : Array[Int] = []
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(wasm_host_new_binding(store, next_id, finalized))
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="lane.test.wasm_host_observe",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::one(
        @loisvm_runtime.HostParameter::host_object(store),
      ),
      result=@loisvm_runtime.HostResult::unit(),
      invoke=fn(_context, object : WasmTestHostObject) {
        observed.push(object.id)
      },
    ),
  )
  let owned_ref = wasm_host_owned_ref_slot()
  let entry = wasm_host_body(slots=[owned_ref, owned_ref], instructions=[
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    RetainCopy({ value: 1 }, { value: 0 }),
    CallDirect({ value: 3 }, None, [], [{ value: 0 }], None),
    CallDirect({ value: 3 }, None, [], [{ value: 1 }], None),
  ])
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(entry),
      wasm_host_import("lane.test.wasm_host_new", [], Opaque),
      wasm_host_import("lane.test.wasm_host_observe", [Opaque], Unit),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  let result = load_wasm_host_instance(image, registry).execute()
  debug_inspect(
    (result, observed, finalized.val),
    content="(Ok(()), [1, 1], 1)",
  )
}

///|
test "Wasm normal shutdown finalizes Host Object globals" {
  let store : @loisvm_runtime.HostObjectStore[WasmTestHostObject] = @loisvm_runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(wasm_host_new_binding(store, next_id, finalized))
  let initializer = wasm_host_body(slots=[wasm_host_owned_ref_slot()], instructions=[
    CallDirect({ value: 3 }, None, [], [], Some({ value: 0 })),
    InitGlobal({ value: 0 }, { value: 0 }),
  ])
  let image : @bytecode.BytecodeImage = {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    globals: [
      { representation: I32, cleanup: OwnedRef, erased_companion: None },
    ],
    functions: [
      BytecodeBody(initializer),
      BytecodeBody(wasm_host_body(slots=[], instructions=[])),
      wasm_host_import("lane.test.wasm_host_new", [], Opaque),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  debug_inspect(
    (load_wasm_host_instance(image, registry).execute(), finalized.val),
    content="(Ok(()), 1)",
  )
}

///|
test "Wasm rolls back rejected Host Object results" {
  let store : @loisvm_runtime.HostObjectStore[WasmTestHostObject] = @loisvm_runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(wasm_host_new_binding(store, next_id, finalized))
  let entry = wasm_host_body(slots=[wasm_host_owned_ref_slot()], instructions=[
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    Release({ value: 0 }),
  ])
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(entry),
      wasm_host_import("lane.test.wasm_host_new", [], Opaque),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  let object_limit = load_wasm_host_instance(image, registry, config={
    max_call_depth: None,
    max_live_heap_bytes: None,
    max_host_objects: Some(0),
  }).execute()
  let heap_limit = load_wasm_host_instance(image, registry, config={
    max_call_depth: None,
    max_live_heap_bytes: Some(0),
    max_host_objects: None,
  }).execute()
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
test "Wasm reports Host Object use after explicit close" {
  let store : @loisvm_runtime.HostObjectStore[WasmTestHostObject] = @loisvm_runtime.HostObjectStore::new()
  let next_id = Ref(0)
  let finalized = Ref(0)
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(wasm_host_new_binding(store, next_id, finalized))
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="lane.test.wasm_host_close",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::one(
        @loisvm_runtime.HostParameter::host_object(store),
      ),
      result=@loisvm_runtime.HostResult::unit(),
      invoke=fn(_context, object : WasmTestHostObject) { object.closed = true },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="lane.test.wasm_host_read",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::one(
        @loisvm_runtime.HostParameter::host_object(store),
      ),
      result=@loisvm_runtime.HostResult::int(),
      invoke=(_context, object : WasmTestHostObject) => {
        if object.closed {
          raise Failure(message="Host Object is closed")
        }
        object.id.to_int64()
      },
    ),
  )
  let owned_ref = wasm_host_owned_ref_slot()
  let entry = wasm_host_body(
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
      wasm_host_import("lane.test.wasm_host_new", [], Opaque),
      wasm_host_import("lane.test.wasm_host_close", [Opaque], Unit),
      wasm_host_import("lane.test.wasm_host_read", [Opaque], Int),
    ],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  debug_inspect(
    (load_wasm_host_instance(image, registry).execute(), finalized.val),
    content=(
      #|(
      #|  Err(
      #|    RuntimeImportFailure(
      #|      symbol="lane.test.wasm_host_read",
      #|      message="Host Object is closed",
      #|    ),
      #|  ),
      #|  1,
      #|)
    ),
  )
}
