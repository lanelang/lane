///|
async fn lane_fmt(
  files : Array[String],
  check : Bool,
  deny : Bool,
) -> LaneCommandOutcome {
  let errors : Array[CliError] = []
  for file in files {
    let source = read_source_file(file) catch {
      error => {
        errors.push(CliError::file_io(Format, file, "\{error}"))
        continue
      }
    }
    match @format.format_source(source) {
      Ok(formatted) =>
        if formatted != source {
          if check || deny {
            errors.push(NotFormatted(path=file))
          } else {
            write_source_file(file, formatted) catch {
              error => errors.push(CliError::file_io(Write, file, "\{error}"))
            }
          }
        }
      Err(diagnostics) =>
        errors.push(FormatDiagnostics(path=file, diagnostics~))
    }
  }
  if !errors.is_empty() {
    UserErrors(errors)
  } else {
    Succeeded
  }
}
