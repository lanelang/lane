///|
priv struct TestHostObject {
  mut value : Int
} derive(Debug)

///|
priv suberror AdoptionTestError {
  WrapperInitializationFailed
} derive(Debug)

///|
fn adopt_for_test(
  runtime : ExecutionRuntime,
  object : OwnedHostObject,
) -> HostObjectHandle raise HostObjectFailure {
  let result : Result[HostObjectHandle, Unit] = runtime.adopt_host_object(
    object,
    handle => Ok(handle),
  )
  match result {
    Ok(handle) => handle
    Err(_) => abort("infallible Host Object adoption failed")
  }
}

///|
fn resolve_for_test(
  runtime : ExecutionRuntime,
  handle : HostObjectHandle,
) -> Result[BorrowedHostObject, HostObjectFailure] {
  Ok(runtime.resolve_host_object(handle)) catch {
    error => Err(error)
  }
}

///|
test "Host Object lifecycle resolves aliases and finalizes exactly once" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let finalized = Ref(0)
  let payload = { value: 41 }
  let handle = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, payload, finalizer=_ => finalized.val += 1),
  )
  let first = store.project(runtime.resolve_host_object(handle))
  let second = store.project(runtime.resolve_host_object(handle))
  first.value += 1
  debug_inspect(
    (handle, first, second, runtime.live_host_objects(), finalized.val),
    content="({ slot: 0, generation: 1 }, { value: 42 }, { value: 42 }, 1, 0)",
  )
  runtime.release_host_object(handle)
  debug_inspect((runtime.live_host_objects(), finalized.val), content="(0, 1)")
}

///|
test "Host Object slots reuse indices with new generations" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let first = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => ()),
  )
  runtime.release_host_object(first)
  let second = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 2 }, finalizer=_ => ()),
  )
  debug_inspect(
    (first, second),
    content="({ slot: 0, generation: 1 }, { slot: 0, generation: 2 })",
  )
}

///|
test "failed Host Object adoption rolls back and finalizes pending ownership" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let finalized = Ref(0)
  let result : Result[Unit, AdoptionTestError] = runtime.adopt_host_object(
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => finalized.val += 1),
    _handle => Err(WrapperInitializationFailed),
  ) catch {
    _ => fail("unexpected Host Object adoption failure")
  }
  debug_inspect(
    (result, runtime.live_host_objects(), finalized.val),
    content="(Err(WrapperInitializationFailed), 0, 1)",
  )
}

///|
test "typed Host SDK projects Opaque through its Host Object Store" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let handle = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 40 }, finalizer=_ => ()),
  )
  let parameters = HostParameters::pair(
    HostParameters::one(HostParameter::host_object(store)),
    HostParameters::one(HostParameter::int()),
  )
  let binding = RuntimeBinding::typed(
    symbol="lane.test.host_object_add",
    abi_major=1,
    parameters~,
    result=HostResult::int(),
    invoke=fn(_context, arguments) {
      let object : TestHostObject = arguments.0
      object.value.to_int64() + arguments.1
    },
  )
  let borrowed = runtime.resolve_host_object(handle)
  let result = binding.call(runtime.context(), [
    BorrowedOpaque(borrowed),
    Int(2L),
  ])
  debug_inspect(
    (binding.parameters(), binding.result(), result),
    content="([Opaque, Int], Int, Int(42))",
  )
  runtime.release_host_object(handle)
}

///|
test "panic Host Object projection through another typed store is fatal" {
  let runtime = ExecutionRuntime::new()
  let first : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let second : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let handle = adopt_for_test(
    runtime,
    OwnedHostObject::new(first, { value: 40 }, finalizer=_ => ()),
  )
  ignore(second.project(runtime.resolve_host_object(handle)))
}

