///|
test "byte sequence allocation size stays exact at maximum Bytes length" {
  assert_eq(byte_sequence_allocation_size(2147483635), 2147483648L)
}

///|
test "Bytes heap capacity is checked before payload materialization" {
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [],
    layouts: [Bytes],
    object_shapes: [],
    constants: [],
  }
  let heap = Heap::new(image, @runtime.ExecutionRuntime::new(), Some(15))
  let materialized = Ref(false)
  let result : Result[Int, Unit] = try
    heap.allocate_bytes(2147483635, () => {
      materialized.val = true
      []
    })
  catch {
    ResourceLimit(LiveHeapBytes) => Err(())
    _ => fail("unexpected allocation failure")
  } noraise {
    reference => Ok(reference)
  }
  assert_eq((result, materialized.val, heap.live_bytes), (Err(()), false, 0L))
}
