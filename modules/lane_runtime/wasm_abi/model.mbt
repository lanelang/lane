///|
pub(all) enum InternalRuntimeFunction {
  F32ToString
  F64ToString
  FatalString
  HostObjectRelease
} derive(Debug, Eq)

///|
pub fn module_name() -> String {
  "lane.runtime.internal.v1"
}

///|
pub fn functions() -> Array[InternalRuntimeFunction] {
  [F32ToString, F64ToString, FatalString, HostObjectRelease]
}

///|
pub fn InternalRuntimeFunction::name(self : InternalRuntimeFunction) -> String {
  match self {
    F32ToString => "f32_to_string"
    F64ToString => "f64_to_string"
    FatalString => "fatal_string"
    HostObjectRelease => "host_object.release"
  }
}

///|
pub fn InternalRuntimeFunction::type_(
  self : InternalRuntimeFunction,
) -> @wasm_types.FuncType {
  match self {
    F32ToString => { params: [F32], results: [I32], }
    F64ToString => { params: [F64], results: [I32], }
    FatalString => { params: [I32, I32], results: [], }
    HostObjectRelease => { params: [I64], results: [], }
  }
}

///|
pub(all) enum RuntimeControlGlobal {
  MaxLiveHeapBytes
  MaxCallDepth
  FailureCode
  RuntimeImportFailed
} derive(Debug, Eq)

///|
pub fn RuntimeControlGlobal::name(self : RuntimeControlGlobal) -> String {
  match self {
    MaxLiveHeapBytes => "lane.runtime.control.max_live_heap_bytes"
    MaxCallDepth => "lane.runtime.control.max_call_depth"
    FailureCode => "lane.runtime.control.failure_code"
    RuntimeImportFailed => "lane.runtime.control.runtime_import_failed"
  }
}

///|
pub fn runtime_control_globals() -> Array[RuntimeControlGlobal] {
  [MaxLiveHeapBytes, MaxCallDepth, FailureCode, RuntimeImportFailed]
}

///|
pub fn runtime_import_parameters(
  import_ : @lane_runtime.RuntimeImport,
) -> Array[@wasm_types.ValueType] {
  let parameters : Array[@wasm_types.ValueType] = []
  for kind in import_.parameters {
    match kind {
      Unit => ()
      Bool => parameters.push(I32)
      I64 => parameters.push(I64)
      F64 => parameters.push(F64)
      F32 => parameters.push(F32)
      Opaque => parameters.push(I64)
      String => {
        parameters.push(I32)
        parameters.push(I32)
      }
    }
  }
  parameters
}

///|
pub fn runtime_import_results(
  import_ : @lane_runtime.RuntimeImport,
) -> Array[@wasm_types.ValueType] {
  match import_.result {
    Unit => []
    Bool | String | Opaque => [I32]
    I64 => [I64]
    F64 => [F64]
    F32 => [F32]
  }
}
