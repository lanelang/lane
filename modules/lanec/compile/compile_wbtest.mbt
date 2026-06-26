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
    content="payloadless_variant_call none",
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
    .map(fn(item) { item.module_path_text + "::" + item.name })
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
  inspect(program.root_module_path_text, content="Main")
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
      #|    value value#1 : Int
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
test "module artifacts roundtrip through json and link" {
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
  let artifact = compiled_module_set_artifact(modules)
  let decoded : CompiledModuleSetArtifact = @json.from_json(artifact.to_json())
  let linked = link_module_artifacts(decoded)
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
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
  let artifact = compiled_module_set_artifact(modules)
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
      #|    value value#1 : Int
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
}

///|
test "compile module with interface artifact then link with object artifact" {
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
  let lib_artifact = compiled_module_artifact(lib_module)
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
  let main_artifact = compiled_module_artifact(main_module)
  let linked = link_module_artifacts({
    schema_version: 1,
    root_module_path_text: "Main",
    modules: [lib_artifact, main_artifact],
    reachable_module_path_texts: ["Lib", "Main"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
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
  let left_artifact = compiled_module_artifact(left_module)
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
  let right_artifact = compiled_module_artifact(right_module)
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
  let main_artifact = compiled_module_artifact(main_module)
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
  let extra_artifact = compiled_module_artifact(extra_module)
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
  let a_artifact = compiled_module_artifact(a_module)
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
  let b_artifact = compiled_module_artifact(b_module)
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
  let c_artifact = compiled_module_artifact(c_module)
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
  let a_artifact = compiled_module_artifact(a_module)
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
  let b_artifact = compiled_module_artifact(b_module)
  let c_compiled = compile_module_with_interface_artifacts(
    (
      #|module C
      #|import B.*
      #|pub let answer : Int = forwarded.value
    ),
    [b_artifact.interface],
  )
  inspect(c_compiled.diagnostics.length(), content="1")
  inspect(c_compiled.diagnostics[0].message, content="missing import A")
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
  let lib_artifact = compiled_module_artifact(lib_module)
  let interface = lib_artifact.interface.interface
  let damaged_interface : @module_interface.ModuleInterface = {
    module_path: "Other",
    types: interface.types,
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
    content="module interface artifact name mismatch Lib",
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
  let lib_artifact = compiled_module_artifact(lib_module)
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
    content="module interface artifact fingerprint mismatch Lib",
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
  let lib_artifact = compiled_module_artifact(lib_module)
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
    content="module interface artifact module fingerprint mismatch Lib",
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
  let artifact = compiled_module_set_artifact(modules)
  let damaged = artifact.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let object : ModuleObjectArtifact = {
        schema_version: module_.object.schema_version,
        module_path_text: module_.object.module_path_text,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        module_fingerprint: { value: "stale" },
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
    content="module artifact fingerprint mismatch Lib",
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
  let artifact = compiled_module_set_artifact(modules)
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
    content="module interface artifact name mismatch Other",
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
      let object : ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        fingerprint: { value: "stale" },
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
  inspect(
    linked.diagnostics[0].message,
    content="module fingerprint mismatch Lib",
  )
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
      let object : ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports.map(fn(imported) {
          {
            module_path_text: imported.module_path_text,
            kind: imported.kind,
            name: imported.name,
            fingerprint: { value: "stale" },
            type_id: imported.type_id,
            data_constructor: imported.data_constructor,
            value: imported.value,
          }
        }),
        fingerprint: module_.object.fingerprint,
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
    content="imported reference fingerprint mismatch Main -> Lib::value",
  )
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
      let object : ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: [],
        imports: module_.object.imports,
        fingerprint: module_.object.fingerprint,
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
    content="missing exported value Lib::value imported by Main",
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
  inspect(linked.diagnostics[0].message, content="import cycle A")
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
  inspect(linked.diagnostics[0].message, content="missing object Missing")
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
  inspect(result.diagnostics[0].message, content="unresolved_value value")
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
  inspect(result.diagnostics[0].message, content="unresolved_type Hidden")
}

///|
test "check sources does not expose private imported nominal shape through public value" {
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
  inspect(result.diagnostics[0].message, content="not_a_struct type#0")
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
  inspect(result.diagnostics[0].message, content="missing import Missing")
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
  inspect(result.diagnostics[0].message, content="unresolved_value Core.Int.id")
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
  inspect(result.diagnostics[0].message, content="unresolved_type Core.Int.Box")
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
    content="ambiguous_module_value core.int.add",
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
  inspect(result.diagnostics[0].message, content="duplicate module input Main")
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
  inspect(result.diagnostics[0].message, content="unresolved_value missing")
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
  inspect(result.diagnostics[0].message, content="import cycle ExtraA")
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
  inspect(result.diagnostics[0].message, content="import cycle Main")
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
        #|struct Point {
        #|  x : Int
        #|}
        #|
        #|enum Option {
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
  match result.hover_at("file:///Main.lane", 3, 9) {
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
    Some(hover) => inspect(hover.contents, content="some(type#0)")
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
        #|struct Point {
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
  inspect(result.diagnostics[0].message, content="unresolved_value missing")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected partial definition")
  }
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
