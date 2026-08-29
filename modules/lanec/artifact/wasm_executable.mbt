///|
/// Lowers and encodes an executable as the unique persisted execution target:
/// a raw WebAssembly module.
pub fn executable_to_wasm_binary(
  program : @executable.ExecutableProgram,
) -> Result[Bytes, WasmExecutableError] {
  let physical = match
    @physical_lowering.lower_executable_program_to_physical(program) {
    Ok(physical) => physical
    Err(error) => return Err(Lowering(error))
  }
  let module_ = match @wasm_compiler.compile(physical) {
    Ok(module_) => module_
    Err(error) => return Err(WasmCompilation(error))
  }
  Ok(Bytes::from_iter(@wasm_encoder.encode(module_).iter().map(Int::to_byte)))
}
