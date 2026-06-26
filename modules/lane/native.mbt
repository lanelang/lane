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
  object : @compile.ModuleObject,
) -> Unit {
  write_source_file(
    path,
    @compile.module_object_artifact_to_text(
      @compile.module_object_artifact(object),
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
priv struct LinkArtifactInputs {
  manifest : @compile.CompiledModuleSetManifestArtifact
  interfaces : Array[@compile.ModuleInterfaceArtifact]
  objects : Array[@compile.ModuleObjectArtifact]
}

///|
async fn read_link_artifact_inputs(
  interface_paths : Array[String],
  object_paths : Array[String],
  root : String?,
) -> Result[LinkArtifactInputs, String] {
  let interfaces = []
  let objects = []
  for path in interface_paths {
    let artifact = read_module_interface_artifact(path) catch {
      error => return Err("failed to read module interface artifact: \{error}")
    }
    if find_interface_artifact(interfaces, artifact.module_path_text) is Some(_) {
      return Err(
        "duplicate module interface artifact " + artifact.module_path_text,
      )
    }
    interfaces.push(artifact)
  }
  for path in object_paths {
    let artifact = read_module_object_artifact(path) catch {
      error => return Err("failed to read module object artifact: \{error}")
    }
    if find_object_artifact(objects, artifact.module_path_text) is Some(_) {
      return Err(
        "duplicate module object artifact " + artifact.module_path_text,
      )
    }
    objects.push(artifact)
  }
  let root_module_path_text = match root {
    Some(root) => root
    None =>
      match objects.get(0) {
        Some(object) => object.module_path_text
        None => return Err("link requires --object")
      }
  }
  let reachable_module_path_texts : Array[String] = []
  let modules = objects.map(fn(object) {
    if !reachable_module_path_texts.contains(object.module_path_text) {
      reachable_module_path_texts.push(object.module_path_text)
    }
    @compile.ModuleArtifactManifestEntry::{
      module_path_text: object.module_path_text,
      interface_file: object.module_path_text + ".lmi",
      object_file: object.module_path_text + ".lmo",
      module_fingerprint: object.module_fingerprint,
      imported_interface_fingerprints: object.imported_interface_fingerprints,
    }
  })
  Ok({
    manifest: {
      schema_version: 1,
      root_module_path_text,
      modules,
      reachable_module_path_texts,
    },
    interfaces,
    objects,
  })
}

///|
fn find_interface_artifact(
  interfaces : Array[@compile.ModuleInterfaceArtifact],
  module_path_text : String,
) -> @compile.ModuleInterfaceArtifact? {
  for interface in interfaces {
    if interface.module_path_text == module_path_text {
      return Some(interface)
    }
  }
  None
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
  interface_dirs : Array[String],
) -> Array[@compile.ModuleInterfaceArtifact] {
  let artifacts = []
  for interface in interfaces {
    artifacts.push(read_module_interface_artifact(interface))
  }
  for dir in interface_dirs {
    append_module_interface_dir_artifacts(dir, artifacts)
  }
  artifacts
}

///|
async fn append_module_interface_dir_artifacts(
  path : String,
  artifacts : Array[@compile.ModuleInterfaceArtifact],
) -> Unit {
  append_scanned_module_interfaces(path, artifacts)
}

///|
async fn append_scanned_module_interfaces(
  path : String,
  artifacts : Array[@compile.ModuleInterfaceArtifact],
) -> Unit {
  let entries = @fs.readdir(path, sort=true)
  for entry in entries {
    if should_skip_library_entry(entry) {
      continue
    }
    let child = path + "/" + entry
    match @fs.kind(child) {
      Directory => append_scanned_module_interfaces(child, artifacts)
      Regular if child.has_suffix(".lmi") =>
        artifacts.push(read_module_interface_artifact(child))
      _ => ()
    }
  }
}

///|
async fn read_library_sources(
  libs : Array[String],
  lib_dirs : Array[String],
) -> Array[String] {
  let sources = []
  for lib in libs {
    sources.push(read_source_file(lib))
  }
  for dir in lib_dirs {
    append_library_dir_sources(dir, sources)
  }
  sources
}

///|
async fn append_library_dir_sources(
  path : String,
  sources : Array[String],
) -> Unit {
  let entries = @fs.readdir(path, sort=true)
  for entry in entries {
    if should_skip_library_entry(entry) {
      continue
    }
    let child = path + "/" + entry
    match @fs.kind(child) {
      Directory => append_library_dir_sources(child, sources)
      Regular if child.has_suffix(".lane") =>
        sources.push(read_source_file(child))
      _ => ()
    }
  }
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
  abort(message)
}
