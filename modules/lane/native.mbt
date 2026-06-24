///|
fn read_source_file(path : String) -> String raise {
  @fs.read_file_to_string(path, encoding="utf8")
}

///|
fn write_source_file(path : String, source : String) -> Unit raise {
  @fs.write_string_to_file(path, source, encoding="utf8")
}

///|
fn read_library_sources(
  libs : Array[String],
  lib_dirs : Array[String],
) -> Array[String] raise {
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
fn append_library_dir_sources(
  path : String,
  sources : Array[String],
) -> Unit raise {
  let entries = @fs.read_dir(path)
  entries.sort()
  for entry in entries {
    if should_skip_library_entry(entry) {
      continue
    }
    let child = path + "/" + entry
    if @fs.is_dir(child) {
      append_library_dir_sources(child, sources)
    } else if @fs.is_file(child) && child.has_suffix(".lane") {
      sources.push(read_source_file(child))
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
