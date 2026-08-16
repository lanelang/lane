///|
fn test_executable_program(
  program : @module_link.LinkedProgram,
) -> @executable.ExecutableProgram {
  match
    @executable.elaborate(
      program,
      program.entries[0],
      @executable.ExecutionProfile::new(
        builtin_effects=[Io, Panic],
        supports_external_effects=true,
      ),
    ) {
    Ok(executable) => executable
    Err(error) =>
      abort("unexpected executable elaboration error: \{Repr(error)}")
  }
}

///|
test "module artifacts roundtrip through binary, link, and bytecode" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub fn main() -> Unit {
      #|  answer()
      #|}
    ),
    [
      (
        #|module Lib
        #|let host_answer : () -> Unit = extern("lane.test.answer")
        #|pub fn answer() -> Unit {
        #|  host_answer()
        #|}
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let decoded_modules : Array[@artifact.CompiledModuleArtifact] = []
  for module_ in artifact.modules {
    let interface_binary = @artifact.module_interface_artifact_to_binary(
      module_.interface,
    )
    let object_binary = @artifact.module_object_artifact_to_binary(
      module_.object,
    )
    let interface = match
      @artifact.parse_module_interface_artifact_binary(interface_binary) {
      Ok(interface) => interface
      Err(message) => abort(message)
    }
    let object = match
      @artifact.parse_module_object_artifact_binary(object_binary) {
      Ok(object) => object
      Err(message) => abort(message)
    }
    decoded_modules.push({
      schema_version: module_.schema_version,
      interface,
      object,
    })
  }
  let linked = @artifact.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: decoded_modules,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  debug_inspect(
    (
      program.externals.builtins.map(fn(external) {
        external.intrinsic().name()
      }),
      program.externals.runtime_imports.map(fn(import_) { import_.symbol }),
    ),
    content=(
      #|([], ["lane.test.answer"])
    ),
  )
  let executable = test_executable_program(program)
  let linked_artifact = match
    @artifact.executable_to_loisvm_artifact(executable) {
    Ok(artifact) => artifact
    Err(error) => abort("unexpected LoisVM lowering error: \{Repr(error)}")
  }
  let runtime_imports = linked_artifact.bytecode.functions.filter_map(fn(
    function,
  ) {
    match function {
      RuntimeImport(import_) => Some(import_)
      BytecodeBody(_) => None
    }
  })
  debug_inspect(
    runtime_imports,
    content=(
      #|[
      #|  {
      #|    abi_major: 1,
      #|    parameters: [],
      #|    result: Unit,
      #|    symbol: "lane.test.answer",
      #|  },
      #|]
    ),
  )
  let linked_binary = @artifact.linked_program_artifact_to_binary(
    linked_artifact,
  ).unwrap()
  inspect(byte_prefix_text(linked_binary, 8), content="76,65,78,69,65,82,84,0")
  let linked_decoded = match
    @artifact.parse_linked_program_artifact_binary(linked_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  assert_eq(linked_decoded, linked_artifact)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "effect aliases export through interface artifacts" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub fn program() -> Unit ! UI {
      #|  let ignored : I64 = Console::read!()
      #|  Log::write!("ok")
      #|}
    ),
    [
      (
        #|module Lib
        #|pub effect Console {
        #|  read() -> I64
        #|}
        #|pub effect Log {
        #|  write(String) -> Unit
        #|}
        #|pub type UI = { Console, Log }
      ),
    ],
  )
  debug_inspect(
    compiled.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 63,
      #|          end_offset: 70,
      #|          start_line: 4,
      #|          start_column: 7,
      #|          end_line: 4,
      #|          end_column: 14,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 63,
      #|            end_offset: 70,
      #|            start_line: 4,
      #|            start_column: 7,
      #|            end_line: 4,
      #|            end_column: 14,
      #|          },
      #|        ),
      #|        message: "`ignored` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Lib")
    is Some(lib) else {
    abort("expected Lib")
  }
  let lib_artifact = lib.to_artifact()
  inspect(
    interface_alias_signatures(lib_artifact.interface.interface),
    content=(
      #|UI[]:Effect=effect:{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
  let interface_binary = @artifact.module_interface_artifact_to_binary(
    lib_artifact.interface,
  )
  let decoded_binary = match
    @artifact.parse_module_interface_artifact_binary(interface_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  assert_eq(decoded_binary, lib_artifact.interface)
  inspect(
    interface_alias_signatures(decoded_binary.interface),
    content=(
      #|UI[]:Effect=effect:{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
  let inspect_text = match
    @artifact.artifact_binary_to_inspect_text(interface_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(inspect_text),
    content=(
      #|Lane interface artifact
      #|module: Lib
      #|schema: 14
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|interface Lib:
      #|types:
      #|  (none)
      #|effects:
      #|  pub effect Console { read() -> I64 }
      #|  pub effect Log { write(String) -> Unit }
      #|type aliases:
      #|  pub type UI : Effect = { Console, Log }
      #|values:
      #|  (none)
      #|
    ),
  )
}

///|
test "built-in Io roundtrips through typed artifacts" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|pub let println : (String) -> Unit ! Io = extern("println")
      #|pub fn run(action : () -> Unit ! Io) -> Unit ! Io {
      #|  action()
      #|}
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifacts = modules.to_artifact()
  let module_ = artifacts.modules[0]
  let interface_binary = @artifact.module_interface_artifact_to_binary(
    module_.interface,
  )
  let decoded_interface = match
    @artifact.parse_module_interface_artifact_binary(interface_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  let object_binary = @artifact.module_object_artifact_to_binary(module_.object)
  let decoded_object = match
    @artifact.parse_module_object_artifact_binary(object_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  debug_inspect(decoded_object == module_.object, content="true")
  inspect(
    decoded_interface.interface.values
    .map(value => {
      value.name + ": " + @prettyprinter.render(value.type_, width=100)
    })
    .join("\n"),
    content=(
      #|println: (String) -> Unit ! Io
      #|run: (() -> Unit ! Io) -> Unit ! Io
    ),
  )
  let object_text = match
    @artifact.artifact_binary_to_inspect_text(object_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(object_text),
    content=(
      #|Lane object artifact
      #|module: Main
      #|schema: 21
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|object:
      #|imports:
      #|  (none)
      #|exports:
      #|  value println
      #|  value run
      #|public entries:
      #|  Main.println : (String) -> Unit ! Io
      #|  Main.run : (() -> Unit ! Io) -> Unit ! Io
      #|compiler intrinsics:
      #|  (none)
      #|runtime imports:
      #|  println : (String) -> Unit ! Io
      #|buslane:
      #|  buslane {
      #|    metadata {
      #|      next_unique#4;
      #|      value value#0 = "println"#0 value : (String) -> Unit ! Io;
      #|      value value#1 = "run"#1 function : (() -> Unit ! Io) -> Unit ! Io;
      #|      value value#2 = "action"#2 parameter : () -> Unit ! Io;
      #|      value value#3 = "println"#3 external : (String) -> Unit ! Io;
      #|    }
      #|    external value#3
      #|    letrec {
      #|      value#1 = fn(value#2) -> Unit {
      #|        value#2()
      #|      }
      #|    }
      #|    let value#0 = value#3
      #|  }
      #|
    ),
  )
}

///|
test "Panic and Bytes intrinsics roundtrip through object artifacts" {
  let compiled = compile_modules_for_test(
    (
      #|module Basic.Data.Void
      #|pub enum Void {}
      #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
      #|pub let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|pub let bytes_set : (Bytes, I64, Byte) -> Bytes = builtin("%bytes_set")
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) &&
    modules.to_artifact().modules is [module_] else {
    fail("expected one compiled module artifact")
  }
  let binary = @artifact.module_object_artifact_to_binary(module_.object)
  let decoded = match @artifact.parse_module_object_artifact_binary(binary) {
    Ok(object) => object
    Err(message) => fail(message)
  }
  assert_eq(decoded, module_.object)
}

///|
test "external flavors roundtrip through artifacts and linking" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub fn use(fd : Fd) -> I64 ! VectorOp[I64] {
      #|  read(fd)
      #|}
    ),
    [
      (
        #|module Lib
        #|pub extern type Fd : Type
        #|pub extern type VectorOp[A : Type] : Effect
        #|pub let read : (Fd) -> I64 ! VectorOp[I64] = extern("vector.read")
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  guard find_artifact_module(artifact.modules, "Lib") is Some(lib) else {
    abort("expected Lib artifact")
  }
  let interface_binary = @artifact.module_interface_artifact_to_binary(
    lib.interface,
  )
  let decoded_interface = match
    @artifact.parse_module_interface_artifact_binary(interface_binary) {
    Ok(interface) => interface
    Err(message) => abort(message)
  }
  let object_binary = @artifact.module_object_artifact_to_binary(lib.object)
  let decoded_object = match
    @artifact.parse_module_object_artifact_binary(object_binary) {
    Ok(object) => object
    Err(message) => abort(message)
  }
  assert_eq(decoded_interface, lib.interface)
  assert_eq(decoded_object, lib.object)
  let interface_text = match
    @artifact.artifact_binary_to_inspect_text(interface_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(interface_text),
    content=(
      #|Lane interface artifact
      #|module: Lib
      #|schema: 14
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|interface Lib:
      #|types:
      #|  pub extern type Fd : Type
      #|effects:
      #|  pub extern type VectorOp[A : Type] : Effect
      #|type aliases:
      #|  (none)
      #|values:
      #|  pub let read : (Fd) -> I64 ! VectorOp[I64]
      #|
    ),
  )
  let linked = @artifact.link_module_artifacts(artifact)
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  debug_inspect(
    (
      program.program.metadata.types.map(info => {
        (info.name.occurrence, info.flavor)
      }),
      program.program.metadata.effects.map(info => {
        (info.name.occurrence, info.flavor)
      }),
    ),
    content=(
      #|([("Fd", External)], [("VectorOp", External)])
    ),
  )
}

///|
test "effect alias interface fingerprint tracks body changes" {
  let first_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub effect Console {
      #|  read() -> I64
      #|}
      #|pub effect Log {
      #|  write(String) -> Unit
      #|}
      #|pub type UI = { Console }
    ),
    [],
  )
  let second_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub effect Console {
      #|  read() -> I64
      #|}
      #|pub effect Log {
      #|  write(String) -> Unit
      #|}
      #|pub type UI = { Console, Log }
    ),
    [],
  )
  guard first_compiled.modules is Some(first_modules) else {
    abort("expected first modules")
  }
  guard second_compiled.modules is Some(second_modules) else {
    abort("expected second modules")
  }
  guard first_modules.modules.get(0) is Some(first_module) else {
    abort("expected first module")
  }
  guard second_modules.modules.get(0) is Some(second_module) else {
    abort("expected second module")
  }
  inspect(
    first_module.to_artifact().interface.interface_fingerprint ==
    second_module.to_artifact().interface.interface_fingerprint,
    content="false",
  )
}

///|
test "interface fingerprint ignores imported symbol allocation history" {
  let plain_a = compile_modules_for_test(
    (
      #|module A
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub effect Signal {
      #|  emit() -> Unit
      #|}
    ),
    [],
  )
  guard plain_a.modules is Some(plain_a_modules) else {
    abort("expected plain A modules")
  }
  guard plain_a_modules.modules.get(0) is Some(plain_a_module) else {
    abort("expected plain A module")
  }
  let noise = compile_modules_for_test(
    (
      #|module Noise
      #|pub struct Marker {
      #|  value : I64
      #|}
      #|pub effect MarkerEffect {
      #|  mark() -> Unit
      #|}
    ),
    [],
  )
  guard noise.modules is Some(noise_modules) else {
    abort("expected Noise modules")
  }
  guard noise_modules.modules.get(0) is Some(noise_module) else {
    abort("expected Noise module")
  }
  let noise_interface = noise_module.to_interface_artifact()
  let shifted_a = compile_module_with_interfaces_for_test(
    (
      #|module A
      #|import Noise.*
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub effect Signal {
      #|  emit() -> Unit
      #|}
    ),
    [noise_interface],
  )
  guard shifted_a.modules is Some(shifted_a_modules) else {
    abort("expected shifted A modules")
  }
  guard shifted_a_modules.modules.get(0) is Some(shifted_a_module) else {
    abort("expected shifted A module")
  }
  let plain_b = compile_module_with_interfaces_for_test(
    (
      #|module B
      #|import A.*
      #|pub type Signals = { Signal }
      #|pub let forwarded : Box = Box::{ value: 42 }
    ),
    [plain_a_module.to_interface_artifact()],
  )
  guard plain_b.modules is Some(plain_b_modules) else {
    abort("expected plain B modules")
  }
  guard plain_b_modules.modules.get(0) is Some(plain_b_module) else {
    abort("expected plain B module")
  }
  let shifted_b = compile_module_with_interfaces_for_test(
    (
      #|module B
      #|import A.*
      #|pub type Signals = { Signal }
      #|pub let forwarded : Box = Box::{ value: 42 }
    ),
    [noise_interface, shifted_a_module.to_interface_artifact()],
  )
  guard shifted_b.modules is Some(shifted_b_modules) else {
    abort("expected shifted B modules")
  }
  guard shifted_b_modules.modules.get(0) is Some(shifted_b_module) else {
    abort("expected shifted B module")
  }
  inspect(
    plain_b_module.object.interface_fingerprint ==
    shifted_b_module.object.interface_fingerprint,
    content="true",
  )
  let transitive = compile_module_with_interfaces_for_test(
    (
      #|module C
      #|import B.*
      #|pub let answer : I64 = forwarded.value
    ),
    [
      noise_interface,
      shifted_a_module.to_interface_artifact(),
      shifted_b_module.to_interface_artifact(),
    ],
  )
  debug_inspect(transitive.diagnostics, content="[]")
}

///|
test "interface artifact rejects unresolved canonical references" {
  let compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  guard compiled.modules is Some(modules) else { abort("expected Lib modules") }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected Lib module")
  }
  let artifact = module_.to_interface_artifact()
  let damaged : @artifact.ModuleInterfaceArtifact = {
    ..artifact,
    interface: { ..artifact.interface, type_references: [] },
  }
  let result = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = box.value
    ),
    [damaged],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content="[\"invalid module interface artifact\"]",
  )
}

///|
test "module artifact binary rejects wrong kind" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|pub fn main() -> Unit {
      #|  ()
      #|}
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let object_binary = @artifact.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  inspect(byte_prefix_text(object_binary, 8), content="76,65,78,69,65,82,84,0")
  if @artifact.parse_module_interface_artifact_binary(object_binary)
    is Err(message) {
    inspect(
      message,
      content="wrong artifact binary kind: expected interface, got object",
    )
  } else {
    abort("expected wrong artifact binary kind")
  }
  let invalid_magic = object_binary.to_array()
  invalid_magic[0] = b'X'
  if @artifact.parse_module_object_artifact_binary(
      Bytes::from_array(invalid_magic),
    )
    is Err(message) {
    inspect(
      message,
      content="invalid artifact binary: expected Lane artifact magic at byte 0",
    )
  } else {
    abort("expected invalid artifact magic")
  }
  let linked = link_modules_for_test(modules)
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  let artifact = match
    @artifact.executable_to_loisvm_artifact(test_executable_program(program)) {
    Ok(artifact) => artifact
    Err(error) => abort("unexpected LoisVM lowering error: \{Repr(error)}")
  }
  let program_binary = @artifact.linked_program_artifact_to_binary(artifact).unwrap()
  if @artifact.parse_module_object_artifact_binary(program_binary)
    is Err(message) {
    inspect(
      message,
      content="wrong artifact binary kind: expected object, got program",
    )
  } else {
    abort("expected program binary to fail object parsing")
  }
}

///|
test "missing import with mismatched interface artifact reports candidates" {
  let provider = compile_modules_for_test(
    (
      #|module builtins
      #|pub let read_int : I64 = 0
    ),
    [],
  )
  debug_inspect(provider.diagnostics, content="[]")
  guard provider.modules is Some(provider_modules) else {
    abort("expected provider modules")
  }
  guard provider_modules.modules.get(0) is Some(provider_module) else {
    abort("expected provider module")
  }
  let compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Builtins.*
      #|pub let answer : I64 = read_int
    ),
    [provider_module.to_interface_artifact()],
  )
  guard compiled.diagnostics.get(0) is Some(diagnostic) else {
    abort("expected missing import diagnostic")
  }
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "missing imported module `Builtins`",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 19,
      #|        end_offset: 27,
      #|        start_line: 2,
      #|        start_column: 8,
      #|        end_line: 2,
      #|        end_column: 16,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E4002"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 19,
      #|          end_offset: 27,
      #|          start_line: 2,
      #|          start_column: 8,
      #|          end_line: 2,
      #|          end_column: 16,
      #|        },
      #|      ),
      #|      message: "no explicit input provides this module",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane only compiles explicitly provided source files and interface artifacts"],
      #|  helps: ["pass an input whose declared module is `Builtins`, or change the import to one of the listed modules"],
      #|  facts: [
      #|    {
      #|      name: "considered interface artifact",
      #|      value: "declares module `builtins`",
      #|      span: None,
      #|    },
      #|  ],
      #|  suggestions: [
      #|    {
      #|      message: "check the imported module name against the listed explicit inputs",
      #|      edits: [],
      #|      applicability: MaybeIncorrect,
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "module artifact binary inspect renders human readable summaries" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|pub let answer : I64 = 42
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let interface_binary = @artifact.module_interface_artifact_to_binary(
    module_.to_interface_artifact(),
  )
  let object_binary = @artifact.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  let interface_text = match
    @artifact.artifact_binary_to_inspect_text(interface_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  let object_text = match
    @artifact.artifact_binary_to_inspect_text(object_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(interface_text),
    content=(
      #|Lane interface artifact
      #|module: Main
      #|schema: 14
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|interface Main:
      #|types:
      #|  (none)
      #|effects:
      #|  (none)
      #|type aliases:
      #|  (none)
      #|values:
      #|  pub let answer : I64
      #|
    ),
  )
  inspect(
    artifact_inspect_without_fingerprints(object_text),
    content=(
      #|Lane object artifact
      #|module: Main
      #|schema: 21
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|object:
      #|imports:
      #|  (none)
      #|exports:
      #|  value answer
      #|public entries:
      #|  Main.answer : I64
      #|compiler intrinsics:
      #|  (none)
      #|runtime imports:
      #|  (none)
      #|buslane:
      #|  buslane {
      #|    metadata {
      #|      next_unique#1;
      #|      value value#0 = "answer"#0 value : I64;
      #|    }
      #|    let value#0 = 42
      #|  }
      #|
    ),
  )
}

///|
test "duplicate imported top-level value from interface artifact reports artifact origin" {
  let lib_modules = compile_modules_for_test(
    (
      #|module Lib
      #|pub let answer : I64 = 1
    ),
    [],
  )
  guard lib_modules.modules is Some(modules) else {
    abort("expected Lib module")
  }
  guard modules.modules.get(0) is Some(lib_module) else {
    abort("expected compiled Lib module")
  }
  let result = check_source_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = 2
    ),
    [lib_module.to_artifact().interface],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) {
      (diagnostic.message, diagnostic.labels.length(), diagnostic.notes)
    }),
    content=(
      #|[
      #|  (
      #|    "conflicting top-level value `answer`",
      #|    1,
      #|    [
      #|      "a Lane module has one top-level value namespace",
      #|      "previous definition comes from module `Lib`",
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "compile module interface preserves public effects across artifact import" {
  let lib_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|pub let value : I64 = 42
    ),
    [],
  )
  debug_inspect(lib_compiled.diagnostics, content="[]")
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let interface_binary = @artifact.module_interface_artifact_to_binary(
    lib_artifact.interface,
  )
  let decoded = match
    @artifact.parse_module_interface_artifact_binary(interface_binary) {
    Ok(interface) => interface
    Err(message) => abort(message)
  }
  inspect(
    interface_effect_signatures(decoded.interface),
    content="State[1]{get/0->tparam#0,put/1->Unit}",
  )
  let main_compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.{State}
      #|pub type IntState = { State[I64] }
      #|pub let answer : I64 = 42
    ),
    [lib_artifact.interface],
  )
  debug_inspect(main_compiled.diagnostics, content="[]")
}

///|
fn interface_effect_signatures(
  interface : @module_interface.ModuleInterface,
) -> String {
  interface.effects
  .map(fn(effect) {
    let operations = effect.operations
      .map(fn(operation) {
        let result = @prettyprinter.render(operation.result.pretty(), width=100)
        "\{operation.name}/\{operation.payload.length()}->\{result}"
      })
      .join(",")
    "\{effect.name}[\{effect.type_parameters.length()}]{\{operations}}"
  })
  .join(";")
}

///|
fn interface_alias_signatures(
  interface : @module_interface.ModuleInterface,
) -> String {
  interface.type_aliases
  .map(fn(alias_) {
    let parameters = alias_.type_parameters
      .map(fn(parameter) {
        "\{parameter.name}:\{@prettyprinter.render(parameter.kind, width=100)}"
      })
      .join(",")
    "\{alias_.name}[\{parameters}]:\{@prettyprinter.render(alias_.kind, width=100)}=\{interface_alias_body_signature(alias_.body)}"
  })
  .join(";")
}

///|
fn interface_alias_body_signature(
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> String {
  match body {
    TypeBody(type_) => "type:" + @prettyprinter.render(type_, width=100)
    EffectBody(effect) => "effect:" + @prettyprinter.render(effect, width=100)
  }
}

///|
test "module binaries reject immediately preceding schema versions" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|pub let answer : I64 = 42
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let interface_bytes = @artifact.module_interface_artifact_to_binary(
    module_.to_interface_artifact(),
  ).to_array()
  interface_bytes[14] = b'\x0D'
  interface_bytes[15] = b'\x00'
  interface_bytes[16] = b'\x00'
  interface_bytes[17] = b'\x00'
  let object_bytes = @artifact.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  ).to_array()
  object_bytes[14] = b'\x14'
  object_bytes[15] = b'\x00'
  object_bytes[16] = b'\x00'
  object_bytes[17] = b'\x00'
  let messages = []
  match
    @artifact.parse_module_interface_artifact_binary(
      Bytes::from_array(interface_bytes),
    ) {
    Err(message) => messages.push(message)
    Ok(_) => fail("expected old interface schema failure")
  }
  match
    @artifact.parse_module_object_artifact_binary(
      Bytes::from_array(object_bytes),
    ) {
    Err(message) => messages.push(message)
    Ok(_) => fail("expected old object schema failure")
  }
  assert_eq(messages, [
    "unsupported interface artifact schema version 13", "unsupported object artifact schema version 20",
  ])
}

