///|
priv struct LaneSourceInput {
  source_id : String
  path : String?
  text : String
}

///|
fn LaneSourceInput::to_compile_input(
  self : LaneSourceInput,
) -> @compile.SourceInput {
  { source_id: self.source_id, text: self.text }
}

///|
fn LaneSourceInput::array_to_compile_inputs(
  inputs : Array[LaneSourceInput],
) -> Array[@compile.SourceInput] {
  inputs.map(LaneSourceInput::to_compile_input)
}

///|
fn LaneSourceInput::diagnostic_sources(
  root : LaneSourceInput,
  libraries : Array[LaneSourceInput],
) -> DiagnosticSources {
  let sources = DiagnosticSources::DiagnosticSources()
  sources.add_input(root)
  for library in libraries {
    sources.add_input(library)
  }
  sources
}

///|
async fn read_source_file(path : String) -> String {
  @fs.read_file(path).text()
}

///|
async fn write_source_file(path : String, source : String) -> Unit {
  @fs.write_file(path, source, create_mode=CreateOrTruncate)
}

///|
async fn read_binary_file(path : String) -> Bytes {
  @fs.read_file(path).binary()
}

///|
async fn write_binary_file(path : String, bytes : Bytes) -> Unit {
  @fs.write_file(path, bytes, create_mode=CreateOrTruncate)
}

///|
async fn write_module_interface_artifact(
  path : String,
  module_ : @compile.CompiledModule,
) -> Unit {
  write_binary_file(
    path,
    @compile.module_interface_artifact_to_binary(
      module_.to_interface_artifact(),
    ),
  )
}

///|
async fn write_module_object_artifact(
  path : String,
  module_ : @compile.CompiledModule,
) -> Unit {
  write_binary_file(
    path,
    @compile.module_object_artifact_to_binary(module_.to_object_artifact()),
  )
}

///|
async fn read_module_interface_artifact(
  path : String,
) -> @compile.ModuleInterfaceArtifact {
  let bytes = read_binary_file(path)
  match @compile.parse_module_interface_artifact_binary(bytes) {
    Ok(artifact) => artifact
    Err(message) => fail(message)
  }
}

///|
async fn read_module_object_artifact(
  path : String,
) -> @compile.ModuleObjectArtifact {
  let bytes = read_binary_file(path)
  match @compile.parse_module_object_artifact_binary(bytes) {
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
    @compile.linked_program_artifact_to_text(program.to_artifact()),
  )
}

///|
async fn read_linked_program_artifact(path : String) -> @compile.LinkedProgram {
  let source = read_source_file(path)
  let artifact = match @compile.parse_linked_program_artifact_text(source) {
    Ok(artifact) => artifact
    Err(message) => fail(message)
  }
  match artifact.to_linked_program() {
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
async fn read_library_source_inputs(
  root : String,
  libs : Array[String],
  lib_dirs : Array[String],
) -> Result[Array[LaneSourceInput], String] {
  let root_identity = match library_source_identity(root) {
    Ok(identity) => identity
    Err(message) => return Err(message)
  }
  let identities = []
  let sources = []
  for lib in libs {
    match
      append_library_source(Some(root), root_identity, lib, identities, sources) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for dir in lib_dirs {
    match append_library_dir_sources(root_identity, dir, identities, sources) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(sources)
}

///|
async fn library_source_identity(path : String) -> Result[String, String] {
  let identity = @fs.realpath(path) catch {
    error => return Err(resolve_file_error(path, "\{error}"))
  }
  Ok(identity)
}

///|
async fn append_library_source(
  explicit_root : String?,
  root_identity : String,
  path : String,
  identities : Array[String],
  sources : Array[LaneSourceInput],
) -> Result[Unit, String] {
  let identity = match library_source_identity(path) {
    Ok(identity) => identity
    Err(message) => return Err(message)
  }
  if identity == root_identity {
    match explicit_root {
      Some(root) => return Err(root_library_input_error(root, path))
      None => return Ok(())
    }
  }
  if identities.contains(identity) {
    return Ok(())
  }
  let source = read_source_file(path) catch {
    error => return Err(read_file_error(path, "\{error}"))
  }
  identities.push(identity)
  sources.push({ source_id: path, path: Some(path), text: source })
  Ok(())
}

///|
async fn append_library_dir_sources(
  root_identity : String,
  path : String,
  identities : Array[String],
  sources : Array[LaneSourceInput],
) -> Result[Unit, String] {
  let entries = @fs.readdir(path, sort=true) catch {
    error => return Err(read_file_error(path, "\{error}"))
  }
  for entry in entries {
    if should_skip_library_entry(entry) {
      continue
    }
    let child = "\{path}/\{entry}"
    let kind = @fs.kind(child) catch {
      error => return Err(read_file_error(child, "\{error}"))
    }
    match kind {
      Directory =>
        match
          append_library_dir_sources(root_identity, child, identities, sources) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      Regular if child.has_suffix(".lane") =>
        match
          append_library_source(None, root_identity, child, identities, sources) {
          Ok(_) => ()
          Err(message) => return Err(message)
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
