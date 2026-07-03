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
  guard parse_run_target("examples/main.lane") is Err(error) else {
    abort("expected run target error")
  }
  debug_inspect(
    error,
    content="InvalidRunTarget(target=\"examples/main.lane\")",
  )
  inspect(
    error.render_human(),
    content=(
      #|error[E6002]: invalid run target
      #|  = label: expected `FILE:ENTRY`, got `examples/main.lane`
      #|  = note: `lane run` compiles one source file and then selects a public entry from it
      #|  = help: try: lane run Main.lane:main
    ),
  )
}

///|
test "parse runobj target from artifact and module-qualified entry" {
  guard parse_runobj_target("program.lbp:Main.answer") is Ok(target) else {
    abort("expected runobj target")
  }
  inspect(target.file, content="program.lbp")
  inspect(target.entry, content="Main::answer")
}

///|
test "reject runobj target without module-qualified entry" {
  guard parse_runobj_target("program.lbp:answer") is Err(error) else {
    abort("expected runobj target error")
  }
  debug_inspect(
    error,
    content="InvalidRunObjTarget(target=\"program.lbp:answer\")",
  )
  inspect(
    error.render_human(),
    content=(
      #|error[E6008]: invalid runobj target
      #|  = label: expected `FILE:Module.value`, got `program.lbp:answer`
      #|  = note: `lane runobj` loads one linked program artifact and selects a public entry from it
      #|  = help: try: lane runobj program.lbp:Main.main
    ),
  )
}

///|
test "file read diagnostics hide host exception details" {
  let error = CliError::file_io(
    Read,
    "hello",
    "OSError(\"@fs.open(): \\\"hello\\\": No such file or directory\")",
  )
  debug_inspect(
    error,
    content="FileIo(action=Read, path=\"hello\", reason=NotFound)",
  )
  inspect(
    error.render_human(),
    content="error: couldn't read `hello`: No such file or directory",
  )
}

///|
test "file write diagnostics classify permission errors" {
  let error = CliError::file_io(
    Write,
    "/root/out.lmo",
    "OSError(\"@fs.open(): \\\"/root/out.lmo\\\": Permission denied\")",
  )
  debug_inspect(
    error,
    content="FileIo(action=Write, path=\"/root/out.lmo\", reason=PermissionDenied)",
  )
  inspect(
    error.render_human(),
    content="error: couldn't write `/root/out.lmo`: Permission denied",
  )
}

///|
test "file resolve diagnostics hide unclassified host errors" {
  inspect(
    CliError::file_io(Resolve, "input.lane", "OSError(\"opaque host failure\")").render_human(),
    content="error: couldn't resolve `input.lane`: host file operation failed",
  )
}

///|
test "command file diagnostics use command verbs" {
  let error = "OSError(\"@fs.open(): \\\"missing\\\": No such file or directory\")"
  inspect(
    [
      CliError::file_io(Check, "missing.lane", error).render_human(),
      CliError::file_io(Compile, "missing.lane", error).render_human(),
      CliError::file_io(Run, "missing.lane", error).render_human(),
      CliError::file_io(RunObject, "missing.lbp", error).render_human(),
      CliError::file_io(Format, "missing.lane", error).render_human(),
      CliError::file_io(Link, "missing.lmo", error).render_human(),
    ].join("\n"),
    content=(
      #|error: couldn't check `missing.lane`: No such file or directory
      #|error: couldn't compile `missing.lane`: No such file or directory
      #|error: couldn't run `missing.lane`: No such file or directory
      #|error: couldn't run object `missing.lbp`: No such file or directory
      #|error: couldn't format `missing.lane`: No such file or directory
      #|error: couldn't link `missing.lmo`: No such file or directory
    ),
  )
}

///|
test "inspect file diagnostics name the inspect operation" {
  inspect(
    CliError::file_io(
      Inspect,
      "hello",
      "OSError(\"@fs.open(): \\\"hello\\\": No such file or directory\")",
    ).render_human(),
    content="error: couldn't inspect `hello`: No such file or directory",
  )
}

///|
test "default compile artifact path replaces input suffix" {
  inspect(
    default_compile_artifact_path("Main.lane", ".lmi"),
    content="Main.lmi",
  )
  inspect(
    default_compile_artifact_path("src/Main.lane", ".lmo"),
    content="src/Main.lmo",
  )
  inspect(
    default_compile_artifact_path("src/Main.test.lane", ".lmi"),
    content="src/Main.test.lmi",
  )
  inspect(default_compile_artifact_path("Main", ".lmo"), content="Main.lmo")
}

