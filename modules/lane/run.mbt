///|
async fn lane_runobj(path : String, entry_name : String) -> LaneCommandOutcome {
  let program = match read_linked_program_artifact(path) {
    Ok(program) => program
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let entry = match find_entry(program.entries, entry_name) {
    Ok(entry) => entry
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  execute_entry(
    program.program,
    program.externals,
    program.runtime_effect_operations,
    entry,
  )
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
  if !result.diagnostics.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      false,
    )
  }
  guard result.program is Some(program) else {
    internal_error("compiler produced no Buslane program")
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
  externals : @elaborate.BuslaneExternalMap,
  runtime_effect_operations : Array[@compile.LinkedRuntimeEffectOperation],
  entry : @elaborate.BuslaneEntry,
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
  externals : @elaborate.BuslaneExternalMap,
  runtime_effect_operations : Array[@compile.LinkedRuntimeEffectOperation],
  entry : @elaborate.BuslaneEntry,
  write_line : (String) -> Unit,
) -> LaneCommandOutcome {
  let runtime_effects = command_runtime_effects(
    program, runtime_effect_operations,
  )
  match validate_executable_entry(entry, runtime_effects) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let external_runtime = command_external_runtime(
    externals, program, runtime_effect_operations, write_line,
  )
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program, external_runtime,
  ) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  let value = runtime.lookup(entry.value) catch {
    error => internal_error(@prettyprinter.render(error, width=100))
  }
  ignore(
    value.call([], external_runtime) catch {
      error => internal_error(@prettyprinter.render(error, width=100))
    },
  )
  Succeeded
}

///|
fn validate_executable_entry(
  entry : @elaborate.BuslaneEntry,
  runtime_effects : Array[@buslane.EffectId],
) -> Result[Unit, CliError] {
  guard entry.type_ is Function(parameters, result, effect) else {
    return Err(
      EntryNotExecutable(
        name=entry.name,
        type_=entry.type_,
        reason=EntryIsNotFunction,
      ),
    )
  }
  if !parameters.is_empty() {
    return Err(
      EntryNotExecutable(
        name=entry.name,
        type_=entry.type_,
        reason=EntryHasParameters(count=parameters.length()),
      ),
    )
  }
  if result != Primitive(Unit) {
    return Err(
      EntryNotExecutable(
        name=entry.name,
        type_=entry.type_,
        reason=EntryReturnsNonUnit(result~),
      ),
    )
  }
  if !entry_effect_is_supported(effect, runtime_effects) {
    return Err(
      EntryNotExecutable(
        name=entry.name,
        type_=entry.type_,
        reason=EntryHasUnsupportedEffects(effect~),
      ),
    )
  }
  Ok(())
}

///|
fn command_external_runtime(
  externals : @elaborate.BuslaneExternalMap,
  program : @buslane.Program,
  runtime_effect_operations : Array[@compile.LinkedRuntimeEffectOperation],
  write_line : (String) -> Unit,
) -> @buslane_interpreter.BuslaneExternalRuntime {
  let runtime = @intrinsics.standard_external_runtime(externals)
  if command_runtime_effect_operation(program, runtime_effect_operations)
    is Some(operation) {
    runtime.add_effect_handler(operation, fn(
      arguments,
    ) raise @buslane_interpreter.BuslaneRuntimeError {
      if arguments.length() != 1 {
        raise InvalidValue(
          message="Stdlib.Io.Write.println expects one argument",
        )
      }
      guard arguments[0].as_string() is Some(line) else {
        raise InvalidValue(
          message="Stdlib.Io.Write.println expects a string argument",
        )
      }
      write_line(line)
      @buslane_interpreter.BuslaneRuntimeValue::unit()
    })
  }
  runtime
}

///|
fn command_runtime_effects(
  program : @buslane.Program,
  runtime_effect_operations : Array[@compile.LinkedRuntimeEffectOperation],
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
  runtime_effect_operations : Array[@compile.LinkedRuntimeEffectOperation],
) -> @buslane.OperationId? {
  let signature = stdlib_io_write_println_signature()
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
  operation : @compile.LinkedRuntimeEffectOperation,
  signature : @compile.RuntimeEffectOperationSignature,
) -> Bool {
  operation.module_path_text == signature.module_path_text &&
  operation.effect_name == signature.effect_name &&
  operation.operation_name == signature.operation_name &&
  operation.payload == signature.payload &&
  operation.result == signature.result
}

///|
fn stdlib_io_write_println_signature() -> @compile.RuntimeEffectOperationSignature {
  {
    module_path_text: "Stdlib.Io",
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
  entries : Array[@elaborate.BuslaneEntry],
  name : String,
) -> Result[@elaborate.BuslaneEntry, CliError] {
  let matched = entries.filter(entry => entry.name == name)
  match matched.length() {
    1 => Ok(matched[0])
    0 => Err(EntryNotFound(name~, entries~))
    _ => Err(EntryAmbiguous(name~, entries~))
  }
}
