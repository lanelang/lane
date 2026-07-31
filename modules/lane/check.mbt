///|
async fn lane_check(
  file : String,
  libs : Array[String],
  lib_dirs : Array[String],
  deny : Bool,
  no_basic? : Bool = false,
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Check, file, "\{error}"),
      )
  }
  let root : LaneSourceInput = {
    source_id: file,
    path: Some(file),
    text: source,
  }
  let libraries = match
    read_source_command_library_inputs(file, libs, lib_dirs, no_basic~) {
    Ok(libraries) => libraries
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let diagnostic_sources = LaneSourceInput::diagnostic_sources(root, libraries)
  let result = @compile.check({
    root: root.to_compile_input(),
    libraries: LaneSourceInput::array_to_compile_inputs(libraries),
  })
  let diagnostics = result.diagnostics()
  let failures = denied_diagnostics(diagnostics, deny)
  if !failures.is_empty() {
    LaneCommandOutcome::compile_diagnostics(
      diagnostics, diagnostic_sources, false,
    )
  } else if !diagnostics.is_empty() {
    LaneCommandOutcome::compile_diagnostics(
      diagnostics, diagnostic_sources, true,
    )
  } else {
    Succeeded
  }
}
