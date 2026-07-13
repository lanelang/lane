///|
pub(all) suberror LoadError {
  UnresolvedImport(symbol~ : String)
  AbiMismatch(symbol~ : String, expected_major~ : Int, actual_major~ : Int)
  ArityMismatch(symbol~ : String, expected~ : Int, actual~ : Int)
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
  Ok(load_or_raise(image, registry)) catch {
    error => Err(error)
  }
}

///|
fn load_or_raise(
  image : @bytecode.BytecodeImage,
  registry : @runtime.RuntimeRegistry,
) -> LoadedImage raise LoadError {
  let bindings : Array[@runtime.RuntimeBinding?] = []
  for entry in image.functions {
    match entry {
      BytecodeBody(_) => bindings.push(None)
      RuntimeImport(import_) => {
        let binding = match registry.find(import_.symbol) {
          Some(binding) => binding
          None => raise UnresolvedImport(symbol=import_.symbol)
        }
        if binding.abi_major() != import_.abi_major {
          raise AbiMismatch(
            symbol=import_.symbol,
            expected_major=import_.abi_major,
            actual_major=binding.abi_major(),
          )
        }
        if binding.parameters().length() != import_.user_arity {
          raise ArityMismatch(
            symbol=import_.symbol,
            expected=import_.user_arity,
            actual=binding.parameters().length(),
          )
        }
        bindings.push(Some(binding))
      }
    }
  }
  { image, bindings }
}
