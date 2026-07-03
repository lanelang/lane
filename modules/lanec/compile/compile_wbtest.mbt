///|
test "compile source records builtin externals and public entries" {
  let result = compile_source(
    (
      #|module Test
      #|pub let int_add : (Int, Int) -> Int = builtin("%i64_add")
      #|let private_value : Int = 1
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.externals.builtins.length(), content="1")
  inspect(result.externals.builtins[0].name, content="%i64_add")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="int_add",
  )
  guard result.program is Some(_) else { abort("expected Buslane program") }
}

///|
test "compile verifies handler around effectful function call" {
  let result = compile_source(
    (
      #|module Test
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|pub fn program() -> Int {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  guard result.program is Some(program) else {
    abort("expected Buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content="verify_result {}",
  )
}

///|
test "check reports payloadless variant call" {
  let result = check_source(
    (
      #|module Test
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|let value : Option[Int] = none()
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="payloadless variant `none` is not callable",
  )
}

///|
test "compile sources accepts explicit library modules" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources exposes only root public entries" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources accepts selective import with module dot syntax" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.{ value }
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources links only root reachable library modules" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
      (
        #|module Extra
        #|pub let extra : (Int, Int) -> Int = builtin("%i64_add")
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.externals.builtins.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile modules returns separate module objects and interfaces" {
  let result = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : Int
        #|}
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  inspect(modules.root_module_path_text, content="Main")
  inspect(
    modules.modules.map(fn(module_) { module_.module_path_text }).join(","),
    content="Lib,Main",
  )
  guard find_compiled_module(modules.modules, "Lib") is Some(lib) else {
    abort("expected Lib module")
  }
  guard find_compiled_module(modules.modules, "Main") is Some(main) else {
    abort("expected Main module")
  }
  inspect(lib.interface.values.length(), content="1")
  inspect(lib.object.module_path_text, content="Lib")
  inspect(
    lib.object.exports.map(fn(item) { item.name }).join(","),
    content="Box,Box,Box.value,value",
  )
  inspect(
    main.object.imports
    .map(fn(item) { "\{item.module_path_text}::\{item.name}" })
    .join(","),
    content="Lib::Box,Lib::Box,Lib::Box.value,Lib::value",
  )
}

///|
test "link modules produces Buslane program from reachable module objects" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
      (
        #|module Extra
        #|pub let extra : (Int, Int) -> Int = builtin("%i64_add")
      ),
    ],
  )
  inspect(compiled.diagnostics.length(), content="0")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules(modules)
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(program.module_path_texts.join(","), content="Lib,Main")
  inspect(program.externals.builtins.length(), content="0")
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
  inspect(
    @prettyprinter.render(program.program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 : Int
      #|    value answer#1 : Int
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "link modules remaps effect operations through one identity" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub fn program() -> Int {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(42)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
    [
      (
        #|module Lib
        #|pub effect Console {
        #|  read() -> Int
        #|}
        #|pub fn read_int() -> Int ! Console {
        #|  Console::read!()
        #|}
      ),
    ],
  )
  assert_eq(compiled.diagnostics.length(), 0)
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules(modules)
  assert_eq(linked.diagnostics.length(), 0)
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(program.program.metadata.effects.length(), 1)
  assert_eq(program.program.metadata.operations.length(), 1)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "link modules remaps data constructors through one identity" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let main_flag : Flag = flag
    ),
    [
      (
        #|module Lib
        #|pub enum Flag {
        #|  on
        #|}
        #|pub let flag : Flag = on
      ),
    ],
  )
  assert_eq(compiled.diagnostics.length(), 0)
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules(modules)
  assert_eq(linked.diagnostics.length(), 0)
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(program.program.metadata.types.length(), 1)
  assert_eq(program.program.metadata.data_constructors.length(), 1)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "module artifacts roundtrip through binary and link" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = box.value
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : Int
        #|}
        #|pub let box : Box = Box::{ value: 42 }
      ),
    ],
  )
  inspect(compiled.diagnostics.length(), content="0")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let decoded_modules = []
  for module_ in artifact.modules {
    let interface_binary = module_interface_artifact_to_binary(
      module_.interface,
    )
    let object_binary = module_object_artifact_to_binary(module_.object)
    let interface = match
      parse_module_interface_artifact_binary(interface_binary) {
      Ok(interface) => interface
      Err(message) => abort(message)
    }
    let object = match parse_module_object_artifact_binary(object_binary) {
      Ok(object) => object
      Err(message) => abort(message)
    }
    decoded_modules.push({
      schema_version: module_.schema_version,
      module_path_text: module_.module_path_text,
      interface,
      object,
      module_fingerprint: module_.module_fingerprint,
      imported_interface_fingerprints: module_.imported_interface_fingerprints,
    })
  }
  let linked = link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: decoded_modules,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  inspect(@prettyprinter.render(linked.diagnostics, width=100), content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  let linked_binary = linked_program_artifact_to_binary(program.to_artifact())
  inspect(byte_prefix_text(linked_binary, 8), content="76,65,78,69,65,82,84,0")
  let linked_decoded = match
    parse_linked_program_artifact_binary(linked_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  let linked_program = match linked_decoded.to_linked_program() {
    Ok(program) => program
    Err(diagnostics) => abort(@prettyprinter.render(diagnostics, width=100))
  }
  inspect(
    linked_program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
  let linked_inspect = match artifact_binary_to_inspect_text(linked_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(linked_inspect),
    content=(
      #|Lane program artifact
      #|schema: 1
      #|
      #|modules:
      #|  Lib
      #|  Main
      #|
      #|entries:
      #|  answer : Int
      #|
      #|externals:
      #|  (none)
      #|
      #|buslane:
      #|  buslane {
      #|    metadata {
      #|      type Box#0 {
      #|        Box#1(Int)
      #|      }
      #|      function value#2 : (type#0) -> Int
      #|      parameter receiver#3 : type#0
      #|      match_binder match#4 : type#0
      #|      match_binder value#5 : Int
      #|      value box#6 : type#0
      #|      value answer#7 : Int
      #|    }
      #|    let value#0 = fn(value#1) -> Int {
      #|      match value#1 as value#2 -> Int {
      #|        datacon#0(value#3) => value#3
      #|      }
      #|    }
      #|    let value#4 = datacon#0(42)
      #|    let value#5 = value#0(value#4)
      #|  }
      #|
    ),
  )
  let duplicated_entries = linked_decoded.entries.copy()
  duplicated_entries.push(linked_decoded.entries[0])
  let duplicate_entry_artifact : LinkedProgramArtifact = {
    schema_version: linked_decoded.schema_version,
    module_path_texts: linked_decoded.module_path_texts,
    program: linked_decoded.program,
    externals: linked_decoded.externals,
    entries: duplicated_entries,
  }
  guard duplicate_entry_artifact.to_linked_program()
    is Err(duplicate_entry_diagnostics) else {
    abort("expected duplicate linked entry diagnostic")
  }
  inspect(
    duplicate_entry_diagnostics
    .map(fn(diagnostic) { diagnostic.message })
    .join(","),
    content="duplicate linked entry `answer`",
  )
  let unknown_entry_artifact : LinkedProgramArtifact = {
    schema_version: linked_decoded.schema_version,
    module_path_texts: linked_decoded.module_path_texts,
    program: linked_decoded.program,
    externals: linked_decoded.externals,
    entries: [
      {
        name: "missing",
        value: { index: 999 },
        type_: linked_decoded.entries[0].type_,
      },
    ],
  }
  guard unknown_entry_artifact.to_linked_program()
    is Err(unknown_entry_diagnostics) else {
    abort("expected unknown linked entry diagnostic")
  }
  inspect(
    unknown_entry_diagnostics
    .map(fn(diagnostic) { diagnostic.message })
    .join(","),
    content="linked entry `missing` points to an unknown value",
  )
  let invalid_program_artifact : LinkedProgramArtifact = {
    schema_version: linked_decoded.schema_version,
    module_path_texts: linked_decoded.module_path_texts,
    program: {
      metadata: linked_decoded.program.metadata,
      terms: [External({ index: 999 })],
    },
    externals: linked_decoded.externals,
    entries: [],
  }
  guard invalid_program_artifact.to_linked_program()
    is Err(invalid_program_diagnostics) else {
    abort("expected invalid linked program diagnostic")
  }
  inspect(
    invalid_program_diagnostics
    .map(fn(diagnostic) { diagnostic.message })
    .join(","),
    content="linked program contains invalid Buslane",
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "module artifact binary rejects wrong kind" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  inspect(@prettyprinter.render(compiled.diagnostics, width=100), content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let object_binary = module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  inspect(byte_prefix_text(object_binary, 8), content="76,65,78,69,65,82,84,0")
  if parse_module_interface_artifact_binary(object_binary) is Err(message) {
    inspect(
      message,
      content="wrong artifact binary kind: expected interface, got object",
    )
  } else {
    abort("expected wrong artifact binary kind")
  }
  let linked = link_modules(modules)
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  let program_binary = linked_program_artifact_to_binary(program.to_artifact())
  if parse_module_object_artifact_binary(program_binary) is Err(message) {
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
  let provider = compile_modules(
    (
      #|module builtins
      #|pub let read_int : Int = 0
    ),
    [],
  )
  inspect(@prettyprinter.render(provider.diagnostics, width=100), content="[]")
  guard provider.modules is Some(provider_modules) else {
    abort("expected provider modules")
  }
  guard provider_modules.modules.get(0) is Some(provider_module) else {
    abort("expected provider module")
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Builtins.*
      #|pub let answer : Int = read_int
    ),
    [provider_module.to_interface_artifact()],
  )
  guard compiled.diagnostics.get(0) is Some(diagnostic) else {
    abort("expected missing import diagnostic")
  }
  inspect(
    @prettyprinter.render(diagnostic, width=100),
    content=(
      #|error[E4002]: missing imported module `Builtins`
      #|  --> 2:8-2:16
      #|  = label: 2:8-2:16 no explicit input provides this module
      #|  = note: Lane only compiles explicitly provided source files and interface artifacts
      #|  = considered interface artifact: declares module `builtins`
      #|  = help: pass an input whose declared module is `Builtins`, or change the import to one of the listed modules
      #|  = suggestion: check the imported module name against the listed explicit inputs (maybe-incorrect)
    ),
  )
}

///|
test "module artifact binary inspect renders human readable summaries" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  inspect(@prettyprinter.render(compiled.diagnostics, width=100), content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let interface_binary = module_interface_artifact_to_binary(
    module_.to_interface_artifact(),
  )
  let object_binary = module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  let interface_text = match artifact_binary_to_inspect_text(interface_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  let object_text = match artifact_binary_to_inspect_text(object_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(interface_text),
    content=(
      #|Lane interface artifact
      #|module: Main
      #|schema: 1
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
      #|  pub let answer : Int
      #|
    ),
  )
  inspect(
    artifact_inspect_without_fingerprints(object_text),
    content=(
      #|Lane object artifact
      #|module: Main
      #|schema: 4
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
      #|  pub let answer : Int
      #|
      #|object:
      #|imports:
      #|  (none)
      #|exports:
      #|  value answer
      #|entries:
      #|  answer : Int
      #|externals:
      #|  (none)
      #|buslane:
      #|  buslane {
      #|    metadata {
      #|      value answer#0 : Int
      #|    }
      #|    let value#0 = 42
      #|  }
      #|
    ),
  )
}

///|
test "compile module interface preserves public effects across artifact import" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|pub let value : Int = 42
    ),
    [],
  )
  inspect(
    @prettyprinter.render(lib_compiled.diagnostics, width=100),
    content="[]",
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let interface_text = module_interface_artifact_to_text(lib_artifact.interface)
  let decoded = match parse_module_interface_artifact_text(interface_text) {
    Ok(interface) => interface
    Err(message) => abort(message)
  }
  inspect(
    interface_effect_signatures(decoded.interface),
    content="State[1]{get/0->tparam#0,put/1->Unit}",
  )
  let main_compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.{State}
      #|pub let answer : Int = 42
    ),
    [lib_artifact.interface],
  )
  inspect(
    @prettyprinter.render(main_compiled.diagnostics, width=100),
    content="[]",
  )
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
test "module object text rejects old schema one artifact" {
  let parsed = parse_module_object_artifact_text(
    (
      #|lane-artifact-text-v1 object {
      #|  schema_version: 1;
      #|  module_path_text: "Old";
      #|  buslane {
      #|    metadata {
      #|    }
      #|  }
      #|}
    ),
  )
  guard parsed is Err(message) else {
    abort("expected old object schema failure")
  }
  inspect(
    message,
    content=(
      #|error[E5016]: unsupported artifact schema
      #|  = label: unsupported module object artifact schema 1 for Old
      #|  = note: this artifact was produced by an incompatible Lane compiler or old schema
      #|  = help: regenerate the artifact with the current Lane compiler
    ),
  )
}

///|
test "link module artifacts orders reachable modules by imports" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(compiled.diagnostics.length(), content="0")
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
  let linked = link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: "Main",
    modules: [main, lib],
    reachable_module_path_texts: ["Main", "Lib"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    @prettyprinter.render(program.program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 : Int
      #|    value answer#1 : Int
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
}

///|
test "compile module with interface artifact then link object artifacts" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  inspect(lib_compiled.diagnostics.length(), content="0")
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let main_compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = box.value
    ),
    [lib_artifact.interface],
  )
  inspect(main_compiled.diagnostics.length(), content="0")
  guard main_compiled.modules is Some(main_modules) else {
    abort("expected main modules")
  }
  guard main_modules.modules.get(0) is Some(main_module) else {
    abort("expected Main module")
  }
  let main_artifact = main_module.to_artifact()
  let linked = link_module_object_artifacts([
    lib_artifact.object,
    main_artifact.object,
  ])
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="Lib::box,Main::answer",
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "compile module freshens independently compiled interface symbols" {
  let left_compiled = compile_modules(
    (
      #|module Left
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let left : Box = Box::{ value: 1 }
    ),
    [],
  )
  inspect(left_compiled.diagnostics.length(), content="0")
  guard left_compiled.modules is Some(left_modules) else {
    abort("expected Left modules")
  }
  guard left_modules.modules.get(0) is Some(left_module) else {
    abort("expected Left module")
  }
  let left_artifact = left_module.to_artifact()
  let right_compiled = compile_modules(
    (
      #|module Right
      #|pub struct Box {
      #|  item : Int
      #|}
      #|pub let right : Box = Box::{ item: 2 }
    ),
    [],
  )
  inspect(right_compiled.diagnostics.length(), content="0")
  guard right_compiled.modules is Some(right_modules) else {
    abort("expected Right modules")
  }
  guard right_modules.modules.get(0) is Some(right_module) else {
    abort("expected Right module")
  }
  let right_artifact = right_module.to_artifact()
  let main_compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Left.*
      #|import Right.*
      #|pub let answer : Int = right.item
    ),
    [left_artifact.interface, right_artifact.interface],
  )
  inspect(main_compiled.diagnostics.length(), content="0")
  guard main_compiled.modules is Some(main_modules) else {
    abort("expected Main modules")
  }
  guard main_modules.modules.get(0) is Some(main_module) else {
    abort("expected Main module")
  }
  let main_artifact = main_module.to_artifact()
  let linked = link_module_artifacts({
    schema_version: 1,
    root_module_path_text: "Main",
    modules: [left_artifact, right_artifact, main_artifact],
    reachable_module_path_texts: ["Left", "Right", "Main"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile module follows transitive interface dependencies without extra pollution" {
  let extra_compiled = compile_modules(
    (
      #|module Extra
      #|pub struct Noise {
      #|  value : Int
      #|}
    ),
    [],
  )
  inspect(extra_compiled.diagnostics.length(), content="0")
  guard extra_compiled.modules is Some(extra_modules) else {
    abort("expected Extra modules")
  }
  guard extra_modules.modules.get(0) is Some(extra_module) else {
    abort("expected Extra module")
  }
  let extra_artifact = extra_module.to_artifact()
  let a_compiled = compile_modules(
    (
      #|module A
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  inspect(a_compiled.diagnostics.length(), content="0")
  guard a_compiled.modules is Some(a_modules) else {
    abort("expected A modules")
  }
  guard a_modules.modules.get(0) is Some(a_module) else {
    abort("expected A module")
  }
  let a_artifact = a_module.to_artifact()
  let b_compiled = compile_module_with_interface_artifacts(
    (
      #|module B
      #|import A.*
      #|pub let forwarded : Box = box
    ),
    [extra_artifact.interface, a_artifact.interface],
  )
  inspect(b_compiled.diagnostics.length(), content="0")
  guard b_compiled.modules is Some(b_modules) else {
    abort("expected B modules")
  }
  guard b_modules.modules.get(0) is Some(b_module) else {
    abort("expected B module")
  }
  let b_artifact = b_module.to_artifact()
  let c_compiled = compile_module_with_interface_artifacts(
    (
      #|module C
      #|import B.*
      #|pub let answer : Int = forwarded.value
    ),
    [b_artifact.interface, a_artifact.interface],
  )
  inspect(c_compiled.diagnostics.length(), content="0")
  guard c_compiled.modules is Some(c_modules) else {
    abort("expected C modules")
  }
  guard c_modules.modules.get(0) is Some(c_module) else {
    abort("expected C module")
  }
  let c_artifact = c_module.to_artifact()
  let linked = link_module_artifacts({
    schema_version: 1,
    root_module_path_text: "C",
    modules: [c_artifact, b_artifact, a_artifact],
    reachable_module_path_texts: ["C", "B", "A"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile module reports missing transitive interface dependency" {
  let a_compiled = compile_modules(
    (
      #|module A
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  guard a_compiled.modules is Some(a_modules) else {
    abort("expected A modules")
  }
  guard a_modules.modules.get(0) is Some(a_module) else {
    abort("expected A module")
  }
  let a_artifact = a_module.to_artifact()
  let b_compiled = compile_module_with_interface_artifacts(
    (
      #|module B
      #|import A.*
      #|pub let forwarded : Box = box
    ),
    [a_artifact.interface],
  )
  guard b_compiled.modules is Some(b_modules) else {
    abort("expected B modules")
  }
  guard b_modules.modules.get(0) is Some(b_module) else {
    abort("expected B module")
  }
  let b_artifact = b_module.to_artifact()
  let c_compiled = compile_module_with_interface_artifacts(
    (
      #|module C
      #|import B.*
      #|pub let answer : Int = forwarded.value
    ),
    [b_artifact.interface],
  )
  inspect(c_compiled.diagnostics.length(), content="1")
  inspect(
    c_compiled.diagnostics[0].message,
    content="missing imported module `A`",
  )
}

///|
test "compile module rejects interface artifact name mismatch" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let interface = lib_artifact.interface.interface
  let damaged_interface : @module_interface.ModuleInterface = {
    module_path: "Other",
    types: interface.types,
    effects: interface.effects,
    type_aliases: interface.type_aliases,
    values: interface.values,
    optimization_hints: interface.optimization_hints,
  }
  let damaged : ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: damaged_interface,
    interface_fingerprint: lib_artifact.interface.interface_fingerprint,
    module_fingerprint: lib_artifact.interface.module_fingerprint,
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [damaged],
  )
  inspect(compiled.diagnostics.length(), content="1")
  inspect(
    compiled.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "compile module rejects stale interface artifact fingerprint" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let damaged : ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: lib_artifact.interface.interface,
    interface_fingerprint: { value: "stale" },
    module_fingerprint: lib_artifact.interface.module_fingerprint,
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [damaged],
  )
  inspect(compiled.diagnostics.length(), content="1")
  inspect(
    compiled.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "compile module rejects stale interface artifact module fingerprint" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let damaged : ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: lib_artifact.interface.interface,
    interface_fingerprint: lib_artifact.interface.interface_fingerprint,
    module_fingerprint: { value: "stale" },
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [damaged],
  )
  inspect(compiled.diagnostics.length(), content="1")
  inspect(
    compiled.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "module object fingerprint changes on implementation-only changes" {
  let first_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 1
    ),
    [],
  )
  let second_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 2
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
  let first_artifact = first_module.to_artifact()
  let second_artifact = second_module.to_artifact()
  debug_inspect(
    [
      first_artifact.interface.interface_fingerprint ==
      second_artifact.interface.interface_fingerprint,
      first_artifact.module_fingerprint == second_artifact.module_fingerprint,
      first_artifact.object.object_fingerprint ==
      second_artifact.object.object_fingerprint,
    ],
    content="[true, true, false]",
  )
}

///|
test "link object artifacts rejects stale object fingerprint" {
  let compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected module")
  }
  let object = module_.to_object_artifact()
  let damaged : ModuleObjectArtifact = {
    schema_version: object.schema_version,
    module_path_text: object.module_path_text,
    interface: object.interface,
    interface_fingerprint: object.interface_fingerprint,
    metadata: object.metadata,
    terms: object.terms,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    module_fingerprint: object.module_fingerprint,
    object_fingerprint: { value: "stale" },
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
  let linked = link_module_object_artifacts([damaged])
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="invalid module object artifact",
  )
}

///|
test "link module artifacts rejects interface object fingerprint mismatch" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged = artifact.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let object : ModuleObjectArtifact = {
        schema_version: module_.object.schema_version,
        module_path_text: module_.object.module_path_text,
        interface: module_.object.interface,
        interface_fingerprint: module_.object.interface_fingerprint,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        module_fingerprint: { value: "stale" },
        object_fingerprint: module_.object.object_fingerprint,
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      {
        schema_version: module_.schema_version,
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        module_fingerprint: module_.module_fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="invalid compiled module artifact",
  )
}

///|
test "link module artifacts rejects interface object name mismatch" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged = artifact.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let interface : ModuleInterfaceArtifact = {
        schema_version: module_.interface.schema_version,
        module_path_text: "Other",
        interface: module_.interface.interface,
        interface_fingerprint: module_.interface.interface_fingerprint,
        module_fingerprint: module_.interface.module_fingerprint,
        imported_interface_fingerprints: module_.interface.imported_interface_fingerprints,
      }
      {
        schema_version: module_.schema_version,
        module_path_text: module_.module_path_text,
        interface,
        object: module_.object,
        module_fingerprint: module_.module_fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "link modules rejects stale module object fingerprint" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let stale_modules = modules.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let fingerprint = { value: "stale" }
      let object : ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        fingerprint,
        object_fingerprint: module_object_fingerprint(
          fingerprint,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          module_.object.exports,
          module_.object.imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      {
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_modules({
    root_module_path_text: modules.root_module_path_text,
    modules: stale_modules,
    reachable_module_path_texts: modules.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(linked.diagnostics[0].message, content="stale module object")
}

///|
test "link modules rejects stale imported reference fingerprint" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let damaged_modules = modules.modules.map(fn(module_) {
    if module_.module_path_text == "Main" {
      let imports : Array[ModuleImportedReference] = module_.object.imports.map(fn(
          imported,
        ) {
          {
            module_path_text: imported.module_path_text,
            kind: imported.kind,
            name: imported.name,
            fingerprint: { value: "stale" },
            type_id: imported.type_id,
            data_constructor: imported.data_constructor,
            effect_id: imported.effect_id,
            operation: imported.operation,
            value: imported.value,
          }
        },
      )
      let object : ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports,
        fingerprint: module_.object.fingerprint,
        object_fingerprint: module_object_fingerprint(
          module_.object.fingerprint,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          module_.object.exports,
          imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      {
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_modules({
    root_module_path_text: modules.root_module_path_text,
    modules: damaged_modules,
    reachable_module_path_texts: modules.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(linked.diagnostics[0].message, content="stale imported reference")
}

///|
test "link modules rejects missing exported object value" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let damaged_modules = modules.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let exports = []
      let object : ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports,
        imports: module_.object.imports,
        fingerprint: module_.object.fingerprint,
        object_fingerprint: module_object_fingerprint(
          module_.object.fingerprint,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          exports,
          module_.object.imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      {
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_modules({
    root_module_path_text: modules.root_module_path_text,
    modules: damaged_modules,
    reachable_module_path_texts: modules.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="object artifact does not satisfy its interface",
  )
}

///|
test "link modules rejects compiled artifact import cycle" {
  let compiled_a = compile_modules(
    (
      #|module A
      #|pub let a : Int = 1
    ),
    [],
  )
  let compiled_b = compile_modules(
    (
      #|module B
      #|pub let b : Int = 2
    ),
    [],
  )
  guard compiled_a.modules is Some(modules_a) else {
    abort("expected A modules")
  }
  guard compiled_b.modules is Some(modules_b) else {
    abort("expected B modules")
  }
  guard modules_a.modules.get(0) is Some(module_a) else {
    abort("expected A module")
  }
  guard modules_b.modules.get(0) is Some(module_b) else {
    abort("expected B module")
  }
  let module_a = module_with_imported_interfaces(module_a, [
    {
      module_path_text: "B",
      fingerprint: interface_fingerprint(module_b.interface),
    },
  ])
  let module_b = module_with_imported_interfaces(module_b, [
    {
      module_path_text: "A",
      fingerprint: interface_fingerprint(module_a.interface),
    },
  ])
  let linked = link_modules({
    root_module_path_text: "A",
    modules: [module_a, module_b],
    reachable_module_path_texts: ["A", "B"],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(linked.diagnostics[0].message, content="import cycle involving `A`")
}

///|
test "link modules rejects missing compiled artifact import" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else { abort("expected modules") }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected Main module")
  }
  let module_ = module_with_imported_interfaces(module_, [
    { module_path_text: "Missing", fingerprint: { value: "missing" } },
  ])
  let linked = link_modules({
    root_module_path_text: "Main",
    modules: [module_],
    reachable_module_path_texts: ["Main"],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="missing object artifact for `Missing`",
  )
}

///|
test "check sources does not expose private imported values" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find value `value`")
}

///|
test "check sources does not expose private imported types" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find type `Hidden`")
}

///|
test "check sources rejects private nominal type escape through public function" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = leak().value
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : Int
        #|}
        #|pub fn leak() -> Hidden {
        #|  Hidden::{ value: 42 }
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
  match result.diagnostics[0].span {
    Some(span) => {
      inspect(span.start_line, content="5")
      inspect(span.start_column, content="18")
      inspect(span.end_line, content="5")
      inspect(span.end_column, content="24")
    }
    None => abort("expected diagnostic span")
  }
}

///|
test "check source rejects private nominal type escape through public let" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check source rejects private nominal type escape through public struct field" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub struct Box {
      #|  hidden : Hidden
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check source rejects private nominal type escape through public enum payload" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub enum Box {
      #|  boxed(Hidden)
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check source rejects private nominal type escape through public type alias" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub type Exposed = Hidden
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check sources exposes public imported nominal shape through public value" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = point().x
    ),
    [
      (
        #|module Lib
        #|pub struct Point {
        #|  x : Int
        #|}
        #|pub fn point() -> Point {
        #|  Point::{ x: 42 }
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "check sources rejects missing import" {
  let result = check_sources(
    (
      #|module Main
      #|import Missing
      #|pub let answer : Int = 42
    ),
    [],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="missing imported module `Missing`",
  )
}

///|
test "check sources resolves module qualified value access" {
  let result = compile_sources(
    (
      #|module Main
      #|import Core.Int
      #|pub let answer : Int = Core.Int.id(42)
    ),
    [
      (
        #|module Core.Int
        #|pub fn id(value : Int) -> Int {
        #|  value
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not import child module through parent module" {
  let result = check_sources(
    (
      #|module Main
      #|import Core
      #|pub let answer : Int = Core.Int.id(42)
    ),
    [
      (
        #|module Core
        #|pub let marker : Int = 0
      ),
      (
        #|module Core.Int
        #|pub fn id(value : Int) -> Int {
        #|  value
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="cannot find value `Core.Int.id`",
  )
}

///|
test "check sources resolves module qualified nominal type access" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Lib.Box = Lib.Box::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources resolves module qualified type alias access" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Lib.Answer = 42
    ),
    [
      (
        #|module Lib
        #|pub type Answer = Int
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources resolves module qualified variant expressions and patterns" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Int = match Lib.Option::some(42) {
      #|  Lib.Option::some(value) => value
      #|  Lib.Option::none => 0
      #|}
    ),
    [
      (
        #|module Lib
        #|pub enum Option {
        #|  some(Int)
        #|  none
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not import child module qualified type through parent module" {
  let result = check_sources(
    (
      #|module Main
      #|import Core
      #|pub fn consume(value : Core.Int.Box) -> Int {
      #|  0
      #|}
    ),
    [
      (
        #|module Core
        #|pub let marker : Int = 0
      ),
      (
        #|module Core.Int
        #|pub struct Box {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="cannot find type `Core.Int.Box`",
  )
}

///|
test "check sources rejects ambiguous module qualified field chain" {
  let result = check_sources(
    (
      #|module Main
      #|import core.int
      #|struct AddField {
      #|  add : Int
      #|}
      #|struct CoreBox {
      #|  int : AddField
      #|}
      #|let core : CoreBox = CoreBox::{ int: AddField::{ add: 1 } }
      #|pub let answer : Int = core.int.add
    ),
    [
      (
        #|module core.int
        #|pub let add : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="ambiguous module-qualified value `core.int.add`",
  )
}

///|
test "check sources rejects duplicate module input" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Main
        #|pub let value : Int = 1
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="duplicate module input `Main`",
  )
}

///|
test "import reachable source inputs ignore unrelated parse diagnostics" {
  let result = import_reachable_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|import Lib.*
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|pub let value : Int = 42
        ),
      },
      {
        source_id: "file:///Unrelated.lane",
        text: (
          #|module Unrelated
          #|pub let broken : =
        ),
      },
    ],
  )
  match result {
    Ok(inputs) =>
      inspect(
        inputs.map(fn(input) { input.source_id }).join(","),
        content="file:///Main.lane,file:///Lib.lane",
      )
    Err(diagnostics) => {
      inspect(diagnostics.map(fn(diagnostic) { diagnostic.message }).join("\n"))
      fail("expected unrelated parse diagnostics to be ignored")
    }
  }
}

///|
test "import reachable analysis reports reachable parse diagnostics" {
  let result = analyze_import_reachable_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|import Lib.*
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|pub let broken : =
        ),
      },
      {
        source_id: "file:///Unrelated.lane",
        text: (
          #|module Unrelated
          #|pub let also_broken : =
        ),
      },
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  debug_inspect(
    result.diagnostics[0].source_id,
    content=(
      #|Some("file:///Lib.lane")
    ),
  )
  inspect(result.diagnostics[0].message, content="unexpected token")
}

///|
test "check sources checks unimported library modules" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Extra
        #|pub let extra : Int = missing
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find value `missing`")
}

///|
test "check sources rejects unimported library import cycle" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module ExtraA
        #|import ExtraB
        #|pub let value : Int = 1
      ),
      (
        #|module ExtraB
        #|import ExtraA
        #|pub let value : Int = 2
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="import cycle involving `ExtraA`",
  )
}

///|
test "check sources rejects import cycle" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Lib
        #|import Main
        #|pub let value : Int = 1
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="import cycle involving `Main`",
  )
}

///|
test "analysis resolves same-file definition and hover" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : Int = 42
        #|
        #|pub let answer : Int = value
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected definition")
  }
  match result.hover_at("file:///Main.lane", 5, 24) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected hover")
  }
  match result.hover_at("file:///Main.lane", 3, 10) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected definition hover")
  }
  inspect(
    result.definition_at("file:///Main.lane", 5, 29) is None,
    content="true",
  )
}

///|
test "analysis resolves cross-module definition by source identity" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|import Lib.*
        #|
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|
          #|pub let value : Int = 42
        ),
      },
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Lib.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected cross-module definition")
  }
}

///|
test "analysis resolves types fields and variants" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Point {
        #|  x : Int
        #|}
        #|
        #|pub enum Option {
        #|  some(Point)
        #|  none
        #|}
        #|
        #|pub let point : Point = Point::{ x: 1 }
        #|
        #|pub let field_value : Int = point.x
        #|
        #|pub let wrapped : Option = some(point)
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 12, 18) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected type definition")
  }
  match result.definition_at("file:///Main.lane", 12, 26) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected struct literal type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 12, 32) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 38) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 39) is None,
    content="true",
  )
  match result.hover_at("file:///Main.lane", 3, 13) {
    Some(hover) => inspect(hover.contents, content="type Point : Type")
    None => abort("expected type definition hover")
  }
  match result.definition_at("file:///Main.lane", 14, 35) {
    Some(location) => inspect(location.span.start_line, content="4")
    None => abort("expected field definition")
  }
  match result.hover_at("file:///Main.lane", 4, 3) {
    Some(hover) => inspect(hover.contents, content="x : Int")
    None => abort("expected field definition hover")
  }
  match result.definition_at("file:///Main.lane", 16, 29) {
    Some(location) => inspect(location.span.start_line, content="8")
    None => abort("expected variant definition")
  }
  match result.hover_at("file:///Main.lane", 16, 29) {
    Some(hover) => inspect(hover.contents, content="some(Point)")
    None => abort("expected variant hover")
  }
}

