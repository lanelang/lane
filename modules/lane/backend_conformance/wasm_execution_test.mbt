///|
suberror BackendLoadError {
  WasmCompilation(@wasm_target.WasmCompileError)
  InvalidWasm(detail~ : String)
  RuntimeImportResolution(error~ : @lane_runtime.RuntimeImportResolutionError)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
fn load_physical(
  image : @physical.PhysicalProgram,
  registry : @lane_runtime.RuntimeRegistry,
  mode? : @lane_wasm_runtime.ExecutionMode = Jit,
) -> Result[@lane_wasm_runtime.LoadedImage, BackendLoadError] {
  let module_ = match @wasm_target.compile(image) {
    Ok(module_) => module_
    Err(error) => return Err(WasmCompilation(error))
  }
  let encoded = @wasm_encoder.encode(module_)
  let wasm = Bytes::from_iter(encoded.iter().map(value => value.to_byte()))
  match
    @lane_wasm_runtime.load_wasm(
      wasm,
      image.functions.filter_map(entry => {
        match entry {
          RuntimeImport(import_) => Some(import_)
          PhysicalBody(_) => None
        }
      }),
      registry,
      mode~,
    ) {
    Ok(loaded) => Ok(loaded)
    Err(InvalidWasm(detail~)) => Err(InvalidWasm(detail~))
    Err(RuntimeImportResolution(error~)) => Err(RuntimeImportResolution(error~))
    Err(BackendCompileFailure(detail~)) => Err(BackendCompileFailure(detail~))
  }
}

///|
fn load_physical_interpreted(
  image : @physical.PhysicalProgram,
  registry : @lane_runtime.RuntimeRegistry,
) -> Result[@lane_wasm_runtime.LoadedImage, BackendLoadError] {
  load_physical(image, registry, mode=Interpreter)
}