///|
async test "compile writes default module artifacts beside source" {
  let workspace = ".tmp-lane-default-compile-artifacts"
  let source_path = "\{workspace}/Main.lane"
  let interface_path = "\{workspace}/Main.lmi"
  let object_path = "\{workspace}/Main.lmo"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  write_source_file(
    source_path,
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
  )
  let outcome = lane_compile(source_path, [], None, None, false)
  guard outcome is Succeeded else {
    cleanup_library_fixture(workspace)
    abort("expected compile to succeed")
  }
  let interface_bytes = @fs.read_file(interface_path).binary()
  let object_bytes = @fs.read_file(object_path).binary()
  cleanup_library_fixture(workspace)
  inspect(
    byte_prefix_text(interface_bytes, 8),
    content="76,65,78,69,65,82,84,0",
  )
  inspect(byte_prefix_text(object_bytes, 8), content="76,65,78,69,65,82,84,0")
}

///|
async test "native module artifacts are binary and readable" {
  let workspace = ".tmp-lane-binary-artifacts"
  let interface_path = "\{workspace}/Main.lmi"
  let object_path = "\{workspace}/Main.lmo"
  let program_path = "\{workspace}/Main.lbp"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  let compiled = @compile.compile_module_with_interface_artifacts(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else {
    cleanup_library_fixture(workspace)
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    cleanup_library_fixture(workspace)
    abort("expected compiled module")
  }
  write_module_interface_artifact(interface_path, module_)
  write_module_object_artifact(object_path, module_)
  let linked = @compile.link_modules(modules)
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    cleanup_library_fixture(workspace)
    abort("expected linked program")
  }
  write_linked_program_artifact(program_path, program)
  let interface_bytes = @fs.read_file(interface_path).binary()
  let object_bytes = @fs.read_file(object_path).binary()
  let program_bytes = @fs.read_file(program_path).binary()
  inspect(
    byte_prefix_text(interface_bytes, 8),
    content="76,65,78,69,65,82,84,0",
  )
  inspect(byte_prefix_text(object_bytes, 8), content="76,65,78,69,65,82,84,0")
  inspect(byte_prefix_text(program_bytes, 8), content="76,65,78,69,65,82,84,0")
  let interface = match read_module_interface_artifact(interface_path) {
    Ok(artifact) => artifact
    Err(error) => {
      cleanup_library_fixture(workspace)
      abort(error.render_human())
    }
  }
  let object = match read_module_object_artifact(object_path) {
    Ok(artifact) => artifact
    Err(error) => {
      cleanup_library_fixture(workspace)
      abort(error.render_human())
    }
  }
  let linked_program = match read_linked_program_artifact(program_path) {
    Ok(program) => program
    Err(error) => {
      cleanup_library_fixture(workspace)
      abort(error.render_human())
    }
  }
  cleanup_library_fixture(workspace)
  inspect(interface.module_path_text, content="Main")
  inspect(object.module_path_text, content="Main")
  inspect(
    linked_program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
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
test "run handler body block with effectful local binding" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|effect Console {
      #|  read() -> Int
      #|}
      #|pub let answer : Int = {
      #|  handle {
      #|    let x : Int = Console::read!()
      #|    x
      #|  } with {
      #|    Console::read(resume) => resume(42)
      #|  } final value {
      #|    value
      #|  }
      #|}
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
}

///|
test "missing entry error lists available public entries" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub let answer : Int = 42
    ),
  )
  guard find_entry(result.entries, "main") is Err(error) else {
    abort("expected missing entry")
  }
  debug_inspect(
    error,
    content=(
      #|EntryNotFound(
      #|  name="main",
      #|  entries=[{ name: "answer", value: { index: 0 }, type_: Primitive(Int) }],
      #|)
    ),
  )
  inspect(
    error.render_human(),
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
    CliError::Internal(message="callee is not callable").render_human(),
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
    facts: [],
    suggestions: [],
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
    facts: [],
    suggestions: [],
  }
  inspect(denied_diagnostics([warning], false).length(), content="0")
  inspect(denied_diagnostics([warning], true).length(), content="1")
  inspect(denied_diagnostics([error], false).length(), content="1")
}

///|
test "compile diagnostics render source snippets" {
  let source =
    #|module Main
    #|import Builtins.{
    #|  read_int
    #|}
    #|pub let answer : Int = 1
  let root : LaneSourceInput = {
    source_id: "ops.lane",
    path: Some("ops.lane"),
    text: source,
  }
  let result = @compile.check_source_inputs(root.to_compile_input(), [])
  guard result.diagnostics.length() == 1 else {
    abort("expected one missing import diagnostic")
  }
  let sources = LaneSourceInput::diagnostic_sources(root, [])
  inspect(
    render_compile_diagnostic(result.diagnostics[0], sources),
    content=(
      #|error[E4002]: missing imported module `Builtins`
      #|  --> ops.lane:2:8
      #|   |
      #| 2 | import Builtins.{
      #|   |        ^^^^^^^^ no explicit input provides this module
      #|   |
      #|  = note: Lane only compiles explicitly provided source files and interface artifacts
      #|  = considered source module: `Main`
      #|  = help: pass an input whose declared module is `Builtins`, or change the import to one of the listed modules
      #|  = suggestion: check the imported module name against the listed explicit inputs (maybe-incorrect)
    ),
  )
}

