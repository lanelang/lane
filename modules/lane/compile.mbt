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
