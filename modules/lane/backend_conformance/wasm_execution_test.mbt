///|
suberror BackendLoadError {
  InvalidPhysicalProgram(@physical.PhysicalProgramVerificationError)
  WasmCompilation(@wasm_target.WasmCompileError)
  InvalidWasm(detail~ : String)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
struct TestHostFunction {
  module_name : String
  field_name : String
  type_ : @wasm_types.FuncType
  invoke : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError
}

///|
struct TestHostBindings {
  functions : Array[TestHostFunction]
}

///|
fn TestHostBindings::new() -> TestHostBindings {
  { functions: [], }
}

///|
fn TestHostBindings::add(
  self : TestHostBindings,
  field_name : String,
  type_ : @wasm_types.FuncType,
  invoke : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError,
) -> Unit {
  self.functions.push({ module_name: "lane.test", field_name, type_, invoke, })
}

///|
fn TestHostBindings::observe_i64(
  self : TestHostBindings,
  field_name : String,
  observe : (Int64) -> Unit,
) -> Unit {
  self.add(field_name, { params: [I64], results: [], }, (_caller, values) => {
    guard values is [I64(value)] else { raise TypeMismatch }
    observe(value)
    []
  })
}

///|
fn TestHostBindings::observe_f64(
  self : TestHostBindings,
  field_name : String,
  observe : (Double) -> Unit,
) -> Unit {
  self.add(field_name, { params: [F64], results: [], }, (_caller, values) => {
    guard values is [F64(value)] else { raise TypeMismatch }
    observe(value)
    []
  })
}

///|
fn TestHostBindings::signal(
  self : TestHostBindings,
  field_name : String,
  signal : () -> Unit,
) -> Unit {
  self.add(field_name, { params: [], results: [], }, (_caller, values) => {
    guard values.is_empty() else { raise TypeMismatch }
    signal()
    []
  })
}

///|
fn TestHostBindings::byte_sequence_length(
  self : TestHostBindings,
  field_name : String,
) -> Unit {
  self.add(field_name, { params: [I32, I32], results: [I64], }, (
    _caller,
    values,
  ) => {
    guard values is [I32(_), I32(length)] else { raise TypeMismatch }
    [I64(length.to_int64())]
  })
}

///|
fn load_physical(
  image : @physical.PhysicalProgram,
  mode? : @lane_wasm_runtime.ExecutionMode = Jit,
  wasi_stdout? : ((Bytes) -> Unit)? = None,
  host? : TestHostBindings = TestHostBindings::new(),
) -> Result[@lane_wasm_runtime.LoadedImage, BackendLoadError] {
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => return Err(InvalidPhysicalProgram(error))
  }
  let module_ = match @wasm_target.compile(verified) {
    Ok(module_) => module_
    Err(error) => return Err(WasmCompilation(error))
  }
  let encoded = @wasm_encoder.encode(module_)
  let wasm = Bytes::from_iter(encoded.iter().map(value => value.to_byte()))
  match
    @lane_wasm_runtime.load_wasm(wasm, mode~, wasi_stdout~, configure_host=linker => {
      for function in host.functions {
        linker.add_host_func_with_caller(
          function.module_name,
          function.field_name,
          function.invoke,
          func_type=function.type_,
        )
      }
    }) {
    Ok(loaded) => Ok(loaded)
    Err(InvalidWasm(detail~)) => Err(InvalidWasm(detail~))
    Err(BackendCompileFailure(detail~)) => Err(BackendCompileFailure(detail~))
  }
}

///|
fn load_physical_interpreted(
  image : @physical.PhysicalProgram,
  host? : TestHostBindings = TestHostBindings::new(),
) -> Result[@lane_wasm_runtime.LoadedImage, BackendLoadError] {
  load_physical(image, mode=Interpreter, host~)
}
