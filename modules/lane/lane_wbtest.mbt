///|
test "parse run target from file and entry suffix" {
  guard parse_run_target("examples/main.lane:answer") is Ok(target) else {
    abort("expected run target")
  }
  inspect(target.file, content="examples/main.lane")
  inspect(target.entry, content="answer")
}

///|
test "reject run target without entry suffix" {
  guard parse_run_target("examples/main.lane") is Err(message) else {
    abort("expected run target error")
  }
  inspect(
    message,
    content=(
      #|error[E6002]: invalid run target
      #|  = label: expected `FILE:ENTRY`, got `examples/main.lane`
      #|  = note: `lane run` compiles one source file and then selects a public entry from it
      #|  = help: try: lane run Main.lane:main
    ),
  )
}

///|
test "compile output errors explain both long and short flags" {
  inspect(
    missing_compile_output_error("--emit-interface", "-t"),
    content=(
      #|error[E6004]: missing compile output path
      #|  = label: `lane compile` requires `--emit-interface` to choose where to write an artifact
      #|  = note: compile writes a module interface and a module object as separate artifacts
      #|  = help: try: lane compile Main.lane -t Main.lmi -o Main.lmo
      #|  = help: short form: `-t <path>`
    ),
  )
}

///|
test "run selected public value through buslane interpreter" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub let answer : Int = 42
      #|let hidden : Int = 1
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program,
    @intrinsics.standard_external_runtime(result.externals),
  )
  let entry = find_entry(result.entries, "answer")
  guard entry is Ok(entry) else { abort("expected entry") }
  inspect(
    render_entry_value(runtime.lookup(entry.value), entry.type_),
    content="42 : Int",
  )
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "selected public function entry renders as function" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub fn id(x : Int) -> Int { x }
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let runtime = @buslane_interpreter.evaluate_buslane_program(
    program,
    @intrinsics.standard_external_runtime(result.externals),
  )
  let entry = find_entry(result.entries, "id")
  guard entry is Ok(entry) else { abort("expected entry") }
  inspect(
    render_entry_value(runtime.lookup(entry.value), entry.type_),
    content="<function> : (Int) -> Int",
  )
}

///|
test "missing entry error lists available public entries" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub let answer : Int = 42
    ),
  )
  guard find_entry(result.entries, "main") is Err(message) else {
    abort("expected missing entry")
  }
  inspect(
    message,
    content=(
      #|error[E6005]: entry was not found in the linked program
      #|  = label: requested entry `main` does not exist
      #|  = note: available public entries: answer
      #|  = help: use one of the listed public entries, or export the value with `pub` before compiling
    ),
  )
}

///|
test "render primitive entry values with source type annotations" {
  inspect(
    render_entry_value(
      @buslane_interpreter.BuslaneRuntimeValue::bool(true),
      Primitive(Bool),
    ),
    content="true : Bool",
  )
  inspect(
    render_entry_value(
      @buslane_interpreter.BuslaneRuntimeValue::string("lane"),
      Primitive(String),
    ),
    content="\"lane\" : String",
  )
  inspect(
    render_entry_value(
      @buslane_interpreter.BuslaneRuntimeValue::unit(),
      Primitive(Unit),
    ),
    content="() : Unit",
  )
}

///|
test "internal compiler error is marked as a compiler bug" {
  inspect(
    internal_compiler_error("callee is not callable"),
    content=(
      #|error[E6200]: internal Lane compiler/runtime error
      #|  = label: compiler/runtime invariant failed: callee is not callable
      #|  = note: this is not expected after a successful Lane typecheck
      #|  = help: please file a compiler bug with the source file, command, and this diagnostic
    ),
  )
}

///|
test "check deny controls warning failures" {
  let warning : @compile.CompileDiagnostic = {
    source_id: None,
    message: "example warning",
    span: None,
    severity: Warning,
    code: None,
    labels: [],
    notes: [],
    helps: [],
  }
  let error : @compile.CompileDiagnostic = {
    source_id: None,
    message: "example error",
    span: None,
    severity: Error,
    code: None,
    labels: [],
    notes: [],
    helps: [],
  }
  inspect(denied_diagnostics([warning], false).length(), content="0")
  inspect(denied_diagnostics([warning], true).length(), content="1")
  inspect(denied_diagnostics([error], false).length(), content="1")
}

///|
async test "lib-dir excludes root source and deduplicates libraries" {
  let workspace = ".tmp-lane-library-sources"
  let root = "\{workspace}/Main.lane"
  let lib = "\{workspace}/Lib.lane"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  @fs.write_file(root, "root", create_mode=CreateOrTruncate)
  @fs.write_file(lib, "lib", create_mode=CreateOrTruncate)
  guard read_library_sources(root, [lib], [workspace]) is Ok(sources) else {
    cleanup_library_fixture(workspace)
    abort("expected normalized library sources")
  }
  cleanup_library_fixture(workspace)
  inspect(sources.length(), content="1")
  inspect(sources[0], content="lib")
}

///|
async test "explicit lib cannot be the root source" {
  let workspace = ".tmp-lane-root-lib"
  let root = "\{workspace}/Main.lane"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  @fs.write_file(root, "root", create_mode=CreateOrTruncate)
  guard read_library_sources(root, [root], []) is Err(message) else {
    cleanup_library_fixture(workspace)
    abort("expected explicit root library error")
  }
  cleanup_library_fixture(workspace)
  inspect(
    message,
    content=(
      #|error[E6008]: root source was also passed as an explicit library
      #|  = label: `.tmp-lane-root-lib/Main.lane` resolves to the same source file as the root source `.tmp-lane-root-lib/Main.lane`
      #|  = note: `lane check` and `lane run` compile the root source separately from library inputs
      #|  = note: `--lib-dir` discovery silently skips the root source, but explicit `--lib` keeps mistakes visible
      #|  = help: remove the duplicate `--lib .tmp-lane-root-lib/Main.lane` argument
    ),
  )
}

///|
#cfg(not(platform="windows"))
async test "library source identity resolves symlinks" {
  let workspace = ".tmp-lane-library-symlinks"
  let root = "\{workspace}/Main.lane"
  let lib = "\{workspace}/Lib.lane"
  let lib_alias = "\{workspace}/LibAlias.lane"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  @fs.write_file(root, "root", create_mode=CreateOrTruncate)
  @fs.write_file(lib, "lib", create_mode=CreateOrTruncate)
  @fs.symlink(lib_alias, target="Lib.lane")
  guard read_library_sources(root, [lib_alias, lib], []) is Ok(sources) else {
    cleanup_library_fixture(workspace)
    abort("expected symlinked duplicate library to be deduped")
  }
  cleanup_library_fixture(workspace)
  inspect(sources.length(), content="1")
  inspect(sources[0], content="lib")
}

///|
async fn cleanup_library_fixture(workspace : String) -> Unit {
  @fs.rmdir(workspace, recursive=true) catch {
    _ => ()
  }
}
