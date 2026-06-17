///|
async fn main {
  @async.pause()
  let command = parse_lane_command() catch {
    error => fail_with_message("\{error}")
  }
  match command {
    Check(file~, stdlib~) => lane_check(file, stdlib)
    Run(file~, entry~, stdlib~) => lane_run(file, entry, stdlib)
  }
}

///|
fn lane_check(file : String, stdlib : String?) -> Unit {
  let prelude = read_prelude(stdlib) catch {
    error => fail_with_message("failed to read prelude: \{error}")
  }
  let source = read_source_file(file) catch {
    error => fail_with_message("failed to read source: \{error}")
  }
  let result = @compile.check_with_prelude(prelude, source)
  if result.diagnostics.is_empty() {
    exit_success()
  } else {
    print_diagnostics(result.diagnostics)
    exit_failure()
  }
}

///|
fn lane_run(file : String, entry : String, stdlib : String?) -> Unit {
  let prelude = read_prelude(stdlib) catch {
    error => fail_with_message("failed to read prelude: \{error}")
  }
  let source = read_source_file(file) catch {
    error => fail_with_message("failed to read source: \{error}")
  }
  let result = @compile.compile_with_prelude(prelude, source)
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
