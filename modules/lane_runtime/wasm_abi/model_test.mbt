///|
test "internal runtime ABI has one complete declaration table" {
  debug_inspect(
    functions().map(fn(function) {
      (module_name(), function.name(), function.type_())
    }),
    content=(
      #|[
      #|  (
      #|    "lane.runtime.internal.v1",
      #|    "f32_to_string",
      #|    { params: [F32, I32], results: [I32] },
      #|  ),
      #|  (
      #|    "lane.runtime.internal.v1",
      #|    "f64_to_string",
      #|    { params: [F64, I32], results: [I32] },
      #|  ),
      #|  (
      #|    "lane.runtime.internal.v1",
      #|    "fatal_string",
      #|    { params: [I32, I32], results: [] },
      #|  ),
      #|]
    ),
  )
}

///|
test "runtime controls and failure codes have one stable ABI table" {
  debug_inspect(
    (
      runtime_control_globals().map(fn(control) { control.name() }),
      [RuntimeFailureCode::LiveHeapBytes, AllocationOrArc].map(fn(failure) {
        (failure, failure.code())
      }),
      [1, 2, 3, 4].map(fn(code) { (code, RuntimeFailureCode::from_code(code)) }),
    ),
    content=(
      #|(
      #|  [
      #|    "lane.runtime.control.max_live_heap_bytes",
      #|    "lane.runtime.control.failure_code",
      #|  ],
      #|  [(LiveHeapBytes, 2), (AllocationOrArc, 3)],
      #|  [
      #|    (1, None),
      #|    (2, Some(LiveHeapBytes)),
      #|    (3, Some(AllocationOrArc)),
      #|    (4, None),
      #|  ],
      #|)
    ),
  )
}
