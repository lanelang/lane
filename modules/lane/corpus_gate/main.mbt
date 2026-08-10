///|
priv suberror CorpusGateFailure {
  CorpusGateFailure(String)
} derive(Debug)

///|
priv struct RunFixture {
  file : String
  entry : String
}

///|
let valid_corpus_maximum_control_depth = 23

///|
fn main {
  run_corpus_gate() catch {
    CorpusGateFailure(message) => abort(message)
    error => abort("\{Repr(error)}")
  }
}

///|
fn run_corpus_gate() -> Unit raise {
  guard @env.get_env_var("LANE_HOME") is Some(home) else {
    raise CorpusGateFailure("LANE_HOME is not set")
  }
  let libraries = read_library_sources(home.trim().to_owned() + "/basic")
  let fixtures = read_run_fixtures("examples/fixtures/lane-run.json")
  let mut maximum_depth = 0
  let mut maximum_fixture = ""
  for fixture in fixtures {
    let depth = compile_wasm_control_depth(fixture, libraries)
    if depth > valid_corpus_maximum_control_depth {
      raise CorpusGateFailure(
        fixture.file +
        ":" +
        fixture.entry +
        " produced Wasm control depth " +
        depth.to_string() +
        ", exceeding the valid-corpus bound " +
        valid_corpus_maximum_control_depth.to_string(),
      )
    }
    if depth > maximum_depth {
      maximum_depth = depth
      maximum_fixture = fixture.file + ":" + fixture.entry
    }
  }
  println(
    "valid example maximum Wasm control depth: " +
    maximum_depth.to_string() +
    " at " +
    maximum_fixture,
  )
}

///|
fn compile_wasm_control_depth(
  fixture : RunFixture,
  libraries : Array[@compile.SourceInput],
) -> Int raise {
  let program = match
    @compile.compile({
      root: { source_id: fixture.file, text: read_text(fixture.file) },
      libraries,
    }) {
    Succeeded(program, _) => program
    Failed(failure) =>
      raise CorpusGateFailure(
        fixture.file +
        ":" +
        fixture.entry +
        " failed compilation: " +
        "\{Repr(failure.diagnostics())}",
      )
  }
  let mut selected = None
  for entry in program.entries() {
    if entry.name() == fixture.entry {
      if selected is Some(_) {
        raise CorpusGateFailure(
          fixture.file +
          ":" +
          fixture.entry +
          " selects more than one compiled entry",
        )
      }
      selected = Some(entry)
    }
  }
  guard selected is Some(entry) else {
    raise CorpusGateFailure(
      fixture.file + ":" + fixture.entry + " is not a compiled entry",
    )
  }
  let executable = match program.elaborate_entry(entry) {
    Ok(executable) => executable
    Err(error) =>
      raise CorpusGateFailure(
        fixture.file +
        ":" +
        fixture.entry +
        " failed elaboration: " +
        "\{Repr(error)}",
      )
  }
  let image = match @artifact.lower_executable_to_loisvm_bytecode(executable) {
    Ok(image) => image
    Err(error) =>
      raise CorpusGateFailure(
        fixture.file +
        ":" +
        fixture.entry +
        " failed LoisVM lowering: " +
        "\{Repr(error)}",
      )
  }
  let module_ = match @loisvm_wasm.compile(image) {
    Ok(module_) => module_
    Err(error) =>
      raise CorpusGateFailure(
        fixture.file +
        ":" +
        fixture.entry +
        " failed Wasm compilation: " +
        "\{Repr(error)}",
      )
  }
  @loisvm_wasm.maximum_function_control_depth(module_)
}

///|
fn read_run_fixtures(path : String) -> Array[RunFixture] raise {
  let manifest = @json.parse(read_text(path))
  guard manifest is { "cases": Array(cases), .. } else {
    raise CorpusGateFailure(path + " must contain array field cases")
  }
  let fixtures = []
  for case in cases {
    guard case is { "mode": String(mode), .. } else { continue }
    if mode != "run" {
      continue
    }
    guard case is { "file": String(file), "entry": String(entry), .. } else {
      raise CorpusGateFailure("run fixture must contain string file and entry")
    }
    fixtures.push({ file, entry })
  }
  fixtures
}

///|
fn read_library_sources(
  directory : String,
) -> Array[@compile.SourceInput] raise {
  let sources = []
  append_library_sources(directory, sources)
  sources
}

///|
fn append_library_sources(
  directory : String,
  sources : Array[@compile.SourceInput],
) -> Unit raise {
  let entries = @fs.read_dir(directory)
  entries.sort()
  for entry in entries {
    if should_skip_library_entry(entry) {
      continue
    }
    let path = directory + "/" + entry
    if @fs.is_dir(path) {
      append_library_sources(path, sources)
    } else if entry.has_suffix(".lane") && @fs.is_file(path) {
      sources.push({ source_id: path, text: read_text(path) })
    }
  }
}

///|
fn should_skip_library_entry(entry : String) -> Bool {
  entry.has_prefix(".") ||
  entry == "_build" ||
  entry == "build" ||
  entry == "dist"
}

///|
fn read_text(path : String) -> String raise {
  @fs.read_file_to_string(path, encoding="utf8")
}
