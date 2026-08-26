///|
fn load_physical_interpreted(
  image : @physical.PhysicalProgram,
  registry : @lane_runtime.RuntimeRegistry,
) -> Result[@lane_wasm_runtime.LoadedImage, String] {
  let module_ = match @wasm_target.compile(image) {
    Ok(module_) => module_
    Err(error) => return Err("Wasm compilation failed: \{Repr(error)}")
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
      mode=Interpreter,
    ) {
    Ok(loaded) => Ok(loaded)
    Err(error) => Err("Wasm loading failed: \{Repr(error)}")
  }
}
