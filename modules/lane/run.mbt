///|
async fn lane_exec(path : String, no_jit? : Bool = false) -> LaneCommandOutcome {
  let artifact = match read_linked_program_artifact(path) {
    Ok(artifact) => artifact
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_wasm_artifact_with_output(artifact, line => println(line), no_jit~)
}

///|
async fn lane_run(
  file : String,
  entry : String,
  libs : Array[String],
  lib_dirs : Array[String],
  no_basic? : Bool = false,
  no_jit? : Bool = false,
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
  let libraries = match
    read_source_command_library_inputs(file, libs, lib_dirs, no_basic~) {
    Ok(libraries) => libraries
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let diagnostic_sources = LaneSourceInput::diagnostic_sources(root, libraries)
  let result = @compile.compile({
    root: root.to_compile_input(),
    libraries: LaneSourceInput::array_to_compile_inputs(libraries),
  })
  let diagnostics = result.diagnostics()
  let failures = denied_diagnostics(diagnostics, false)
  if !failures.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      diagnostics, diagnostic_sources, false,
    )
  }
  let program = match result {
    Succeeded(program, _) => program
    Failed(_) => return internal_error("failed compilation had no errors")
  }
  if !diagnostics.is_empty() {
    print_diagnostics_with_sources(diagnostics, diagnostic_sources)
  }
  let entry = match find_entry(program.entries(), entry) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_entry(program, entry, no_jit~)
}

///|
fn execute_entry(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  execute_entry_with_output(program, entry, line => println(line), no_jit~)
}

///|
fn execute_entry_with_output(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
  write_line : (String) -> Unit,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  let executable = match elaborate_command_entry(program, entry) {
    Ok(executable) => executable
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let artifact = match lower_executable_wasm(executable) {
    Ok(artifact) => artifact
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_wasm_artifact_with_output(artifact, write_line, no_jit~)
}

///|
fn lower_executable_wasm(
  executable : @executable.ExecutableProgram,
) -> Result[@artifact.LinkedProgramArtifact, CliError] {
  match @artifact.executable_to_wasm_artifact(executable) {
    Ok(artifact) => Ok(artifact)
    Err(error) => Err(ExecutionImageLowering(message="\{Repr(error)}"))
  }
}

///|
fn elaborate_command_entry(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
) -> Result[@executable.ExecutableProgram, CliError] {
  match program.elaborate_entry(entry, lane_command_execution_profile()) {
    Ok(executable) => Ok(executable)
    Err(EntryAdmissionRejected(type_~, reason~, ..)) =>
      Err(EntryNotExecutable(name=display_entry(entry), type_~, reason~))
    Err(UnsupportedEffectSpecialization(detail~)) =>
      Err(ExecutionImageLowering(message=detail))
    Err(error) =>
      Err(Internal(message="executable elaboration failed: \{Repr(error)}"))
  }
}

///|
fn execute_wasm_artifact_with_output(
  artifact : @artifact.LinkedProgramArtifact,
  write_line : (String) -> Unit,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  let mode = if no_jit {
    @lane_wasm_runtime.ExecutionMode::Interpreter
  } else {
    Jit
  }
  let loaded = match
    @lane_wasm_runtime.load_wasm(
      artifact.wasm,
      artifact.runtime_imports,
      command_runtime_registry(write_line),
      mode~,
    ) {
    Ok(loaded) => loaded
    Err(error) =>
      return LaneCommandOutcome::user_error(
        ExecutionImageLoad(message="\{Repr(error)}"),
      )
  }
  let instance = match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) =>
      return LaneCommandOutcome::user_error(
        ExecutionImageLoad(message="\{Repr(error)}"),
      )
  }
  match instance.execute() {
    Ok(_) => Succeeded
    Err(error) => LaneCommandOutcome::user_error(ExecutionFailed(error))
  }
}

///|
fn command_runtime_registry(
  write_line : (String) -> Unit,
) -> @lane_runtime.RuntimeRegistry {
  let registry = @lane_runtime.RuntimeRegistry::new()
  registry.register(
    @lane_runtime.RuntimeBinding::new(
      symbol="println",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=(_context, arguments) => {
        guard arguments is [BorrowedString(line)] else {
          raise Failure(message="println expects one String argument")
        }
        write_line(line.to_string())
        Unit
      },
    ),
  )
  registry
}

///|
fn find_entry(
  entries : Array[@compile.CompiledEntry],
  name : String,
) -> Result[@compile.CompiledEntry, CliError] {
  let matched = entries.filter(entry => entry.name() == name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(EntryNotFound(name~, entries~))
    _ => Err(EntryAmbiguous(name~, entries~))
  }
}

///|
fn find_public_entry(
  entries : Array[@compile.CompiledEntry],
  name : PublicEntryName,
) -> Result[@compile.CompiledEntry, CliError] {
  let matched = entries.filter(fn(entry) {
    entry.module_path_text() == name.module_path_text &&
    entry.name() == name.value_name
  })
  let display_name = display_public_entry_name(name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(EntryNotFound(name=display_name, entries~))
    _ => Err(EntryAmbiguous(name=display_name, entries~))
  }
}
