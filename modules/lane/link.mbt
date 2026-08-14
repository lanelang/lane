///|
async fn lane_link(
  objects : Array[String],
  entry_name : PublicEntryName,
  output : String,
  verbose : Bool,
) -> LaneCommandOutcome {
  let object_artifacts = match read_module_object_artifacts(objects) {
    Ok(objects) => objects
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let linked = @compile.link_module_objects(object_artifacts)
  let diagnostics = linked.diagnostics()
  if !diagnostics.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      diagnostics,
      CompilerDiagnosticSources(),
      false,
    )
  }
  let program = match linked {
    Succeeded(program, _) => program
    Failed(_) => return internal_error("failed link had no errors")
  }
  let entry = match find_public_entry(program.entries(), entry_name) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let profile = @executable.ExecutionProfile::lane_cli()
  match validate_executable_entry(entry, program, profile) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let executable = match program.elaborate_entry(entry, profile) {
    Ok(executable) => executable
    Err(error) =>
      return LaneCommandOutcome::user_error(
        ExecutionImageLowering(message="\{Repr(error)}"),
      )
  }
  match write_linked_program_artifact(output, executable) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  if verbose {
    let linked_modules = program.module_path_texts().join(",")
    println("linked program \{output}")
    println("linked modules \{linked_modules}")
    println("linked entry \{display_public_entry_name(entry_name)}")
  }
  Succeeded
}

///|
fn display_entry(entry : @compile.CompiledEntry) -> String {
  "\{entry.module_path_text()}.\{entry.name()}"
}

///|
fn display_public_entry_name(entry : PublicEntryName) -> String {
  "\{entry.module_path_text}.\{entry.value_name}"
}
