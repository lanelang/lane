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
      #|    { params: [F32], results: [I32] },
      #|  ),
      #|  (
      #|    "lane.runtime.internal.v1",
      #|    "f64_to_string",
      #|    { params: [F64], results: [I32] },
      #|  ),
      #|  (
      #|    "lane.runtime.internal.v1",
      #|    "fatal_string",
      #|    { params: [I32, I32], results: [] },
      #|  ),
      #|  (
      #|    "lane.runtime.internal.v1",
      #|    "host_object.release",
      #|    { params: [I64], results: [] },
      #|  ),
      #|]
    ),
  )
}
