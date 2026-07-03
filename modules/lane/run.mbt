///|
async fn lane_runlinked(
  path : String,
  entry_name : String,
) -> LaneCommandOutcome {
  let program = read_linked_program_artifact(path) catch {
    error => {
      println(read_file_error(path, "\{error}"))
      return UserFailure
    }
  }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program.program,
    @intrinsics.standard_external_runtime(program.externals),
  ) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  let entry = match find_entry(program.entries, entry_name) {
    Ok(entry) => entry
    Err(message) => {
      println(message)
      return UserFailure
    }
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
    error => {
      println(read_file_error(file, "\{error}"))
      return UserFailure
    }
  }
  let root : LaneSourceInput = {
    source_id: file,
    path: Some(file),
    text: source,
  }
  let libraries = match read_library_source_inputs(file, libs, lib_dirs) {
    Ok(libraries) => libraries
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
  let diagnostic_sources = LaneSourceInput::diagnostic_sources(root, libraries)
  let result = @compile.compile_source_inputs(
    root.to_compile_input(),
    LaneSourceInput::array_to_compile_inputs(libraries),
  )
  if !result.diagnostics.is_empty() {
    print_diagnostics_with_sources(result.diagnostics, diagnostic_sources)
    return UserFailure
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
    Err(message) => {
      println(message)
      return UserFailure
    }
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
) -> Result[@elaborate.BuslaneEntry, String] {
  let matched = entries.filter(entry => entry.name == name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(entry_lookup_error(name, entries))
    _ => Err(ambiguous_entry_error(name, entries))
  }
}
