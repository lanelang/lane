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
    Link(interfaces~, objects~, root~) => lane_link(interfaces, objects, root)
    Lsp(stdio~) => lsp_command(stdio)
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
async fn lane_check(
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
async fn lane_compile(
  file : String,
  interfaces : Array[String],
  emit_interface : String?,
  emit_object : String?,
) -> LaneCommandOutcome {
  guard emit_interface is Some(interface_path) else {
    println("compile requires --emit-interface")
    return UserFailure
  }
  guard emit_object is Some(object_path) else {
    println("compile requires --emit-object")
    return UserFailure
  }
  let source = read_source_file(file) catch {
    error => {
      println("failed to read source: \{error}")
      return UserFailure
    }
  }
  let imported_interfaces = read_module_interface_artifacts(interfaces) catch {
    error => {
      println("failed to read module interface artifact: \{error}")
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
      println("failed to write module interface artifact: \{error}")
      return UserFailure
    }
  }
  write_module_object_artifact(object_path, module_.object) catch {
    error => {
      println("failed to write module object artifact: \{error}")
      return UserFailure
    }
  }
  println("compiled module " + module_.module_path_text)
  println("wrote interface " + interface_path)
  println("wrote object " + object_path)
  Succeeded
}

///|
async fn lane_link(
  interfaces : Array[String],
  objects : Array[String],
  root : String?,
) -> LaneCommandOutcome {
  if interfaces.is_empty() || objects.is_empty() {
    println("link requires --interface and --object")
    return UserFailure
  }
  if objects.length() > 1 && root is None {
    println("link root required when linking multiple module object inputs")
    return UserFailure
  }
  let inputs = match read_link_artifact_inputs(interfaces, objects, root) {
    Ok(inputs) => inputs
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
  let linked = @compile.link_module_artifact_parts(
    inputs.manifest,
    inputs.interfaces,
    inputs.objects,
  )
  if !linked.diagnostics.is_empty() {
    print_diagnostics(linked.diagnostics)
    return UserFailure
  }
  guard linked.program is Some(program) else {
    internal_error("linker produced no program")
  }
  println("linked root " + program.root_module_path_text)
  println("linked entries " + entry_names(program.entries).join(","))
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
