///|
pub fn LinkedExecutableProgram::lower_to_loisvm_bytecode(
  self : LinkedExecutableProgram,
) -> Result[
  @loisvm_bytecode.BytecodeImage,
  @loisvm_lowering.LoisvmLoweringError,
] {
  @loisvm_lowering.lower_linked_program_to_bytecode_with_runtime_effects(
    self.program,
    self.externals,
    self.entry,
    self.runtime_effect_operations,
  )
}

///|
pub fn LinkedExecutableProgram::to_artifact(
  self : LinkedExecutableProgram,
) -> Result[LinkedProgramArtifact, @loisvm_lowering.LoisvmLoweringError] {
  match self.lower_to_loisvm_bytecode() {
    Ok(bytecode) =>
      Ok({ schema_version: linked_program_artifact_schema_version, bytecode })
    Err(error) => Err(error)
  }
}