///|
test "typed Host SDK wraps owned Opaque results" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let finalized = Ref(0)
  let binding = RuntimeBinding::typed(
    symbol="lane.test.host_object_new",
    abi_major=1,
    parameters=HostParameters::none(),
    result=HostResult::host_object(store, finalizer=_object => {
      finalized.val += 1
    }),
    invoke=fn(_context, _arguments) { { value: 42 } },
  )
  let owned = match binding.call(runtime.context(), []) {
    OwnedOpaque(object) => object
    _ => fail("typed Host Object result used the wrong erased value kind")
  }
  let handle = adopt_for_test(runtime, owned)
  let object = store.project(runtime.resolve_host_object(handle))
  debug_inspect(
    (binding.parameters(), binding.result(), object, finalized.val),
    content="([], Opaque, { value: 42 }, 0)",
  )
  runtime.release_host_object(handle)
  assert_eq(finalized.val, 1)
}

///|
test "unlimited Host Object table accepts multiple live objects" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let first = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => ()),
  )
  let second = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 2 }, finalizer=_ => ()),
  )
  assert_eq(runtime.live_host_objects(), 2)
  runtime.release_host_object(first)
  runtime.release_host_object(second)
}

///|
test "bounded Host Object capacity is restored by final release" {
  let runtime = ExecutionRuntime::new(config={
    max_call_depth: None,
    max_live_heap_bytes: None,
    max_host_objects: Some(1),
  })
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let first = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => ()),
  )
  runtime.release_host_object(first)
  let second = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 2 }, finalizer=_ => ()),
  )
  debug_inspect(second, content="{ slot: 0, generation: 2 }")
  runtime.release_host_object(second)
}

///|
test "zero Host Object budget finalizes the rejected result" {
  let runtime = ExecutionRuntime::new(config={
    max_call_depth: None,
    max_live_heap_bytes: None,
    max_host_objects: Some(0),
  })
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let finalized = Ref(0)
  let result : Result[Unit, HostObjectFailure] = try {
    ignore(
      adopt_for_test(
        runtime,
        OwnedHostObject::new(store, { value: 1 }, finalizer=_ => {
          finalized.val += 1
        }),
      ),
    )
    Ok(())
  } catch {
    HostObjectLimitExceeded => Err(HostObjectLimitExceeded)
    _ => fail("unexpected Host Object allocation failure")
  }
  debug_inspect(
    (result, runtime.live_host_objects(), finalized.val),
    content="(Err(HostObjectLimitExceeded), 0, 1)",
  )
}

///|
test "negative Host Object budget behaves as zero budget" {
  let runtime = ExecutionRuntime::new(config={
    max_call_depth: None,
    max_live_heap_bytes: None,
    max_host_objects: Some(-1),
  })
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let finalized = Ref(0)
  let result : Result[Unit, HostObjectFailure] = try {
    ignore(
      adopt_for_test(
        runtime,
        OwnedHostObject::new(store, { value: 1 }, finalizer=_ => {
          finalized.val += 1
        }),
      ),
    )
    Ok(())
  } catch {
    HostObjectLimitExceeded => Err(HostObjectLimitExceeded)
    _ => fail("unexpected Host Object allocation failure")
  }
  debug_inspect(
    (result, runtime.live_host_objects(), finalized.val),
    content="(Err(HostObjectLimitExceeded), 0, 1)",
  )
}

///|
test "stale Host Object handle is rejected" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let handle = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => ()),
  )
  runtime.release_host_object(handle)
  debug_inspect(
    resolve_for_test(runtime, handle),
    content=(
      #|Err(InvalidHostObjectHandle(detail="handle generation is stale"))
    ),
  )
}

///|
test "cross-execution Host Object handle is rejected" {
  let first_runtime = ExecutionRuntime::new()
  let second_runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let handle = adopt_for_test(
    first_runtime,
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => ()),
  )
  debug_inspect(
    resolve_for_test(second_runtime, handle),
    content=(
      #|Err(InvalidHostObjectHandle(detail="handle belongs to another execution"))
    ),
  )
}

///|
test "panic Host Object finalizer failure is fatal" {
  let runtime = ExecutionRuntime::new()
  let store : HostObjectStore[TestHostObject] = HostObjectStore::new()
  let handle = adopt_for_test(
    runtime,
    OwnedHostObject::new(store, { value: 1 }, finalizer=_ => {
      abort("finalizer failed")
    }),
  )
  runtime.release_host_object(handle)
}
