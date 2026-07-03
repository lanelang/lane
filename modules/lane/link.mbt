///|
async fn lane_link(
  objects : Array[String],
  output : String,
  verbose : Bool,
) -> LaneCommandOutcome {
  let object_artifacts = match read_module_object_artifacts(objects) {
    Ok(objects) => objects
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
  let linked = @compile.link_module_object_artifacts(object_artifacts)
  if !linked.diagnostics.is_empty() {
    print_diagnostics(linked.diagnostics)
    return UserFailure
  }
  guard linked.program is Some(program) else {
    internal_error("linker produced no program")
  }
  write_linked_program_artifact(output, program) catch {
    error => {
      println(write_file_error(output, "\{error}"))
      return UserFailure
    }
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
  entries.map(fn(entry) { entry.name })
}
