///|
async fn lane_fmt(
  files : Array[String],
  check : Bool,
  deny : Bool,
) -> LaneCommandOutcome {
  let mut failed = false
  for file in files {
    let source = read_source_file(file) catch {
      error => {
        println(read_file_error(file, "\{error}"))
        failed = true
        continue
      }
    }
    match @format.format_source(source) {
      Ok(formatted) =>
        if formatted != source {
          if check || deny {
            println("\{file}: not formatted")
            failed = true
          } else {
            write_source_file(file, formatted) catch {
              error => {
                println(write_file_error(file, "\{error}"))
                failed = true
              }
            }
          }
        }
      Err(diagnostics) => {
        failed = true
        for diagnostic in diagnostics {
          let rendered = @prettyprinter.render(diagnostic, width=100)
          println("\{file}: \{rendered}")
        }
      }
    }
  }
  if failed {
    UserFailure
  } else {
    Succeeded
  }
}
