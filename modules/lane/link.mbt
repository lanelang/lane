///|
async fn lane_link(
  objects : Array[String],
  output : String,
  verbose : Bool,
) -> LaneCommandOutcome {
  let object_artifacts = match read_module_object_artifacts(objects) {
    Ok(objects) => objects
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let linked = @compile.link_module_object_artifacts(object_artifacts)
  if !linked.diagnostics.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      linked.diagnostics,
      CompilerDiagnosticSources(),
      false,
    )
  }
  guard linked.program is Some(program) else {
    internal_error("linker produced no program")
  }
  write_linked_program_artifact(output, program) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Write, output, "\{error}"),
      )
  }
  if verbose {
    let linked_modules = program.module_path_texts.join(",")
    let linked_entries = entry_names(program.entries).join(",")
    println("linked program \{output}")
    println("linked modules \{linked_modules}")
    println("linked entries \{linked_entries}")
  }
  Succeeded
}

///|
fn entry_names(entries : Array[@elaborate.BuslaneEntry]) -> Array[String] {
  entries.map(fn(entry) { display_entry_name(entry.name) })
}

///|
fn display_entry_name(name : String) -> String {
  name.split("::").map(StringView::to_owned).collect().join(".")
}
