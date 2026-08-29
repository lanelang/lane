///|
struct TestHostFunction {
  module_name : String
  field_name : String
  type_ : @wasm_types.FuncType
  invoke : (Array[@wasm_types.Value]) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError
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
  invoke : (Array[@wasm_types.Value]) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError,
) -> Unit {
  self.functions.push({ module_name: "lane.test", field_name, type_, invoke, })
}

///|
fn TestHostBindings::observe_i64(
  self : TestHostBindings,
  field_name : String,
  observe : (Int64) -> Unit,
) -> Unit {
  self.add(field_name, { params: [I64], results: [], }, values => {
    guard values is [I64(value)] else { raise TypeMismatch }
    observe(value)
    []
  })
}

///|
fn TestHostBindings::observe_f32(
  self : TestHostBindings,
  field_name : String,
  observe : (Float) -> Unit,
) -> Unit {
  self.add(field_name, { params: [F32], results: [], }, values => {
    guard values is [F32(value)] else { raise TypeMismatch }
    observe(value)
    []
  })
}

///|
fn TestHostBindings::provide_i64(
  self : TestHostBindings,
  field_name : String,
  value : Int64,
) -> Unit {
  self.add(field_name, { params: [], results: [I64], }, _ => [I64(value)])
}

///|
fn TestHostBindings::signal(
  self : TestHostBindings,
  field_name : String,
  signal : () -> Unit,
) -> Unit {
  self.add(field_name, { params: [], results: [], }, _ => {
    signal()
    []
  })
}

///|
fn load_physical_interpreted(
  image : @physical.PhysicalProgram,
  host? : TestHostBindings = TestHostBindings::new(),
) -> Result[@lane_wasm_runtime.LoadedImage, String] {
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => return Err("Physical verification failed: \{Repr(error)}")
  }
  let module_ = match @wasm_target.compile(verified) {
    Ok(module_) => module_
    Err(error) => return Err("Wasm compilation failed: \{Repr(error)}")
  }
  let encoded = @wasm_encoder.encode(module_)
  let wasm = Bytes::from_iter(encoded.iter().map(value => value.to_byte()))
  match
    @lane_wasm_runtime.load_wasm(wasm, mode=Interpreter, configure_host=linker => {
      for function in host.functions {
        linker.add_host_func(
          function.module_name,
          function.field_name,
          function.invoke,
          func_type=function.type_,
        )
      }
    }) {
    Ok(loaded) => Ok(loaded)
    Err(error) => Err("Wasm loading failed: \{Repr(error)}")
  }
}
