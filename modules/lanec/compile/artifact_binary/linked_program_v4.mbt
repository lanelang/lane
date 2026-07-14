///|
pub fn lower_executable_to_loisvm_bytecode(
  program : @executable.ExecutableProgram,
) -> Result[
  @loisvm_bytecode.BytecodeImage,
  @loisvm_lowering.LoisvmLoweringError,
] {
  @loisvm_lowering.lower_executable_program_to_bytecode(program)
}

///|
pub fn executable_to_loisvm_artifact(
  program : @executable.ExecutableProgram,
) -> Result[
  @module_compile.LinkedProgramArtifact,
  @loisvm_lowering.LoisvmLoweringError,
] {
  match lower_executable_to_loisvm_bytecode(program) {
    Ok(bytecode) =>
      Ok({
        schema_version: @module_compile.linked_program_artifact_schema_version,
        bytecode,
      })
    Err(error) => Err(error)
  }
}

///|
pub fn executable_to_loisvm_binary(
  program : @executable.ExecutableProgram,
) -> Result[Bytes, @loisvm_lowering.LoisvmLoweringError] {
  match executable_to_loisvm_artifact(program) {
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
