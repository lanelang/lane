///|
suberror TargetLoadError {
  InvalidPhysicalProgram(@physical.PhysicalProgramVerificationError)
  WasmCompilation(@wasm_target.WasmCompileError)
  InvalidWasm(detail~ : String)
  RuntimeImportResolution(error~ : @lane_runtime.RuntimeImportResolutionError)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
fn runtime_import_manifest(
  image : @physical.PhysicalProgram,
) -> Array[@lane_runtime.RuntimeImport] {
  image.functions.filter_map(entry => {
    match entry {
      RuntimeImport(import_) => Some(import_)
      PhysicalBody(_) => None
    }
  })
}

///|
fn load(
  image : @physical.PhysicalProgram,
  registry : @lane_runtime.RuntimeRegistry,
  mode? : @lane_wasm_runtime.ExecutionMode = Jit,
) -> Result[@lane_wasm_runtime.LoadedImage, TargetLoadError] {
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
    @lane_wasm_runtime.load_wasm(
      wasm,
      runtime_import_manifest(image),
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
fn load_interpreted(
  image : @physical.PhysicalProgram,
  registry : @lane_runtime.RuntimeRegistry,
) -> Result[@lane_wasm_runtime.LoadedImage, TargetLoadError] {
  load(image, registry, mode=Interpreter)
}
