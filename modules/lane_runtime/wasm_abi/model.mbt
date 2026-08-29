///|
pub(all) enum InternalRuntimeFunction {
  F32ToString
  F64ToString
  FatalString
} derive(Debug, Eq)

///|
pub fn module_name() -> String {
  "lane.runtime.internal.v1"
}

///|
pub fn float_text_capacity() -> Int {
  32
}

///|
pub fn functions() -> Array[InternalRuntimeFunction] {
  [F32ToString, F64ToString, FatalString]
}

///|
pub fn InternalRuntimeFunction::name(self : InternalRuntimeFunction) -> String {
  match self {
    F32ToString => "f32_to_string"
    F64ToString => "f64_to_string"
    FatalString => "fatal_string"
  }
}

///|
pub fn InternalRuntimeFunction::type_(
  self : InternalRuntimeFunction,
) -> @wasm_types.FuncType {
  match self {
    F32ToString => { params: [F32, I32], results: [I32], }
    F64ToString => { params: [F64, I32], results: [I32], }
    FatalString => { params: [I32, I32], results: [], }
  }
}

///|
pub(all) enum RuntimeControlGlobal {
  MaxLiveHeapBytes
  MaxCallDepth
  FailureCode
} derive(Debug, Eq)

///|
pub fn RuntimeControlGlobal::name(self : RuntimeControlGlobal) -> String {
  match self {
    MaxLiveHeapBytes => "lane.runtime.control.max_live_heap_bytes"
    MaxCallDepth => "lane.runtime.control.max_call_depth"
    FailureCode => "lane.runtime.control.failure_code"
  }
}

///|
pub fn runtime_control_globals() -> Array[RuntimeControlGlobal] {
  [MaxLiveHeapBytes, MaxCallDepth, FailureCode]
}
