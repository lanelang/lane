///|
async fn lane_check(
  file : String,
  libs : Array[String],
  lib_dirs : Array[String],
  deny : Bool,
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error => {
      println(read_file_error(file, "\{error}"))
      return UserFailure
    }
  }
  let libraries = match read_library_sources(file, libs, lib_dirs) {
    Ok(libraries) => libraries
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
  let result = @compile.check_sources(source, libraries)
  let failures = denied_diagnostics(result.diagnostics, deny)
  if !failures.is_empty() {
    print_diagnostics(result.diagnostics)
    UserFailure
  } else if !result.diagnostics.is_empty() {
    print_diagnostics(result.diagnostics)
    Succeeded
  } else {
    Succeeded
  }
}
