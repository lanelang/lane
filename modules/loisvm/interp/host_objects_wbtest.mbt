///|
test "interpreter rejects stale Host Object handles" {
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [],
    layouts: [Reference],
    object_shapes: [],
    constants: [],
  }
  let runtime = @runtime.ExecutionRuntime::new()
  let finalized = Ref(0)
  let adopted : Result[@runtime.HostObjectHandle, Unit] = runtime.adopt_host_object(
    @runtime.OwnedHostObject::new((), finalizer=_object => finalized.val += 1),
    handle => Ok(handle),
  )
  let handle = match adopted {
    Ok(handle) => handle
    Err(_) => fail("infallible Host Object adoption failed")
  }
  runtime.release_host_object(handle)
  let heap = Heap::new(image, runtime, None)
  let reference = heap.allocate_host_object(handle)
  let result : Result[@runtime.BorrowedHostObject, String] = Ok(
    heap.borrow_host_object(reference),
  ) catch {
    InternalFailure(detail~) => Err(detail)
    _ => fail("unexpected Host Object resolution failure")
  }
  debug_inspect(
    (result, finalized.val),
    content="(Err(\"handle generation is stale\"), 1)",
  )
}
