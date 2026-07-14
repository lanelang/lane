///|
async fn lane_exec(path : String) -> LaneCommandOutcome {
  let image = match read_linked_program_artifact(path) {
    Ok(image) => image
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_loisvm_image_with_output(image, line => println(line))
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
  let failures = denied_diagnostics(result.diagnostics, false)
  if !failures.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      false,
    )
  }
  guard result.program is Some(program) else {
    internal_error("compiler produced no Buslane program")
  }
  if !result.diagnostics.is_empty() {
    print_diagnostics_with_sources(result.diagnostics, diagnostic_sources)
  }
  let entry = match find_entry(result.entries, entry) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_entry(
    program,
    result.externals,
    result.runtime_effect_operations,
    entry,
  )
}

///|
fn execute_entry(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  runtime_effect_operations : Array[@module_link.LinkedRuntimeEffectOperation],
  entry : @buslane_lowering.BuslaneEntry,
) -> LaneCommandOutcome {
  execute_entry_with_output(
    program,
    externals,
    runtime_effect_operations,
    entry,
    line => println(line),
  )
}

///|
fn execute_entry_with_output(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  runtime_effect_operations : Array[@module_link.LinkedRuntimeEffectOperation],
  entry : @buslane_lowering.BuslaneEntry,
  write_line : (String) -> Unit,
) -> LaneCommandOutcome {
  let runtime_effects = command_runtime_effects(
    program, runtime_effect_operations,
  )
  match validate_executable_entry(entry, runtime_effects) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let linked : @module_link.LinkedProgram = {
    module_path_texts: [],
    program,
    externals,
    entries: [entry],
    runtime_effect_operations,
  }
  let executable = match elaborate_linked_executable(linked, entry) {
    Ok(executable) => executable
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let image = match lower_executable_image(executable) {
    Ok(image) => image
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_loisvm_image_with_output(image, write_line)
}

///|
fn elaborate_linked_executable(
  linked : @module_link.LinkedProgram,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@executable.ExecutableProgram, CliError] {
  match @executable.elaborate(linked, entry) {
    Ok(executable) => Ok(executable)
    Err(error) => Err(ExecutionImageLowering(message="\{to_repr(error)}"))
  }
}

///|
fn lower_executable_image(
  executable : @executable.ExecutableProgram,
) -> Result[@loisvm_bytecode.BytecodeImage, CliError] {
  match @artifact_binary.lower_executable_to_loisvm_bytecode(executable) {
    Ok(image) => Ok(image)
    Err(error) => Err(ExecutionImageLowering(message="\{to_repr(error)}"))
  }
}

///|
fn validate_executable_entry(
  entry : @buslane_lowering.BuslaneEntry,
  runtime_effects : Array[@buslane.EffectId],
) -> Result[Unit, CliError] {
  guard entry.type_ is Function(parameters, result, effect) else {
    return Err(
      EntryNotExecutable(
        name=display_entry(entry),
        type_=entry.type_,
        reason=EntryIsNotFunction,
      ),
    )
  }
  if !parameters.is_empty() {
    return Err(
      EntryNotExecutable(
        name=display_entry(entry),
        type_=entry.type_,
        reason=EntryHasParameters(count=parameters.length()),
      ),
    )
  }
  if result != Primitive(Unit) {
    return Err(
      EntryNotExecutable(
        name=display_entry(entry),
        type_=entry.type_,
        reason=EntryReturnsNonUnit(result~),
      ),
    )
  }
  if !entry_effect_is_supported(effect, runtime_effects) {
    return Err(
      EntryNotExecutable(
        name=display_entry(entry),
        type_=entry.type_,
        reason=EntryHasUnsupportedEffects(effect~),
      ),
    )
  }
  Ok(())
}

///|
fn execute_loisvm_image_with_output(
  image : @loisvm_bytecode.BytecodeImage,
  write_line : (String) -> Unit,
) -> LaneCommandOutcome {
  let loaded = match
    @loisvm_wasm.load(image, command_loisvm_runtime(write_line)) {
    Ok(loaded) => loaded
    Err(error) =>
      return LaneCommandOutcome::user_error(
        ExecutionImageLoad(message="\{to_repr(error)}"),
      )
  }
  let instance = match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) =>
      return LaneCommandOutcome::user_error(
        ExecutionImageLoad(message="\{to_repr(error)}"),
      )
  }
  match instance.execute() {
    Ok(_) => Succeeded
    Err(error) =>
      LaneCommandOutcome::user_error(
        ExecutionFailed(message="\{to_repr(error)}"),
      )
  }
}

