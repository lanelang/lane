///|
async fn lane_compile(
  file : String,
  interfaces : Array[String],
  emit_interface : String?,
  emit_object : String?,
  verbose : Bool,
) -> LaneCommandOutcome {
  let interface_path = compile_output_path(file, emit_interface, ".lmi")
  let object_path = compile_output_path(file, emit_object, ".lmo")
  let source = read_source_file(file) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Compile, file, "\{error}"),
      )
  }
  let root : LaneSourceInput = {
    source_id: file,
    path: Some(file),
    text: source,
  }
  let imported_interfaces = match read_module_interface_artifacts(interfaces) {
    Ok(imported_interfaces) => imported_interfaces
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let diagnostic_sources = LaneSourceInput::diagnostic_sources(root, [])
  let result = @compile.compile_module_input_with_interface_artifacts(
    root.to_compile_input(),
    imported_interfaces,
  )
  let failures = denied_diagnostics(result.diagnostics, false)
  if !failures.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      false,
    )
  }
  guard result.modules is Some(modules) else {
    internal_error("compiler produced no compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    internal_error("compiler produced no compiled module")
  }
  write_module_interface_artifact(interface_path, module_) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Write, interface_path, "\{error}"),
      )
  }
  write_module_object_artifact(object_path, module_) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Write, object_path, "\{error}"),
      )
  }
  if verbose {
    println("compiled module \{module_.module_path_text}")
    println("wrote interface \{interface_path}")
    println("wrote object \{object_path}")
  }
  if !result.diagnostics.is_empty() {
    LaneCommandOutcome::compile_diagnostics(
      result.diagnostics,
      diagnostic_sources,
      true,
    )
  } else {
    Succeeded
  }
}

///|
fn compile_output_path(
  source_path : String,
  explicit_path : String?,
  suffix : String,
) -> String {
  if explicit_path is Some(path) {
    path
  } else {
    default_compile_artifact_path(source_path, suffix)
  }
}

///|
fn default_compile_artifact_path(
  source_path : String,
  suffix : String,
) -> String {
  let filename_start = last_path_separator_index(source_path) + 1
  let stem_end = match last_extension_dot_index(source_path, filename_start) {
    Some(index) => index
    None => source_path.length()
  }
  "\{source_path[:stem_end]}\{suffix}"
}

///|
fn last_path_separator_index(path : String) -> Int {
  let mut last = -1
  for index in 0..<path.length() {
    if path[index] == '/' {
      last = index
    }
  }
  last
}

///|
fn last_extension_dot_index(path : String, filename_start : Int) -> Int? {
  let mut last : Int? = None
  for index in filename_start..<path.length() {
    if path[index] == '.' {
      last = Some(index)
    }
  }
  last
}