///|
test "compile diagnostics convert text offsets before rendering" {
  let source =
    #|module Main
    #|// 中文 before import
    #|import Builtins.{
    #|  read_int
    #|}
    #|pub let answer : Int = 1
  let root : LaneSourceInput = {
    source_id: "unicode.lane",
    path: Some("unicode.lane"),
    text: source,
  }
  let result = @compile.check_source_inputs(root.to_compile_input(), [])
  guard result.diagnostics.length() == 1 else {
    abort("expected one missing import diagnostic")
  }
  let sources = LaneSourceInput::diagnostic_sources(root, [])
  inspect(
    render_compile_diagnostic(result.diagnostics[0], sources),
    content=(
      #|error[E4002]: missing imported module `Builtins`
      #|  --> unicode.lane:3:8
      #|   |
      #| 3 | import Builtins.{
      #|   |        ^^^^^^^^ no explicit input provides this module
      #|   |
      #|  = note: Lane only compiles explicitly provided source files and interface artifacts
      #|  = considered source module: `Main`
      #|  = help: pass an input whose declared module is `Builtins`, or change the import to one of the listed modules
      #|  = suggestion: check the imported module name against the listed explicit inputs (maybe-incorrect)
    ),
  )
}

///|
test "source-less diagnostic labels are preserved as notes" {
  let diagnostic : @compile.CompileDiagnostic = {
    source_id: None,
    message: "source-less error",
    span: None,
    severity: Error,
    code: Some("E9999"),
    labels: [
      {
        span: @basic.SourceSpan::dummy(),
        message: "context without a source file",
        style: Primary,
      },
    ],
    notes: ["ordinary note"],
    helps: ["ordinary help"],
    facts: [],
    suggestions: [],
  }
  inspect(
    render_compile_diagnostic(diagnostic, DiagnosticSources()),
    content=(
      #|error[E9999]: source-less error
      #|  = note: context without a source file
      #|  = note: ordinary note
      #|  = help: ordinary help
    ),
  )
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
  guard read_library_source_inputs(root, [lib], [workspace]) is Ok(sources) else {
    cleanup_library_fixture(workspace)
    abort("expected normalized library sources")
  }
  cleanup_library_fixture(workspace)
  inspect(sources.length(), content="1")
  inspect(sources[0].text, content="lib")
  inspect(sources[0].source_id, content=".tmp-lane-library-sources/Lib.lane")
  debug_inspect(
    sources[0].path,
    content="Some(\".tmp-lane-library-sources/Lib.lane\")",
  )
}

///|
async test "explicit lib cannot be the root source" {
  let workspace = ".tmp-lane-root-lib"
  let root = "\{workspace}/Main.lane"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  @fs.write_file(root, "root", create_mode=CreateOrTruncate)
  guard read_library_source_inputs(root, [root], []) is Err(error) else {
    cleanup_library_fixture(workspace)
    abort("expected explicit root library error")
  }
  cleanup_library_fixture(workspace)
  debug_inspect(
    error,
    content=(
      #|RootLibraryInput(
      #|  root=".tmp-lane-root-lib/Main.lane",
      #|  library=".tmp-lane-root-lib/Main.lane",
      #|)
    ),
  )
  inspect(
    error.render_human(),
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
  guard read_library_source_inputs(root, [lib_alias, lib], []) is Ok(sources) else {
    cleanup_library_fixture(workspace)
    abort("expected symlinked duplicate library to be deduped")
  }
  cleanup_library_fixture(workspace)
  inspect(sources.length(), content="1")
  inspect(sources[0].text, content="lib")
  inspect(
    sources[0].source_id,
    content=".tmp-lane-library-symlinks/LibAlias.lane",
  )
}

///|
async fn cleanup_library_fixture(workspace : String) -> Unit {
  @fs.rmdir(workspace, recursive=true) catch {
    _ => ()
  }
}

///|
fn byte_prefix_text(bytes : Bytes, count : Int) -> String {
  let values = []
  let length = if bytes.length() < count { bytes.length() } else { count }
  for index in 0..<length {
    values.push(bytes[index].to_int().to_string())
  }
  values.join(",")
}