///|
test "analysis narrows struct pattern type references" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Point {
        #|  x : Int
        #|}
        #|
        #|pub fn get_x(point : Point) -> Int {
        #|  match point {
        #|    Point::{ x } => x
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 9, 6) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected pattern type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 9, 13) is None,
    content="true",
  )
}

///|
test "analysis keeps partial definitions when unrelated diagnostics exist" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : Int = 42
        #|
        #|pub let answer : Int = value
        #|
        #|pub let bad : Int = missing
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find value `missing`")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected partial definition")
  }
}

///|
test "analysis produces type inlay hints for inferred binders" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = seed
        #|  match local {
        #|    value => value
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 54,
      #|        end_offset: 59,
      #|        start_line: 4,
      #|        start_column: 7,
      #|        end_line: 4,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 87,
      #|        end_offset: 92,
      #|        start_line: 6,
      #|        start_column: 5,
      #|        end_line: 6,
      #|        end_column: 10,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis renders user-facing type names in type inlay hints" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum Option[T] {
        #|  some(T)
        #|  none
        #|}
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let boxed = some(seed)
        #|  seed
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 95,
      #|        end_offset: 100,
      #|        start_line: 9,
      #|        start_column: 7,
      #|        end_line: 9,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Option[Int]",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis produces parameter name inlay hints for calls" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum Option {
        #|  some(Int, Bool)
        #|  none
        #|}
        #|
        #|pub fn choose(left : Int, right : Int) -> Int {
        #|  left
        #|}
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = choose(seed, 1)
        #|  match some(local, true) {
        #|    ::some(value, flag) => value
        #|    ::none => 0
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 158,
      #|        end_offset: 163,
      #|        start_line: 13,
      #|        start_column: 7,
      #|        end_line: 13,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 173,
      #|        end_offset: 177,
      #|        start_line: 13,
      #|        start_column: 22,
      #|        end_line: 13,
      #|        end_column: 26,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "left=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 179,
      #|        end_offset: 180,
      #|        start_line: 13,
      #|        start_column: 28,
      #|        end_line: 13,
      #|        end_column: 29,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "right=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 221,
      #|        end_offset: 226,
      #|        start_line: 15,
      #|        start_column: 12,
      #|        end_line: 15,
      #|        end_column: 17,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 228,
      #|        end_offset: 232,
      #|        start_line: 15,
      #|        start_column: 19,
      #|        end_line: 15,
      #|        end_column: 23,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Bool",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis does not synthesize constructor parameter hints from payload types" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum List[A] {
        #|  nil
        #|  cons(A, List[A])
        #|}
        #|
        #|pub fn answer(hd : Int, tl : List[Int]) -> List[Int] {
        #|  List::cons(hd, tl)
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.inlay_hints.length(), content="0")
}

