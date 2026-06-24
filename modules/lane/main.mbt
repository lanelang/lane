///|
async fn main {
  @async.pause()
  let command = parse_lane_command() catch {
    error => fail_with_message("\{error}")
  }
  match command {
    Check(file~, libs~, lib_dirs~) => lane_check(file, libs, lib_dirs)
    Run(file~, entry~, libs~, lib_dirs~) =>
      lane_run(file, entry, libs, lib_dirs)
  }
}

///|
fn lane_check(
  file : String,
  libs : Array[String],
  lib_dirs : Array[String],
) -> Unit {
  let source = read_source_file(file) catch {
    error => fail_with_message("failed to read source: \{error}")
  }
  let libraries = read_library_sources(libs, lib_dirs) catch {
    error => fail_with_message("failed to read library source: \{error}")
  }
  let result = @compile.check_sources(source, libraries)
  if result.diagnostics.is_empty() {
    exit_success()
  } else {
    print_diagnostics(result.diagnostics)
    exit_failure()
  }
}

///|
fn lane_run(
  file : String,
  entry : String,
  libs : Array[String],
  lib_dirs : Array[String],
) -> Unit {
  let source = read_source_file(file) catch {
    error => fail_with_message("failed to read source: \{error}")
  }
  let libraries = read_library_sources(libs, lib_dirs) catch {
    error => fail_with_message("failed to read library source: \{error}")
  }
  let result = @compile.compile_sources(source, libraries)
  if !result.diagnostics.is_empty() {
    print_diagnostics(result.diagnostics)
    exit_failure()
  }
  guard result.program is Some(program) else {
    fail_with_message("compiler produced no Buslane program")
  }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program,
    @intrinsics.standard_external_runtime(result.externals),
  ) catch {
    error => fail_with_message(@prettyprinter.render(error, width=100))
  }
  let entry = find_entry(result.entries, entry)
  let value = runtime.lookup(entry.value) catch {
    error => fail_with_message(@prettyprinter.render(error, width=100))
  }
  println(render_entry_value(value, entry.type_))
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
) -> @elaborate.BuslaneEntry {
  let matched = entries.filter(entry => entry.name == name)
  match matched.length() {
    1 => matched[0]
    0 => fail_with_message("entry not found: " + name)
    _ => fail_with_message("ambiguous entry: " + name)
  }
}

///|
fn print_diagnostics(diagnostics : Array[@compile.CompileDiagnostic]) -> Unit {
  for diagnostic in diagnostics {
    println(@prettyprinter.render(diagnostic, width=100))
  }
}
