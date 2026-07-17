///|
async fn lane_compile(
  file : String,
  interfaces : Array[String],
  interface_path : String,
  object_path : String,
  verbose : Bool,
) -> LaneCommandOutcome {
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
    println("compiled module \{module_.object.module_path_text}")
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
