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
    F32ToString => { params: [F32], results: [I32] }
    F64ToString => { params: [F64], results: [I32] }
    FatalString => { params: [I32, I32], results: [] }
    HostObjectRelease => { params: [I64], results: [] }
  }
}
