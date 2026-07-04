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
      #|error[E6002]: invalid run target `examples/main.lane`
      #|  expected: FILE:ENTRY
      #|
      #|`lane run` compiles one source file and then selects a public entry from it.
      #|
      #|Example:
      #|  lane run Main.lane:main
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
      #|error[E6008]: invalid runobj target `program.lbp:answer`
      #|  expected: FILE:Module.value
      #|
      #|`lane runobj` loads one linked program artifact and selects a public entry from it.
      #|
      #|Example:
      #|  lane runobj program.lbp:Main.main
    ),
  )
}

///|
test "basic command parser diagnostics render as command reports" {
  inspect(
    [
      InvalidCommand(message="invalid option `--wat`").render_human(),
      UnknownCommand.render_human(),
      MissingArgument(name="file").render_human(),
    ].join("\n---\n"),
    content=(
      #|error[E6000]: invalid lane command line
      #|  parser message: invalid option `--wat`
      #|
      #|This is a CLI usage error, not a Lane source error.
      #|
      #|Run `lane --help` or `lane <command> --help` to see valid forms.
      #|---
      #|error[E6001]: unknown lane command
      #|The requested subcommand is not supported by this `lane` binary.
      #|Available commands include check, run, compile, inspect, link, runobj, fmt, and lsp.
      #|
      #|Example:
      #|  lane check Main.lane
      #|---
      #|error[E6003]: missing required CLI argument `file`
      #|This is a CLI usage error, not a Lane source error.
      #|
      #|Run `lane --help` or `lane <command> --help` to see the required arguments.
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
test "artifact load diagnostics render as command reports" {
  inspect(
    ArtifactLoad(
      path="main.lmo",
      kind="module object artifact",
      message="invalid artifact header",
    ).render_human(),
    content=(
      #|error: couldn't load module object artifact `main.lmo`
      #|  reason: invalid artifact header
    ),
  )
}

///|
test "duplicate object diagnostics render as command reports" {
  inspect(
    DuplicateObjectArtifact(module_path_text="Main").render_human(),
    content=(
      #|error[E6007]: duplicate module object artifact
      #|  module: Main
      #|
      #|Each module in a link input set must come from exactly one object artifact.
      #|
      #|Remove the duplicate object path and run `lane link` again.
    ),
  )
}

///|
test "format diagnostics render through source-aware reports" {
  let source = "module Test\npub let answer : ="
  guard @format.format_source(source) is Err(diagnostics) else {
    abort("expected format diagnostics")
  }
  let sources = CompilerDiagnosticSources()
  sources.add("Main.lane", source, Some("Main.lane"))
  let diagnostics = diagnostics.map(fn(diagnostic) {
    diagnostic.with_source_id("Main.lane")
  })
  inspect(
    [
      NotFormatted(path="Main.lane").render_human(),
      render_compile_diagnostic(diagnostics[0], sources),
    ].join("\n---\n"),
    content=(
      #|error: Main.lane: not formatted
      #|---
      #|error[E1100]: unexpected token
      #|  --> Main.lane:2:18
      #|   |
      #| 2 | pub let answer : =
      #|   |                  ^ the parser did not expect `=`
      #|   |
      #|  = note: expected one of: identifier, `type`, `(`, `[`
      #|  = help: rewrite this position so it starts with one of: identifier, `type`, `(`, `[`
    ),
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
async test "runobj executes explicit Stdlib Io linked input" {
  let workspace = ".tmp-lane-runobj-stdlib-io"
  let stdlib_source = "\{workspace}/io.lane"
  let stdlib_interface = "\{workspace}/io.lmi"
  let stdlib_object = "\{workspace}/io.lmo"
  let main_source = "\{workspace}/Main.lane"
  let main_object = "\{workspace}/Main.lmo"
  let program_path = "\{workspace}/program.lbp"
  cleanup_library_fixture(workspace)
  @fs.mkdir(workspace)
  write_source_file(
    stdlib_source,
    (
      #|module Stdlib.Io
      #|pub effect Write {
      #|  println(String) -> Unit
      #|}
      #|pub type Console = { Write }
      #|pub type Io = { Console }
    ),
  )
  write_source_file(
    main_source,
    (
      #|module Main
      #|import Stdlib.Io.*
      #|pub fn main() -> Unit ! Io {
      #|  Write::println!("hello")
      #|}
    ),
  )
  guard lane_compile(
      stdlib_source,
      [],
      Some(stdlib_interface),
      Some(stdlib_object),
      false,
    )
    is Succeeded else {
    cleanup_library_fixture(workspace)
    abort("expected stdlib compile to succeed")
  }
  guard lane_compile(
      main_source,
      [stdlib_interface],
      None,
      Some(main_object),
      false,
    )
    is Succeeded else {
    cleanup_library_fixture(workspace)
    abort("expected main compile to succeed")
  }
  guard lane_link([main_object, stdlib_object], program_path, false)
    is Succeeded else {
    cleanup_library_fixture(workspace)
    abort("expected link to succeed")
  }
  let linked_program = match read_linked_program_artifact(program_path) {
    Ok(program) => program
    Err(error) => {
      cleanup_library_fixture(workspace)
      abort(error.render_human())
    }
  }
  let entry = find_entry(linked_program.entries, "Main::main")
  guard entry is Ok(entry) else {
    cleanup_library_fixture(workspace)
    abort("expected linked main entry")
  }
  let output : Array[String] = []
  guard execute_entry_with_output(
      linked_program.program,
      linked_program.externals,
      linked_program.runtime_effect_operations,
      entry,
      line => output.push(line),
    )
    is Succeeded else {
    cleanup_library_fixture(workspace)
    abort("expected runobj to succeed")
  }
  cleanup_library_fixture(workspace)
  inspect(output.join("\n"), content="hello")
}

///|
test "run rejects public value entries" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub let answer : Int = 42
      #|let hidden : Int = 1
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  let entry = find_entry(result.entries, "answer")
  guard entry is Ok(entry) else { abort("expected entry") }
  debug_inspect(
    validate_executable_entry(entry, []),
    content=(
      #|Err(
      #|  EntryNotExecutable(
      #|    name="answer",
      #|    type_=Primitive(Int),
      #|    reason=EntryIsNotFunction,
      #|  ),
      #|)
    ),
  )
}

///|
test "run rejects functions with parameters" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub fn id(x : Int) -> Int { x }
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  let entry = find_entry(result.entries, "id")
  guard entry is Ok(entry) else { abort("expected entry") }
  debug_inspect(
    validate_executable_entry(entry, []),
    content=(
      #|Err(
      #|  EntryNotExecutable(
      #|    name="id",
      #|    type_=Function([Primitive(Int)], Primitive(Int), Empty),
      #|    reason=EntryHasParameters(count=1),
      #|  ),
      #|)
    ),
  )
}

///|
test "run executes pure unit function entries without rendering Unit" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub fn main() -> Unit {
      #|  ()
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let entry = find_entry(result.entries, "main")
  guard entry is Ok(entry) else { abort("expected entry") }
  let outcome = execute_entry(
    program,
    result.externals,
    result.runtime_effect_operations,
    entry,
  )
  guard outcome is Succeeded else { abort("expected run entry to succeed") }
}

///|
test "run accepts Stdlib Io effect aliases when supplied explicitly" {
  let stdlib_io =
    #|module Stdlib.Io
    #|pub effect Write {
    #|  println(String) -> Unit
    #|}
    #|pub type Console = { Write }
    #|pub type Io = { Console }
  let result = @compile.compile_sources(
    (
      #|module Test
      #|import Stdlib.Io.*
      #|pub fn main() -> Unit ! Io {
      #|  Write::println!("hello")
      #|}
    ),
    [stdlib_io],
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let entry = find_entry(result.entries, "main")
  guard entry is Ok(entry) else { abort("expected entry") }
  let runtime_effects = command_runtime_effects(
    program,
    result.runtime_effect_operations,
  )
  debug_inspect(
    validate_executable_entry(entry, runtime_effects),
    content="Ok(())",
  )
}

///|
test "run rejects Stdlib Io effect without explicit runtime metadata" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub effect Write {
      #|  println(String) -> Unit
      #|}
      #|pub fn main() -> Unit ! Write {
      #|  Write::println!("hello")
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.program is Some(program) else { abort("expected program") }
  let entry = find_entry(result.entries, "main")
  guard entry is Ok(entry) else { abort("expected entry") }
  debug_inspect(
    validate_executable_entry(
      entry,
      command_runtime_effects(program, result.runtime_effect_operations),
    ),
    content=(
      #|Err(
      #|  EntryNotExecutable(
      #|    name="main",
      #|    type_=Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|    reason=EntryHasUnsupportedEffects(effect=Singleton({ index: 0 }, [])),
      #|  ),
      #|)
    ),
  )
  guard validate_executable_entry(
      entry,
      command_runtime_effects(program, result.runtime_effect_operations),
    )
    is Err(error) else {
    abort("expected unsupported effect diagnostic")
  }
  inspect(
    error.render_human(),
    content=(
      #|error[E6009]: entry `main` is not executable
      #|  requested type: () -> Unit ! effect#0
      #|  expected: () -> Unit, or supported runtime effects such as Stdlib.Io.Write
      #|
      #|The selected function has unsupported effect set `effect#0`.
      #|
      #|Export a `pub fn main() -> Unit` entry.
      #|Use `lane inspect <artifact>` to inspect public entries and artifact metadata.
    ),
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
      #|error[E6005]: entry `main` was not found
      #|  available public entries: answer
      #|
      #|Use one of the listed public entries, or export the value with `pub` before compiling.
    ),
  )
}

///|
test "ambiguous entry error lists available public entries" {
  let result = @compile.compile_source(
    (
      #|module Test
      #|pub let answer : Int = 42
    ),
  )
  let entry = result.entries[0]
  guard find_entry([entry, entry], "answer") is Err(error) else {
    abort("expected ambiguous entry")
  }
  inspect(
    error.render_human(),
    content=(
      #|error[E6006]: entry name `answer` is ambiguous
      #|  available public entries: answer, answer
      #|
      #|Qualify the requested entry with its module path when possible.
    ),
  )
}

///|
test "internal compiler error is marked as a compiler bug" {
  inspect(
    CliError::Internal(message="callee is not callable").render_human(),
    content=(
      #|error[E6200]: internal Lane compiler/runtime error
      #|  invariant: callee is not callable
      #|
      #|This is not expected after a successful Lane typecheck.
      #|
      #|Please file a compiler bug with the source file, command, and this diagnostic.
    ),
  )
}

///|
test "check deny controls warning failures" {
  let warning : @compiler_diag.CompilerDiagnostic = {
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
  let error : @compiler_diag.CompilerDiagnostic = {
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
test "semantic diagnostics render source snippets" {
  let source =
    #|module Main
    #|struct Point {
    #|  x : Int
    #|  y : Int
    #|}
    #|pub let point : Point = Point::{ x: 1 }
  let root : LaneSourceInput = {
    source_id: "point.lane",
    path: Some("point.lane"),
    text: source,
  }
  let result = @compile.check_source_inputs(root.to_compile_input(), [])
  guard result.diagnostics.length() == 1 else {
    abort("expected one missing field diagnostic")
  }
  let sources = LaneSourceInput::diagnostic_sources(root, [])
  inspect(
    render_compile_diagnostic(result.diagnostics[0], sources),
    content=(
      #|error[E3101]: missing field `y`
      #|  --> point.lane:6:34
      #|   |
      #| 6 | pub let point : Point = Point::{ x: 1 }
      #|   |                                  ^^^^^^ this struct construction or pattern omits required field `y`
      #|   |
      #|  = note: Lane struct literals and struct patterns must account for required fields
      #|  = help: add a `y: ...` field entry
      #|  = suggestion: add a `y: ...` field entry (has-placeholders)
    ),
  )
}

///|
test "source-less diagnostic labels are preserved as notes" {
  let diagnostic : @compiler_diag.CompilerDiagnostic = {
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
    render_compile_diagnostic(diagnostic, CompilerDiagnosticSources()),
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
      #|  root: .tmp-lane-root-lib/Main.lane
      #|  library: .tmp-lane-root-lib/Main.lane
      #|
      #|`lane check` and `lane run` compile the root source separately from library inputs.
      #|`--lib-dir` discovery silently skips the root source, but explicit `--lib` keeps mistakes visible.
      #|
      #|Remove the duplicate `--lib .tmp-lane-root-lib/Main.lane` argument.
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
