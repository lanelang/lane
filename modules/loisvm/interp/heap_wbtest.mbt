///|
test "byte sequence allocation size uses checked Int64 arithmetic" {
  assert_eq(
    [
      checked_byte_sequence_allocation_size(-1L),
      checked_byte_sequence_allocation_size(0L),
      checked_byte_sequence_allocation_size(1L),
      checked_byte_sequence_allocation_size(4L),
      checked_byte_sequence_allocation_size(5L),
      checked_byte_sequence_allocation_size(12L),
      checked_byte_sequence_allocation_size(13L),
      checked_byte_sequence_allocation_size(2147483635L),
      checked_byte_sequence_allocation_size(2147483636L),
      checked_byte_sequence_allocation_size(9223372036854775807L),
    ],
    [
      None,
      Some(16L),
      Some(16L),
      Some(16L),
      Some(24L),
      Some(24L),
      Some(32L),
      Some(2147483648L),
      Some(2147483648L),
      None,
    ],
  )
}

///|
test "Bytes heap capacity is checked before payload materialization" {
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [],
    globals: [],
    functions: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [],
  }
  let heap = Heap::new(image, @runtime.ExecutionRuntime::new(), Some(15))
  let result : Result[Int, Unit] = try
    heap.allocate_filled_byte_sequence(2147483636L, b'\x00')
  catch {
    ResourceLimit(LiveHeapBytes) => Err(())
    _ => fail("unexpected allocation failure")
  } noraise {
    reference => Ok(reference)
  }
  assert_eq((result, heap.live_bytes), (Err(()), 0L))
}

///|
test "Bytes heap capacity is checked before shared payload copying" {
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [],
    globals: [],
    functions: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [],
  }
  let heap = Heap::new(image, @runtime.ExecutionRuntime::new(), Some(16))
  let reference = heap.allocate_filled_byte_sequence(1L, b'\x01')
  let source = heap.byte_sequence(reference)
  let result : Result[Int, Unit] = try
    heap.allocate_updated_byte_sequence(source, 0, b'\x02')
  catch {
    ResourceLimit(LiveHeapBytes) => Err(())
    _ => fail("unexpected allocation failure")
  } noraise {
    result => Ok(result)
  }
  assert_eq((result, source, heap.live_bytes), (Err(()), [b'\x01'], 16L))
}
