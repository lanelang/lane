///|
fn[T] successful_compilation(outcome : @compile.CompilationOutcome[T]) -> T {
  match outcome {
    Succeeded(value, _) => value
    Failed(failure) =>
      abort("expected successful compilation: \{Repr(failure.diagnostics())}")
  }
}

///|
fn compile_program_for_test(
  root : String,
  libraries : Array[String],
) -> @compile.CompilationOutcome[@compile.CompiledProgram] {
  @compile.compile({
    root: { source_id: "<root>", text: root },
    libraries: libraries.mapi(fn(index, text) {
      { source_id: "<library:\{index}>", text }
    }),
  })
}

///|
fn conformance_execution_profile() -> @executable.ExecutionProfile {
  @executable.ExecutionProfile::new(
    builtin_effects=[Io, Panic],
    supports_external_effects=true,
  )
}

///|
fn lower_conformance_program_to_bytecode(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@loisvm_bytecode.BytecodeImage, String] {
  let executable = match
    @executable.elaborate(
      { module_path_texts: [], program, externals, entries: [entry] },
      entry,
      conformance_execution_profile(),
    ) {
    Ok(executable) => executable
    Err(error) => return Err("elaboration failed: \{Repr(error)}")
  }
  match @loisvm_lowering.lower_executable_program_to_bytecode(executable) {
    Ok(image) => Ok(image)
    Err(error) => Err("lowering failed: \{Repr(error)}")
  }
}
