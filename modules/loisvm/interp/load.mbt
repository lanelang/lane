///|
pub(all) suberror LoadError {
  InvalidBytecode(@bytecode.BytecodeVerificationError)
  RuntimeImportResolution(@runtime.RuntimeImportResolutionError)
} derive(Debug, Eq)

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
  match @bytecode.verify_bytecode_image(image) {
    Ok(_) => ()
    Err(error) => return Err(InvalidBytecode(error))
  }
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
          Err(error) => return Err(RuntimeImportResolution(error))
        }
        bindings.push(Some(binding))
      }
    }
  }
  Ok({ image, bindings })
}
