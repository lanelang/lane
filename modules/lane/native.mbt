///|
async fn read_source_file(path : String) -> String {
  @fs.read_file(path).text()
}

///|
async fn write_source_file(path : String, source : String) -> Unit {
  @fs.write_file(path, source, create_mode=CreateOrTruncate)
}

///|
async fn write_module_interface_artifact(
  path : String,
  module_ : @compile.CompiledModule,
) -> Unit {
  write_source_file(
    path,
    @compile.module_interface_artifact_to_text(
      @compile.module_interface_artifact(module_),
    ),
  )
}

///|
async fn write_module_object_artifact(
  path : String,
  module_ : @compile.CompiledModule,
) -> Unit {
  write_source_file(
    path,
    @compile.module_object_artifact_to_text(
      @compile.module_object_artifact(module_),
    ),
  )
}

///|
async fn read_module_interface_artifact(
  path : String,
) -> @compile.ModuleInterfaceArtifact {
  let source = read_source_file(path)
  match @compile.parse_module_interface_artifact_text(source) {
    Ok(artifact) => artifact
    Err(message) => fail(message)
  }
}

///|
async fn read_module_object_artifact(
  path : String,
) -> @compile.ModuleObjectArtifact {
  let source = read_source_file(path)
  match @compile.parse_module_object_artifact_text(source) {
    Ok(artifact) => artifact
    Err(message) => fail(message)
  }
}

///|
async fn write_linked_program_artifact(
  path : String,
  program : @compile.LinkedProgram,
) -> Unit {
  write_source_file(
    path,
    @compile.linked_program_artifact_to_text(
      @compile.linked_program_artifact(program),
    ),
  )
}

///|
async fn read_linked_program_artifact(path : String) -> @compile.LinkedProgram {
  let source = read_source_file(path)
  let artifact = match @compile.parse_linked_program_artifact_text(source) {
    Ok(artifact) => artifact
    Err(message) => fail(message)
  }
  match @compile.linked_program_from_artifact(artifact) {
    Ok(program) => program
    Err(diagnostics) => fail(@prettyprinter.render(diagnostics, width=100))
  }
}

///|
async fn read_module_object_artifacts(
  object_paths : Array[String],
) -> Result[Array[@compile.ModuleObjectArtifact], String] {
  let objects = []
  for path in object_paths {
    let artifact = read_module_object_artifact(path) catch {
      error => return Err(read_file_error(path, "\{error}"))
    }
    if find_object_artifact(objects, artifact.module_path_text) is Some(_) {
      return Err(
        lane_boundary_error(
          "E6007",
          "duplicate module object artifact",
          ["module `\{artifact.module_path_text}` was provided more than once"],
          [
            "each module in a link input set must come from exactly one object artifact",
          ],
          ["remove the duplicate object path and run `lane link` again"],
        ),
      )
    }
    objects.push(artifact)
  }
  Ok(objects)
}

///|
fn find_object_artifact(
  objects : Array[@compile.ModuleObjectArtifact],
  module_path_text : String,
) -> @compile.ModuleObjectArtifact? {
  for object in objects {
    if object.module_path_text == module_path_text {
      return Some(object)
    }
  }
  None
}

///|
async fn read_module_interface_artifacts(
  interfaces : Array[String],
) -> Result[Array[@compile.ModuleInterfaceArtifact], String] {
  let artifacts = []
  for interface in interfaces {
    let artifact = read_module_interface_artifact(interface) catch {
      error => return Err(read_file_error(interface, "\{error}"))
    }
    artifacts.push(artifact)
  }
  Ok(artifacts)
}

///|
async fn read_library_sources(
  libs : Array[String],
  lib_dirs : Array[String],
) -> Result[Array[String], String] {
  let sources = []
  for lib in libs {
    let source = read_source_file(lib) catch {
      error => return Err(read_file_error(lib, "\{error}"))
    }
    sources.push(source)
  }
  for dir in lib_dirs {
    match append_library_dir_sources(dir, sources) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(sources)
}

///|
async fn append_library_dir_sources(
  path : String,
  sources : Array[String],
) -> Result[Unit, String] {
  let entries = @fs.readdir(path, sort=true) catch {
    error => return Err(read_file_error(path, "\{error}"))
  }
  for entry in entries {
    if should_skip_library_entry(entry) {
      continue
    }
    let child = path + "/" + entry
    match @fs.kind(child) {
      Directory =>
        match append_library_dir_sources(child, sources) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      Regular if child.has_suffix(".lane") => {
        let source = read_source_file(child) catch {
          error => return Err(read_file_error(child, "\{error}"))
        }
        sources.push(source)
      }
      _ => ()
    }
  }
  Ok(())
}

///|
fn should_skip_library_entry(entry : String) -> Bool {
  // TODO: Decide the final default-excluded directory names for library discovery.
  entry.has_prefix(".") ||
  entry == "_build" ||
  entry == "build" ||
  entry == "dist"
}

///|
fn[T] internal_error(message : String) -> T {
  abort(internal_compiler_error(message))
}
