///|
async fn lane_fmt(files : Array[String], check : Bool) -> LaneCommandOutcome {
  let errors : Array[CliError] = []
  let diagnostics : Array[@compiler_diag.CompilerDiagnostic] = []
  let sources = CompilerDiagnosticSources()
  for file in files {
    let source = read_source_file(file) catch {
      error => {
        errors.push(CliError::file_io(Format, file, "\{error}"))
        continue
      }
    }
    sources.add(file, source, Some(file))
    match @format.format_source(source) {
      Ok(formatted) =>
        if formatted != source {
          if check {
            errors.push(NotFormatted(path=file))
          } else {
            write_source_file(file, formatted) catch {
              error => errors.push(CliError::file_io(Write, file, "\{error}"))
            }
          }
        }
      Err(file_diagnostics) =>
        diagnostics.append(
          file_diagnostics.map(fn(diagnostic) {
            diagnostic.with_source_id(file)
          }),
        )
    }
  }
  if !diagnostics.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(diagnostics, sources, false)
  }
  if !errors.is_empty() {
    UserErrors(errors)
  } else {
    Succeeded
  }
}
