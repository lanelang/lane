///|
async fn lane_link(
  objects : Array[String],
  export_requests : Array[PublicExportRequest],
  output : String,
  verbose : Bool,
) -> LaneCommandOutcome {
  let object_artifacts = match read_module_object_artifacts(objects) {
    Ok(objects) => objects
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let linked = @compile.link_module_objects(object_artifacts)
  let diagnostics = linked.diagnostics()
  if !diagnostics.is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      diagnostics,
      CompilerDiagnosticSources(),
      false,
    )
  }
  let program = match linked {
    Succeeded(program, _) => program
    Failed(_) => return internal_error("failed link had no errors")
  }
  let exports = []
  for request in export_requests {
    let entry = match
      find_public_entry(program.entries(), request.entry_name()) {
      Ok(entry) => entry
      Err(error) => return LaneCommandOutcome::user_error(error)
    }
    exports.push(@compile.CompiledExport::{ entry, name: request.wasm_name, })
  }
  let executable = match elaborate_command_exports(program, exports) {
    Ok(executable) => executable
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  match write_wasm_executable(output, executable) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  if verbose {
    let linked_modules = program.module_path_texts().join(",")
    println("linked WebAssembly module \{output}")
    println("linked modules \{linked_modules}")
    for request in export_requests {
      println(
        "exported \{display_public_entry_name(request.entry_name())} as \{request.wasm_name}",
      )
    }
  }
  Succeeded
}

///|
fn display_entry(entry : @compile.CompiledEntry) -> String {
  "\{entry.module_path_text()}.\{entry.name()}"
}

///|
fn display_public_entry_name(entry : PublicEntryName) -> String {
  "\{entry.module_path_text}.\{entry.value_name}"
}
