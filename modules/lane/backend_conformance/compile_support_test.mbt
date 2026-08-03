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
