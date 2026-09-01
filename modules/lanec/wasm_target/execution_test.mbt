///|
suberror TargetLoadError {
  InvalidPhysicalProgram(@physical.PhysicalProgramVerificationError)
  WasmCompilation(@wasm_target.WasmCompileError)
  InvalidWasm(detail~ : String)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
fn runtime_service_exports(module_ : @wasm_types.Module) -> Array[String] {
  module_.exports.filter_map(export_ => {
    if export_.name == "lane.runtime.string.new" {
      Some(export_.name)
    } else {
      None
    }
  })
}

///|
fn encode_wasm_module(module_ : @wasm_types.Module) -> Bytes {
  let encoded = @wasm_encoder.encode(module_)
  Bytes::from_iter(encoded.iter().map(value => value.to_byte()))
}

///|
fn load(
  image : @physical.PhysicalProgram,
  mode? : @lane_wasm_runtime.ExecutionMode = Jit,
  configure_host? : @lane_wasm_runtime.HostLinkerConfiguration = _ => (),
) -> Result[@lane_wasm_runtime.LoadedImage, TargetLoadError] {
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => return Err(InvalidPhysicalProgram(error))
  }
  let module_ = match @wasm_target.compile(verified) {
    Ok(module_) => module_
    Err(error) => return Err(WasmCompilation(error))
  }
  match
    @lane_wasm_runtime.load_wasm(
      encode_wasm_module(module_),
      mode~,
      wasi_stderr=Some(_ => ()),
      configure_host~,
    ) {
    Ok(loaded) => Ok(loaded)
    Err(InvalidWasm(detail~)) => Err(InvalidWasm(detail~))
    Err(BackendCompileFailure(detail~)) => Err(BackendCompileFailure(detail~))
  }
}

///|
