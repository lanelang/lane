///|
/// Lowers a verified executable program to a complete LoisVM bytecode image.
/// Failure returns no partial image.
pub fn lower_executable_to_loisvm_bytecode(
  program : @executable.ExecutableProgram,
) -> Result[
  @loisvm_bytecode.BytecodeImage,
  @loisvm_lowering.LoisvmLoweringError,
] {
  @loisvm_lowering.lower_executable_program_to_bytecode(program)
}

///|
/// Lowers and wraps an executable for linked-program persistence. The artifact
/// codec selects the current schema when this value is encoded.
pub fn executable_to_loisvm_artifact(
  program : @executable.ExecutableProgram,
) -> Result[LinkedProgramArtifact, @loisvm_lowering.LoisvmLoweringError] {
  match lower_executable_to_loisvm_bytecode(program) {
    Ok(bytecode) => Ok({ bytecode, })
    Err(error) => Err(error)
  }
}

///|
/// Lowers and encodes an executable without exposing an intermediate artifact.
/// Lowering failure returns no partial binary payload.
pub fn executable_to_loisvm_binary(
  program : @executable.ExecutableProgram,
) -> Result[Bytes, LoisvmBinaryError] {
  match executable_to_loisvm_artifact(program) {
    Err(error) => Err(Lowering(error))
    Ok(artifact) =>
      match linked_program_artifact_to_binary(artifact) {
        Ok(bytes) => Ok(bytes)
        Err(error) => Err(BytecodeVerificationCompilerDefect(error))
      }
  }
}

///|
/// Encodes a caller-supplied LoisVM image in the current linked-program schema.
/// Invalid bytecode is rejected before artifact bytes are produced.
pub fn loisvm_linked_program_to_binary(
  image : @loisvm_bytecode.BytecodeImage,
) -> Result[Bytes, @loisvm_bytecode.BytecodeVerificationError] {
  linked_program_artifact_to_binary({ bytecode: image, })
}

///|
/// Decodes a linked-program payload and returns only a LoisVM-verifier-accepted
/// bytecode image. Malformed framing, an incompatible artifact schema, or
/// invalid bytecode returns `Err`; no additional verifier call is required.
pub fn parse_loisvm_linked_program_binary(
  bytes : Bytes,
) -> Result[@loisvm_bytecode.BytecodeImage, String] {
  match parse_linked_program_artifact_binary(bytes) {
    Ok(artifact) => Ok(artifact.bytecode)
    Err(message) => Err(message)
  }
}
