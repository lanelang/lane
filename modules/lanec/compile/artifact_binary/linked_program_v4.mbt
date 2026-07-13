///|
pub fn linked_executable_to_loisvm_binary(
  program : @module_compile.LinkedExecutableProgram,
) -> Result[Bytes, @loisvm_lowering.LoisvmLoweringError] {
  match program.to_artifact() {
    Ok(artifact) => Ok(linked_program_artifact_to_binary(artifact))
    Err(error) => Err(error)
  }
}

///|
pub fn loisvm_linked_program_to_binary(
  image : @loisvm_bytecode.BytecodeImage,
) -> Bytes {
  linked_program_artifact_to_binary({
    schema_version: @module_compile.linked_program_artifact_schema_version,
    bytecode: image,
  })
}

///|
pub fn parse_loisvm_linked_program_binary(
  bytes : Bytes,
) -> Result[@loisvm_bytecode.BytecodeImage, String] {
  match parse_linked_program_artifact_binary(bytes) {
    Ok(artifact) => Ok(artifact.bytecode)
    Err(message) => Err(message)
  }
}
