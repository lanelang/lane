///|
async fn read_source_file(path : String) -> String {
  @fs.read_file(path).text()
}

///|
async fn write_source_file(path : String, source : String) -> Unit {
  @fs.write_file(path, source, create_mode=CreateOrTruncate)
}

///|
async fn write_compiled_module_artifact(
  path : String,
  modules : @compile.CompiledModuleSet,
) -> Unit {
  let artifact = @compile.compiled_module_set_artifact(modules)
  write_source_file(path, artifact.to_json().stringify())
}

///|
async fn read_compiled_module_artifact(
  path : String,
) -> @compile.CompiledModuleSetArtifact {
  let source = read_source_file(path)
  @json.from_json(@json.parse(source))
}

///|
async fn read_module_interface_artifact(
  path : String,
) -> @compile.ModuleInterfaceArtifact {
  let source = read_source_file(path)
  @json.from_json(@json.parse(source))
}

///|
struct CompiledModuleArtifactDir {
  manifest : @compile.CompiledModuleSetManifestArtifact
  interfaces : Array[@compile.ModuleInterfaceArtifact]
  objects : Array[@compile.ModuleObjectArtifact]
}

///|
async fn write_compiled_module_artifact_dir(
  path : String,
  modules : @compile.CompiledModuleSet,
) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, recursive=true)
  }
  let manifest = @compile.compiled_module_set_manifest_artifact(modules)
  write_source_file(path + "/lane-modules.json", manifest.to_json().stringify())
  for module_ in modules.modules {
    let interface = @compile.module_interface_artifact(module_)
    let object = @compile.module_object_artifact(module_.object)
    write_source_file(
      path + "/" + module_.module_path_text + ".lmi.json",
      interface.to_json().stringify(),
    )
    write_source_file(
      path + "/" + module_.module_path_text + ".lmo.json",
      object.to_json().stringify(),
    )
  }
}

///|
async fn read_compiled_module_artifact_dir(
  path : String,
) -> CompiledModuleArtifactDir {
  let manifest : @compile.CompiledModuleSetManifestArtifact = @json.from_json(
    @json.parse(read_source_file(path + "/lane-modules.json")),
  )
  let interfaces = []
  let objects = []
  for entry in manifest.modules {
    let interface : @compile.ModuleInterfaceArtifact = @json.from_json(
      @json.parse(read_source_file(path + "/" + entry.interface_file)),
    )
    let object : @compile.ModuleObjectArtifact = @json.from_json(
      @json.parse(read_source_file(path + "/" + entry.object_file)),
    )
    interfaces.push(interface)
    objects.push(object)
  }
  { manifest, interfaces, objects }
}

///|
async fn read_link_artifact_inputs(
  artifacts : Array[String],
  artifact_dirs : Array[String],
  root : String?,
) -> Result[@compile.CompiledModuleSetArtifact, String] {
  let sets = []
  for artifact in artifacts {
    let item = read_compiled_module_artifact(artifact) catch {
      error => return Err("failed to read module artifact: \{error}")
    }
    sets.push(item)
  }
  for artifact_dir in artifact_dirs {
    let artifact_dir = read_compiled_module_artifact_dir(artifact_dir) catch {
      error => return Err("failed to read module artifact directory: \{error}")
    }
    match compiled_module_set_artifact_from_dir(artifact_dir) {
      Ok(item) => sets.push(item)
      Err(message) => return Err(message)
    }
  }
  let root_module_path_text = match root {
    Some(root) => root
    None =>
      match sets.get(0) {
        Some(artifact) => artifact.root_module_path_text
        None =>
          return Err("link target must be FILE, --artifact, or --artifact-dir")
      }
  }
  merge_compiled_module_set_artifacts(sets, root_module_path_text)
}

///|
fn compiled_module_set_artifact_from_dir(
  artifact_dir : CompiledModuleArtifactDir,
) -> Result[@compile.CompiledModuleSetArtifact, String] {
  let modules : Array[@compile.CompiledModuleArtifact] = []
  for entry in artifact_dir.manifest.modules {
    guard find_interface_artifact(
        artifact_dir.interfaces,
        entry.module_path_text,
      )
      is Some(interface) else {
      return Err("missing module interface artifact " + entry.module_path_text)
    }
    guard find_object_artifact(artifact_dir.objects, entry.module_path_text)
      is Some(object) else {
      return Err("missing module object artifact " + entry.module_path_text)
    }
    modules.push({
      schema_version: 1,
      module_path_text: entry.module_path_text,
      interface,
      object,
      module_fingerprint: entry.module_fingerprint,
      imported_interface_fingerprints: entry.imported_interface_fingerprints,
    })
  }
  Ok({
    schema_version: artifact_dir.manifest.schema_version,
    root_module_path_text: artifact_dir.manifest.root_module_path_text,
    modules,
    reachable_module_path_texts: artifact_dir.manifest.reachable_module_path_texts,
  })
}

///|
fn merge_compiled_module_set_artifacts(
  artifacts : Array[@compile.CompiledModuleSetArtifact],
  root_module_path_text : String,
) -> Result[@compile.CompiledModuleSetArtifact, String] {
  let modules : Array[@compile.CompiledModuleArtifact] = []
  let reachable_module_path_texts : Array[String] = []
  for artifact in artifacts {
    for module_ in artifact.modules {
      if find_compiled_module_artifact(modules, module_.module_path_text)
        is Some(_) {
        return Err("duplicate module artifact " + module_.module_path_text)
      }
      modules.push(module_)
    }
    for module_path_text in artifact.reachable_module_path_texts {
      if !reachable_module_path_texts.contains(module_path_text) {
        reachable_module_path_texts.push(module_path_text)
      }
    }
  }
  Ok({
    schema_version: 1,
    root_module_path_text,
    modules,
    reachable_module_path_texts,
  })
}

///|
fn find_compiled_module_artifact(
  modules : Array[@compile.CompiledModuleArtifact],
  module_path_text : String,
) -> @compile.CompiledModuleArtifact? {
  for module_ in modules {
    if module_.module_path_text == module_path_text {
      return Some(module_)
    }
  }
  None
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
  let manifest_path = path + "/lane-modules.json"
  if @fs.exists(manifest_path) {
    append_manifest_module_interfaces(path, manifest_path, artifacts)
  } else {
    append_scanned_module_interfaces(path, artifacts)
  }
}

///|
async fn append_manifest_module_interfaces(
  path : String,
  manifest_path : String,
  artifacts : Array[@compile.ModuleInterfaceArtifact],
) -> Unit {
  let manifest : @compile.CompiledModuleSetManifestArtifact = @json.from_json(
    @json.parse(read_source_file(manifest_path)),
  )
  for entry in manifest.modules {
    artifacts.push(
      read_module_interface_artifact(path + "/" + entry.interface_file),
    )
  }
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
      Regular if child.has_suffix(".lmi.json") =>
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
