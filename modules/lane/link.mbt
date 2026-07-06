///|
async fn lane_link(
  objects : Array[String],
  entry_name : String,
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
  let entry = match find_entry(program.entries, entry_name) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let runtime_effects = command_runtime_effects(
    program.program,
    program.runtime_effect_operations,
  )
  match validate_executable_entry(entry, runtime_effects) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let executable = program.to_executable(entry)
  write_linked_program_artifact(output, executable) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Write, output, "\{error}"),
      )
  }
  if verbose {
    let linked_modules = program.module_path_texts.join(",")
    println("linked program \{output}")
    println("linked modules \{linked_modules}")
    println("linked entry \{display_entry_name(entry.name)}")
  }
  Succeeded
}

///|
fn display_entry_name(name : String) -> String {
  name.split("::").map(StringView::to_owned).collect().join(".")
}
