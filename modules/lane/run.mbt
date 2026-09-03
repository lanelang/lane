///|
async fn lane_exec(
  path : String,
  entry : String,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  let wasm = match read_wasm_executable(path) {
    Ok(wasm) => wasm
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_wasm(wasm, entry, no_jit~)
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
async fn execute_entry(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  execute_entry_with_output(program, entry, no_jit~)
}

///|
async fn execute_entry_with_output(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
  write_stdout? : ((Bytes) -> Unit)? = None,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  let executable = match elaborate_command_entry(program, entry) {
    Ok(executable) => executable
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let wasm = match lower_executable_wasm(executable) {
    Ok(wasm) => wasm
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_wasm_with_wasi_stdout(wasm, "_start", write_stdout, no_jit~)
}

///|
fn lower_executable_wasm(
  executable : @executable.ExecutableProgram,
) -> Result[Bytes, CliError] {
  match @artifact.executable_to_verified_wasm(executable) {
    Ok(wasm) => Ok(wasm.bytes())
    Err(error) => Err(wasm_executable_error_to_cli(error))
  }
}

///|
fn elaborate_command_entry(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
) -> Result[@executable.ExecutableProgram, CliError] {
  match validate_command_entry_invocation(program, entry) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
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
fn validate_command_entry_invocation(
  program : @compile.CompiledProgram,
  entry : @compile.CompiledEntry,
) -> Result[Unit, CliError] {
  guard program.entry_type(entry) is Some(type_) else {
    return Err(Internal(message="selected entry has no linked type metadata"))
  }
  let normalized = type_.normalize() catch {
    error =>
      return Err(
        Internal(
          message="selected entry type normalization failed: \{Repr(error)}",
        ),
      )
  }
  guard normalized is Function(parameters, result, _) else {
    return Err(
      EntryNotExecutable(name=display_entry(entry), type_~, reason=NotFunction),
    )
  }
  if !parameters.is_empty() {
    return Err(
      EntryNotInvocable(
        name=display_entry(entry),
        type_~,
        reason=HasParameters(count=parameters.length()),
      ),
    )
  }
  if result != Primitive(Unit) {
    return Err(
      EntryNotInvocable(
        name=display_entry(entry),
        type_~,
        reason=ReturnsNonUnit(result~),
      ),
    )
  }
  Ok(())
}

///|
fn elaborate_command_exports(
  program : @compile.CompiledProgram,
  exports : Array[@compile.CompiledExport],
) -> Result[@executable.ExecutableProgram, CliError] {
  match program.elaborate_exports(exports, lane_command_execution_profile()) {
    Ok(executable) => Ok(executable)
    Err(DuplicateExportName(name)) => Err(DuplicateLinkExportName(name~))
    Err(ReservedExportName(name)) => Err(ReservedLinkExportName(name~))
    Err(EntryAdmissionRejected(type_~, reason~, value~)) => {
      let mut name = "<unknown export>"
      for export_ in exports {
        if export_.entry.value_id() == value {
          name = display_entry(export_.entry)
        }
      }
      Err(ExportNotExecutable(name~, type_~, reason~))
    }
    Err(UnsupportedEffectSpecialization(detail~)) =>
      Err(ExecutionImageLowering(message=detail))
    Err(error) =>
      Err(Internal(message="executable elaboration failed: \{Repr(error)}"))
  }
}

///|
async fn execute_wasm(
  wasm : Bytes,
  entry : String,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  execute_wasm_with_wasi_stdout(wasm, entry, None, no_jit~)
}

///|
async fn execute_wasm_with_wasi_stdout(
  wasm : Bytes,
  entry : String,
  wasi_stdout : ((Bytes) -> Unit)?,
  no_jit? : Bool = false,
) -> LaneCommandOutcome {
  let mode = if no_jit {
    @lane_wasm_runtime.ExecutionMode::Interpreter
  } else {
    Jit
  }
  let current_directory = match @env.current_dir() {
    Some(directory) => directory
    None =>
      return LaneCommandOutcome::user_error(
        Internal(message="cannot determine the current working directory"),
      )
  }
  let loaded = match
    @lane_wasm_runtime.load_wasm(
      wasm,
      mode~,
      wasi_stdout~,
      wasi_preopens=[
        @lane_wasm_runtime.WasiPreopen::new(current_directory, "."),
      ],
      configure_host=configure_lane_runtime_v1,
    ) {
    Ok(loaded) => loaded
    Err(error) =>
      return LaneCommandOutcome::user_error(
        ExecutionImageLoad(message="\{Repr(error)}"),
      )
  }
  match loaded.execute_export_async(entry) {
    Ok(Returned) => Succeeded
    Ok(ProcessExit(code~)) => ProcessExited(code~)
    Err(error) => LaneCommandOutcome::user_error(ExecutionFailed(error))
  }
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
