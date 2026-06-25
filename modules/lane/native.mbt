///|
async fn read_source_file(path : String) -> String {
  @fs.read_file(path).text()
}

///|
async fn write_source_file(path : String, source : String) -> Unit {
  @fs.write_file(path, source, create_mode=CreateOrTruncate)
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
