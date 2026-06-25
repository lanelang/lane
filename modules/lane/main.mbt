///|
enum LaneCommandOutcome {
  Succeeded
  UserFailure
}

///|
fn main {
  let command = match parse_lane_command() {
    Ok(command) => command
    Err(message) => {
      println(message)
      println("lane command failed")
      return
    }
  }
  let outcome = match command {
    Check(file~, libs~, lib_dirs~, deny~) =>
      lane_check(file, libs, lib_dirs, deny)
    Fmt(files~, check~, deny~) => lane_fmt(files, check, deny)
    Run(file~, entry~, libs~, lib_dirs~) =>
      lane_run(file, entry, libs, lib_dirs)
  }
  match outcome {
    Succeeded => ()
    UserFailure => println("lane command failed")
  }
}

///|
fn lane_fmt(
  files : Array[String],
  check : Bool,
  deny : Bool,
) -> LaneCommandOutcome {
  let mut failed = false
  for file in files {
    let source = read_source_file(file) catch {
      error => {
        println("failed to read source: \{error}")
        failed = true
        continue
      }
    }
    match @format.format_source(source) {
      Ok(formatted) =>
        if formatted != source {
          if check || deny {
            println(file + ": not formatted")
            failed = true
          } else {
            write_source_file(file, formatted) catch {
              error => {
                println("failed to write source: \{error}")
                failed = true
              }
            }
          }
        }
      Err(diagnostics) => {
        failed = true
        for diagnostic in diagnostics {
          println(file + ": " + @prettyprinter.render(diagnostic, width=100))
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

///|
fn lane_check(
  file : String,
  libs : Array[String],
  lib_dirs : Array[String],
  deny : Bool,
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error => {
      println("failed to read source: \{error}")
      return UserFailure
    }
  }
  let libraries = read_library_sources(libs, lib_dirs) catch {
    error => {
      println("failed to read library source: \{error}")
      return UserFailure
    }
  }
  let result = @compile.check_sources(source, libraries)
  let failures = denied_diagnostics(result.diagnostics, deny)
  if !failures.is_empty() {
    print_diagnostics(result.diagnostics)
    UserFailure
  } else if !result.diagnostics.is_empty() {
    print_diagnostics(result.diagnostics)
    Succeeded
  } else {
    Succeeded
  }
}

///|
fn lane_run(
  file : String,
  entry : String,
  libs : Array[String],
  lib_dirs : Array[String],
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error => {
      println("failed to read source: \{error}")
      return UserFailure
    }
  }
  let libraries = read_library_sources(libs, lib_dirs) catch {
    error => {
      println("failed to read library source: \{error}")
      return UserFailure
    }
  }
  let result = @compile.compile_sources(source, libraries)
  if !result.diagnostics.is_empty() {
    print_diagnostics(result.diagnostics)
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
    0 => Err("entry not found: " + name)
    _ => Err("ambiguous entry: " + name)
  }
}

///|
fn print_diagnostics(diagnostics : Array[@compile.CompileDiagnostic]) -> Unit {
  for diagnostic in diagnostics {
    println(@prettyprinter.render(diagnostic, width=100))
  }
}

///|
fn denied_diagnostics(
  diagnostics : Array[@compile.CompileDiagnostic],
  deny : Bool,
) -> Array[@compile.CompileDiagnostic] {
  diagnostics.filter(fn(diagnostic) { deny || diagnostic.severity is Error })
}
