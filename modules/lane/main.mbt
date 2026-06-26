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
      println("lane command failed")
      return
    }
  }
  let outcome = match command {
    Check(file~, libs~, lib_dirs~, interfaces~, interface_dirs~, deny~) =>
      lane_check(file, libs, lib_dirs, interfaces, interface_dirs, deny)
    Compile(
      file~,
      libs~,
      lib_dirs~,
      interfaces~,
      interface_dirs~,
      out~,
      out_dir~
    ) =>
      lane_compile(
        file, libs, lib_dirs, interfaces, interface_dirs, out, out_dir,
      )
    Fmt(files~, check~, deny~) => lane_fmt(files, check, deny)
    Link(file~, artifacts~, artifact_dirs~, root~, libs~, lib_dirs~) =>
      lane_link(file, artifacts, artifact_dirs, root, libs, lib_dirs)
    Lsp(stdio~) => lsp_command(stdio)
    Run(file~, entry~, libs~, lib_dirs~) =>
      lane_run(file, entry, libs, lib_dirs)
  }
  match outcome {
    Succeeded => ()
    UserFailure => println("lane command failed")
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
  interfaces : Array[String],
  interface_dirs : Array[String],
  deny : Bool,
) -> LaneCommandOutcome {
  if (!libs.is_empty() || !lib_dirs.is_empty()) &&
    (!interfaces.is_empty() || !interface_dirs.is_empty()) {
    println(
      "check inputs must be either source libraries or module interfaces, not both",
    )
    return UserFailure
  }
  let source = read_source_file(file) catch {
    error => {
      println("failed to read source: \{error}")
      return UserFailure
    }
  }
  let result = if !interfaces.is_empty() || !interface_dirs.is_empty() {
    let imported_interfaces = read_module_interface_artifacts(
      interfaces, interface_dirs,
    ) catch {
      error => {
        println("failed to read module interface artifact: \{error}")
        return UserFailure
      }
    }
    @compile.check_source_with_interface_artifacts(source, imported_interfaces)
  } else {
    let libraries = read_library_sources(libs, lib_dirs) catch {
      error => {
        println("failed to read library source: \{error}")
        return UserFailure
      }
    }
    @compile.check_sources(source, libraries)
  }
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
  libs : Array[String],
  lib_dirs : Array[String],
  interfaces : Array[String],
  interface_dirs : Array[String],
  out : String?,
  out_dir : String?,
) -> LaneCommandOutcome {
  if out is Some(_) && out_dir is Some(_) {
    println("compile output must be either --out or --out-dir, not both")
    return UserFailure
  }
  if (!libs.is_empty() || !lib_dirs.is_empty()) &&
    (!interfaces.is_empty() || !interface_dirs.is_empty()) {
    println(
      "compile inputs must be either source libraries or module interfaces, not both",
    )
    return UserFailure
  }
  let source = read_source_file(file) catch {
    error => {
      println("failed to read source: \{error}")
      return UserFailure
    }
  }
  let result = if !interfaces.is_empty() || !interface_dirs.is_empty() {
    let imported_interfaces = read_module_interface_artifacts(
      interfaces, interface_dirs,
    ) catch {
      error => {
        println("failed to read module interface artifact: \{error}")
        return UserFailure
      }
    }
    @compile.compile_module_with_interface_artifacts(
      source, imported_interfaces,
    )
  } else {
    let libraries = read_library_sources(libs, lib_dirs) catch {
      error => {
        println("failed to read library source: \{error}")
        return UserFailure
      }
    }
    @compile.compile_modules(source, libraries)
  }
  if !result.diagnostics.is_empty() {
    print_diagnostics(result.diagnostics)
    return UserFailure
  }
  guard result.modules is Some(modules) else {
    internal_error("compiler produced no compiled modules")
  }
  if out is Some(path) {
    write_compiled_module_artifact(path, modules) catch {
      error => {
        println("failed to write module artifact: \{error}")
        return UserFailure
      }
    }
    println("wrote artifact " + path)
  }
  if out_dir is Some(path) {
    write_compiled_module_artifact_dir(path, modules) catch {
      error => {
        println("failed to write module artifact directory: \{error}")
        return UserFailure
      }
    }
    println("wrote artifact directory " + path)
  }
  println("compiled root " + modules.root_module_path_text)
  println("compiled modules " + module_names(modules.modules).join(","))
  Succeeded
}

///|
async fn lane_link(
  file : String?,
  artifacts : Array[String],
  artifact_dirs : Array[String],
  root : String?,
  libs : Array[String],
  lib_dirs : Array[String],
) -> LaneCommandOutcome {
  let artifact_count = artifacts.length() + artifact_dirs.length()
  if file is Some(_) && artifact_count != 0 {
    println("link target must be either FILE or module artifacts, not both")
    return UserFailure
  }
  match file {
    Some(path) => {
      if root is Some(_) {
        println("--root is only valid when linking module artifacts")
        return UserFailure
      }
      lane_link_source(path, libs, lib_dirs)
    }
    None =>
      if artifact_count == 0 {
        println("link target must be FILE, --artifact, or --artifact-dir")
        UserFailure
      } else if artifact_count > 1 && root is None {
        println(
          "link root required when linking multiple module artifact inputs",
        )
        UserFailure
      } else {
        lane_link_artifacts(artifacts, artifact_dirs, root)
      }
  }
}

///|
async fn lane_link_source(
  file : String,
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
  let compiled = @compile.compile_modules(source, libraries)
  if !compiled.diagnostics.is_empty() {
    print_diagnostics(compiled.diagnostics)
    return UserFailure
  }
  guard compiled.modules is Some(modules) else {
    internal_error("compiler produced no compiled modules")
  }
  let linked = @compile.link_modules(modules)
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
async fn lane_link_artifacts(
  artifacts : Array[String],
  artifact_dirs : Array[String],
  root : String?,
) -> LaneCommandOutcome {
  let artifact = match
    read_link_artifact_inputs(artifacts, artifact_dirs, root) {
    Ok(artifact) => artifact
    Err(message) => {
      println(message)
      return UserFailure
    }
  }
  let linked = @compile.link_module_artifacts(artifact)
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
fn module_names(modules : Array[@compile.CompiledModule]) -> Array[String] {
  modules.map(fn(module_) { module_.module_path_text })
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