///|
fn command_loisvm_runtime(
  write_line : (String) -> Unit,
) -> @loisvm_runtime.RuntimeRegistry {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.effect.v1/Basic.Io/Write/println",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=(_context, arguments) => {
        guard arguments is [BorrowedString(line)] else {
          raise Failure(
            message="Basic.Io.Write.println expects one String argument",
          )
        }
        write_line(line.to_string())
        Unit
      },
    ),
  )
  registry
}

///|
fn command_runtime_effects(
  program : @buslane.Program,
  runtime_effect_operations : Array[@module_link.LinkedRuntimeEffectOperation],
) -> Array[@buslane.EffectId] {
  let effects = []
  if command_runtime_effect_operation(program, runtime_effect_operations)
    is Some(operation) {
    if program.metadata.operation_info(operation) is Some(info) {
      effects.push(info.owner)
    }
  }
  effects
}

///|
fn command_runtime_effect_operation(
  program : @buslane.Program,
  runtime_effect_operations : Array[@module_link.LinkedRuntimeEffectOperation],
) -> @buslane.OperationId? {
  let signature = basic_io_write_println_signature()
  for operation in runtime_effect_operations {
    if runtime_effect_operation_matches(operation, signature) &&
      program.metadata.operation_info(operation.operation) is Some(_) {
      return Some(operation.operation)
    }
  }
  None
}

///|
fn runtime_effect_operation_matches(
  operation : @module_link.LinkedRuntimeEffectOperation,
  signature : @module_link.RuntimeEffectOperationSignature,
) -> Bool {
  operation.module_path_text == signature.module_path_text &&
  operation.effect_name == signature.effect_name &&
  operation.operation_name == signature.operation_name &&
  operation.payload == signature.payload &&
  operation.result == signature.result
}

///|
fn basic_io_write_println_signature() -> @module_link.RuntimeEffectOperationSignature {
  {
    module_path_text: "Basic.Io",
    effect_name: "Write",
    operation_name: "println",
    payload: [Primitive(String)],
    result: Primitive(Unit),
  }
}

///|
fn entry_effect_is_supported(
  effect : @buslane.Effect,
  runtime_effects : Array[@buslane.EffectId],
) -> Bool {
  match effect {
    Empty => true
    Singleton(id, arguments) =>
      arguments.is_empty() &&
      runtime_effects.any(fn(effect_id) { effect_id == id })
    Parameter(_) => false
    Union(effects) =>
      effects.all(fn(effect) {
        entry_effect_is_supported(effect, runtime_effects)
      })
  }
}

///|
fn find_entry(
  entries : Array[@buslane_lowering.BuslaneEntry],
  name : String,
) -> Result[@buslane_lowering.BuslaneEntry, CliError] {
  let matched = entries.filter(entry => entry.name == name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(EntryNotFound(name~, entries~))
    _ => Err(EntryAmbiguous(name~, entries~))
  }
}

///|
fn find_public_entry(
  entries : Array[@buslane_lowering.BuslaneEntry],
  name : PublicEntryName,
) -> Result[@buslane_lowering.BuslaneEntry, CliError] {
  let matched = entries.filter(fn(entry) {
    entry.module_path_text == name.module_path_text &&
    entry.name == name.value_name
  })
  let display_name = display_public_entry_name(name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(EntryNotFound(name=display_name, entries~))
    _ => Err(EntryAmbiguous(name=display_name, entries~))
  }
}