///|
test "analysis keeps nested call parameter hints at distinct positions" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn append(left : Int, right : Int) -> Int {
        #|  left
        #|}
        #|
        #|pub fn apply(f : (Int) -> Int, value : Int) -> Int {
        #|  f(value)
        #|}
        #|
        #|pub fn inc(value : Int) -> Int {
        #|  value
        #|}
        #|
        #|pub let answer : Int = append(1, apply(inc, 2))
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  assert_no_duplicate_parameter_hint_positions(result.inlay_hints)
}

///|
test "analysis skips parameter name inlay hints for source operators" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn op_add(left : Int, right : Int) -> Int {
        #|  left
        #|}
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = seed + 1
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 112,
      #|        end_offset: 117,
      #|        start_line: 8,
      #|        start_column: 7,
      #|        end_line: 8,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis produces implicit argument inlay hints for auto offers" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
        #|  op.add(a, b)
        #|}
        #|
        #|offer int_add_ops : Add[Int] = builtin("%int_add_ops")
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = seed + 1
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 227,
      #|        end_offset: 232,
      #|        start_line: 14,
      #|        start_column: 7,
      #|        end_line: 14,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 242,
      #|        end_offset: 243,
      #|        start_line: 14,
      #|        start_column: 22,
      #|        end_line: 14,
      #|        end_column: 23,
      #|      },
      #|    },
      #|    kind: ImplicitArgumentHint,
      #|    label: ", op=int_add_ops",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis combines implicit argument inlay hints at the call end" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub struct Eq[A] {
        #|  eq : (A, A) -> Bool
        #|}
        #|
        #|pub fn[A] choose(a : A, b : A, auto op : Add[A], auto eq : Eq[A]) -> A {
        #|  if eq.eq(a, b) {
        #|    op.add(a, b)
        #|  } else {
        #|    a
        #|  }
        #|}
        #|
        #|offer int_add_ops : Add[Int] = builtin("%int_add_ops")
        #|offer int_eq_ops : Eq[Int] = builtin("%int_eq_ops")
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = choose(seed, 1)
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    implicit_inlay_hint_labels(result.inlay_hints).join("\n"),
    content=", op=int_add_ops, eq=int_eq_ops",
  )
}

