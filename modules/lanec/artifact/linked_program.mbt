///|
/// Lowers an executable through the compiler-private physical program and
/// emits the unique persisted execution target: WebAssembly.
pub fn executable_to_wasm_artifact(
  program : @executable.ExecutableProgram,
) -> Result[LinkedProgramArtifact, WasmExecutableError] {
  let physical = match
    @physical_lowering.lower_executable_program_to_physical(program) {
    Ok(physical) => physical
    Err(error) => return Err(Lowering(error))
  }
  let module_ = match @wasm_compiler.compile(physical) {
    Ok(module_) => module_
    Err(error) => return Err(WasmCompilation(error))
  }
  let runtime_imports = physical.functions.filter_map(fn(entry) {
    match entry {
      RuntimeImport(import_) => Some(import_)
      PhysicalBody(_) => None
    }
  })
  Ok({
    wasm: Bytes::from_iter(
      @wasm_encoder.encode(module_).iter().map(Int::to_byte),
    ),
    runtime_imports,
  })
}

///|
/// Lowers and encodes an executable without exposing compiler-private physical
/// state. Failure returns no partial artifact.
pub fn executable_to_wasm_binary(
  program : @executable.ExecutableProgram,
) -> Result[Bytes, WasmExecutableError] {
  match executable_to_wasm_artifact(program) {
    Ok(artifact) => Ok(linked_program_artifact_to_binary(artifact))
    Err(error) => Err(error)
  }
}