///|
test "link module artifacts orders reachable modules by imports" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  guard find_artifact_module(artifact.modules, "Main") is Some(main) else {
    abort("expected Main artifact")
  }
  guard find_artifact_module(artifact.modules, "Lib") is Some(lib) else {
    abort("expected Lib artifact")
  }
  let linked = @artifact.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: "Main",
    modules: [main, lib],
    reachable_module_path_texts: ["Main", "Lib"],
  })
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    @prettyprinter.render(program.program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    next_unique#2;
      #|    value value#0 = "value"#0 value : I64;
      #|    value value#1 = "answer"#1 value : I64;
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
}

///|
test "tuple signatures use safe nominal artifact presentation" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Basic.Data.Tuple
      #|pub fn pair(value : (I64, Bool)) -> (I64, Bool) {
      #|  value
      #|}
    ),
    [
      (
        #|module Basic.Data.Tuple
        #|pub enum Tuple[A, B] {
        #|  tuple(A, B)
        #|}
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) &&
    @module_compile.find_compiled_module(modules.modules, "Main")
    is Some(module_) else {
    abort("expected compiled Main module")
  }
  let binary = @artifact.module_interface_artifact_to_binary(
    module_.to_interface_artifact(),
  )
  let inspect_text = match @artifact.artifact_binary_to_inspect_text(binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(inspect_text),
    content=(
      #|Lane interface artifact
      #|module: Main
      #|schema: 14
      #|
      #|imported interfaces:
      #|  Basic.Data.Tuple: sha256:b8cc828dc42a4df958a95aea3b3d1a2f0d7ba5b4ed5818057621e3c69bd99885
      #|
      #|interface Main:
      #|types:
      #|  (none)
      #|effects:
      #|  (none)
      #|type aliases:
      #|  (none)
      #|values:
      #|  pub fn pair(value : Tuple[I64, Bool]) : (Tuple[I64, Bool]) -> Tuple[I64, Bool]
      #|
    ),
  )
}

///|
fn find_artifact_module(
  modules : Array[@artifact.CompiledModuleArtifact],
  module_path_text : String,
) -> @artifact.CompiledModuleArtifact? {
  for module_ in modules {
    if module_.interface.module_path_text == module_path_text {
      return Some(module_)
    }
  }
  None
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

///|
fn artifact_inspect_without_fingerprints(text : String) -> String {
  let lines = []
  for line in text.split("\n") {
    let line = line.to_owned()
    if !line.has_prefix("interface fingerprint:") &&
      !line.has_prefix("module fingerprint:") &&
      !line.has_prefix("object fingerprint:") {
      lines.push(line)
    }
  }
  lines.join("\n")
}
