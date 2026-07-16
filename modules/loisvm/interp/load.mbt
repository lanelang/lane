///|
pub type LoadError = @runtime.RuntimeImportResolutionError

///|
pub struct LoadedImage {
  image : @bytecode.BytecodeImage
  bindings : Array[@runtime.RuntimeBinding?]
}

///|
pub fn load(
  image : @bytecode.BytecodeImage,
  registry : @runtime.RuntimeRegistry,
) -> Result[LoadedImage, LoadError] {
  let bindings : Array[@runtime.RuntimeBinding?] = []
  for entry in image.functions {
    match entry {
      BytecodeBody(_) => bindings.push(None)
      RuntimeImport(import_) => {
        let binding = match
          registry.resolve(
            import_.symbol,
            expected_abi_major=import_.abi_major,
            expected_parameters=import_.parameters,
            expected_result=import_.result,
          ) {
          Ok(binding) => binding
          Err(error) => return Err(error)
        }
        bindings.push(Some(binding))
      }
    }
  }
  Ok({ image, bindings })
}
