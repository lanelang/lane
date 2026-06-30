///|
enum LaneCommandOutcome {
  Succeeded
  UserFailure
}

///|
async fn main {
  let command = match parse_lane_command() {
    Ok(command) => command
    Err(message) => {
      println(message)
      fail("lane command failed")
    }
  }
  let outcome = match command {
    Check(file~, libs~, lib_dirs~, deny~) =>
      lane_check(file, libs, lib_dirs, deny)
    Compile(file~, interfaces~, emit_interface~, emit_object~) =>
      lane_compile(file, interfaces, emit_interface, emit_object)
    Fmt(files~, check~, deny~) => lane_fmt(files, check, deny)
    Link(objects~, output~) => lane_link(objects, output)
    Lsp(stdio~) => lsp_command(stdio)
    RunLinked(program~, entry~) => lane_runlinked(program, entry)
    Run(file~, entry~, libs~, lib_dirs~) =>
      lane_run(file, entry, libs, lib_dirs)
  }
  match outcome {
    Succeeded => ()
    UserFailure => fail("lane command failed")
  }
}

///|
async fn lsp_command(_stdio : Bool) -> LaneCommandOutcome {
  @async.pause()
  run_lsp_server(ServerState())
  Succeeded
}

///|
async fn run_lsp_server(state : ServerState) -> Unit {
  while read_protocol_message(@stdio.stdin) is Some(message) {
    let result = state.handle_message(message)
    for outgoing in result.outgoing {
      write_protocol_message(@stdio.stdout, outgoing)
    }
    if result.exit_requested {
      break
    }
  }
}

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

///|
async fn lane_check(
  file : String,
  libs : Array[String],
  lib_dirs : Array[String],
  deny : Bool,
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error => {
      println(read_file_error(file, "\{error}"))
      return UserFailure
    }
  }
  let libraries = match read_library_sources(libs, lib_dirs) {
    Ok(libraries) => libraries
    Err(message) => {
      println(message)
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
async fn lane_compile(
  file : String,
  interfaces : Array[String],
  emit_interface : String?,
  emit_object : String?,
) -> LaneCommandOutcome {
  guard emit_interface is Some(interface_path) else {
    println(missing_compile_output_error("--emit-interface", "-t"))
    return UserFailure
  }
  guard emit_object is Some(object_path) else {
    println(missing_compile_output_error("--emit-object", "-o"))
    return UserFailure
  }
  let source = read_source_file(file) catch {
    error => {
      println(read_file_error(file, "\{error}"))
      return UserFailure
    }
  }
  let imported_interfaces = match read_module_interface_artifacts(interfaces) {
    Ok(imported_interfaces) => imported_interfaces
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
  let result = @compile.compile_module_with_interface_artifacts(
    source, imported_interfaces,
  )
  if !result.diagnostics.is_empty() {
    print_diagnostics(result.diagnostics)
    return UserFailure
  }
  guard result.modules is Some(modules) else {
    internal_error("compiler produced no compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    internal_error("compiler produced no compiled module")
  }
  write_module_interface_artifact(interface_path, module_) catch {
    error => {
      println(write_file_error(interface_path, "\{error}"))
      return UserFailure
    }
  }
  write_module_object_artifact(object_path, module_) catch {
    error => {
      println(write_file_error(object_path, "\{error}"))
      return UserFailure
    }
  }
  println("compiled module \{module_.module_path_text}")
  println("wrote interface \{interface_path}")
  println("wrote object \{object_path}")
  Succeeded
}

///|
async fn lane_link(
  objects : Array[String],
  output : String,
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
  let linked_modules = program.module_path_texts.join(",")
  let linked_entries = entry_names(program.entries).join(",")
  println("linked program \{output}")
  println("linked modules \{linked_modules}")
  println("linked entries \{linked_entries}")
  Succeeded
}

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
  let libraries = match read_library_sources(libs, lib_dirs) {
    Ok(libraries) => libraries
    Err(message) => {
      println(message)
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
    0 => Err(entry_lookup_error(name, entries))
    _ => Err(ambiguous_entry_error(name, entries))
  }
}

///|
fn entry_names(entries : Array[@elaborate.BuslaneEntry]) -> Array[String] {
  entries.map(fn(entry) { entry.name })
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
