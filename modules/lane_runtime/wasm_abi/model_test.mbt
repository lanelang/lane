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

///|
test "runtime service ABI owns names signatures and host-result requirements" {
  debug_inspect(
    runtime_services().map(service => {
      (
        service,
        service.name(),
        service.type_(),
        [
          @lane_runtime.RuntimeValueKind::Unit,
          Bool,
          I64,
          F64,
          F32,
          String,
          Opaque,
        ].filter(result => service.required_by_import_result(result)),
        functions().filter(function => {
          service.required_by_internal_import(function)
        }),
      )
    }),
    content=(
      #|[
      #|  (
      #|    StringNew,
      #|    "lane.runtime.string.new",
      #|    { params: [I32], results: [I32] },
      #|    [String],
      #|    [F32ToString, F64ToString],
      #|  ),
      #|  (
      #|    HostObjectNew,
      #|    "lane.runtime.host_object.new",
      #|    { params: [I64], results: [I32] },
      #|    [Opaque],
      #|    [],
      #|  ),
      #|]
    ),
  )
}
