///|
pub(all) suberror LoadError {
  InvalidBytecode(@bytecode.BytecodeVerificationError)
  RuntimeImportResolution(@runtime.RuntimeImportResolutionError)
} derive(Debug, Eq)

///|
pub struct LoadedImage {
  image : @bytecode.BytecodeImage
  global_lifecycle : @bytecode.GlobalLifecyclePlan
  bindings : Array[@runtime.RuntimeBinding?]
}

///|
pub fn load(
  image : @bytecode.BytecodeImage,
  registry : @runtime.RuntimeRegistry,
) -> Result[LoadedImage, LoadError] {
  let verified = match @bytecode.verify_bytecode_image_for_execution(image) {
    Ok(verified) => verified
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
  Ok({
    image: verified.image,
    global_lifecycle: verified.global_lifecycle,
    bindings,
  })
}