///|
test "analysis does not mark explicit named auto arguments as implicit" {
  let result = analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
        #|  op.add(a, b)
        #|}
        #|
        #|let int_add_ops : Add[Int] = builtin("%int_add_ops")
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = op_add(seed, 1, op=int_add_ops)
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 225,
      #|        end_offset: 230,
      #|        start_line: 14,
      #|        start_column: 7,
      #|        end_line: 14,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 240,
      #|        end_offset: 244,
      #|        start_line: 14,
      #|        start_column: 22,
      #|        end_line: 14,
      #|        end_column: 26,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "a=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 246,
      #|        end_offset: 247,
      #|        start_line: 14,
      #|        start_column: 28,
      #|        end_line: 14,
      #|        end_column: 29,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "b=",
      #|  },
      #|]
    ),
  )
}

///|
fn find_artifact_module(
  modules : Array[CompiledModuleArtifact],
  module_path_text : String,
) -> CompiledModuleArtifact? {
  for module_ in modules {
    if module_.module_path_text == module_path_text {
      return Some(module_)
    }
  }
  None
}

///|
fn implicit_inlay_hint_labels(hints : Array[InlayHintEntry]) -> Array[String] {
  let labels = []
  for hint in hints {
    match hint.kind {
      ImplicitArgumentHint => labels.push(hint.label)
      _ => ()
    }
  }
  labels
}

