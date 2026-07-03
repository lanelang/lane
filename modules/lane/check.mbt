///|
async fn lane_check(
  file : String,
  libs : Array[String],
  lib_dirs : Array[String],
  deny : Bool,
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
  let libraries = match read_library_source_inputs(file, libs, lib_dirs) {
    Ok(libraries) => libraries
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let diagnostic_sources = LaneSourceInput::diagnostic_sources(root, libraries)
  let result = @compile.check_source_inputs(
    root.to_compile_input(),
    LaneSourceInput::array_to_compile_inputs(libraries),
  )
  let failures = denied_diagnostics(result.diagnostics, deny)
  if !failures.is_empty() {
    LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      false,
    )
  } else if !result.diagnostics.is_empty() {
    LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      true,
    )
  } else {
    Succeeded
  }
}
