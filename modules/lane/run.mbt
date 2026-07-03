///|
async fn lane_runobj(path : String, entry_name : String) -> LaneCommandOutcome {
  let program = match read_linked_program_artifact(path) {
    Ok(program) => program
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program.program,
    @intrinsics.standard_external_runtime(program.externals),
  ) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  let entry = match find_entry(program.entries, entry_name) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let value = runtime.lookup(entry.value) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  println(render_entry_value(value, entry.type_))
  Succeeded
}

///|
async fn lane_run(
  file : String,
  entry : String,
  libs : Array[String],
  lib_dirs : Array[String],
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Run, file, "\{error}"),
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
  let result = @compile.compile_source_inputs(
    root.to_compile_input(),
    LaneSourceInput::array_to_compile_inputs(libraries),
  )
  if !result.diagnostics.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      false,
    )
  }
  guard result.program is Some(program) else {
    internal_error("compiler produced no Buslane program")
  }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program,
    @intrinsics.standard_external_runtime(result.externals),
  ) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  let entry = match find_entry(result.entries, entry) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let value = runtime.lookup(entry.value) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  println(render_entry_value(value, entry.type_))
  Succeeded
}

///|
fn render_entry_value(
  value : @buslane_interpreter.BuslaneRuntimeValue,
  type_ : @buslane.Type,
) -> String {
  @prettyprinter.render(value.pretty_with_type(type_), width=100)
}

///|
fn find_entry(
  entries : Array[@elaborate.BuslaneEntry],
  name : String,
) -> Result[@elaborate.BuslaneEntry, CliError] {
  let matched = entries.filter(entry => entry.name == name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(EntryNotFound(name~, entries~))
    _ => Err(EntryAmbiguous(name~, entries~))
  }
}
