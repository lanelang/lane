///|
/// Lowers, encodes, and certifies an executable as the unique persisted
/// execution target: a raw WebAssembly module.
pub fn executable_to_verified_wasm(
  program : @executable.ExecutableProgram,
) -> Result[VerifiedWasmExecutable, WasmExecutableError] {
  let physical = match
    @physical_lowering.lower_executable_program_to_physical(program) {
    Ok(physical) => physical
    Err(error) => return Err(Lowering(error))
  }
  let module_ = match @wasm_compiler.compile(physical) {
    Ok(module_) => module_
    Err(error) => return Err(WasmCompilation(error))
  }
  match certify_wasm_module(module_) {
    Ok(artifact) => Ok(artifact)
    Err(error) => Err(WasmCertification(error))
  }
}

///|
pub fn VerifiedWasmExecutable::bytes(self : VerifiedWasmExecutable) -> Bytes {
  self.bytes
}

///|
fn certify_wasm_module(
  module_ : @wasm_types.Module,
) -> Result[VerifiedWasmExecutable, WasmArtifactCertificationError] {
  let bytes = Bytes::from_iter(
    @wasm_encoder.encode(module_).iter().map(Int::to_byte),
  )
  let reparsed = @wasm_parser.parse_module(bytes) catch {
    error => return Err(EncodedBytesUnparseable(detail=error.to_string()))
  }
  @wasm_validator.validate_module(reparsed) catch {
    error =>
      return Err(
        EncodedModuleInvalid(
          detail=@wasm_validator.format_validation_error(error),
        ),
      )
  }
  Ok({ bytes, })
}