///|
fn assert_no_duplicate_parameter_hint_positions(
  hints : Array[InlayHintEntry],
) -> Unit {
  let positions = []
  for hint in hints {
    guard hint.kind is ParameterHint else { continue }
    let position = "\{hint.location.source_id}:\{hint.location.span.start_line}:\{hint.location.span.start_column}"
    if positions.contains(position) {
      abort("duplicate parameter inlay hint position: \{position}")
    }
    positions.push(position)
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

///|
fn module_with_imported_interfaces(
  module_ : CompiledModule,
  imported : Array[ImportedInterfaceFingerprint],
) -> CompiledModule {
  let object : ModuleObject = {
    module_path_text: module_.object.module_path_text,
    checked: module_.object.checked,
    metadata: module_.object.metadata,
    terms: module_.object.terms,
    externals: module_.object.externals,
    entries: module_.object.entries,
    exports: module_.object.exports,
    imports: module_.object.imports,
    fingerprint: module_.object.fingerprint,
    object_fingerprint: module_object_fingerprint(
      module_.object.fingerprint,
      module_.object.metadata,
      module_.object.terms,
      module_.object.externals,
      module_.object.entries,
      module_.object.exports,
      module_.object.imports,
      imported,
    ),
    imported_interface_fingerprints: imported,
  }
  {
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    object,
    fingerprint: module_.fingerprint,
    imported_interface_fingerprints: imported,
  }
}
