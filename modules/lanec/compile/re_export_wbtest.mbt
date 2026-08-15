///|
fn re_export_provider_source() -> String {
  (
    #|module Provider
    #|pub struct Box {
    #|  value : I64
    #|}
    #|pub let base : I64 = 40
  )
}

///|
fn re_export_facade_source() -> String {
  (
    #|module Facade
    #|pub import Provider.{ Box, base }
  )
}

///|
test "public export targets stay provider-owned without forwarding terms" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Facade
      #|pub fn answer(box : Facade.Box) -> I64 {
      #|  let _base = Facade.base
      #|  box.value
      #|}
    ),
    [re_export_provider_source(), re_export_facade_source()],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Facade")
    is Some(facade) else {
    abort("expected facade module")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Main")
    is Some(main) else {
    abort("expected main module")
  }
  assert_eq(
    (
      facade.interface.exports.map(fn(export_) {
        (
          export_.export_namespace,
          export_.exposed_name,
          export_.target.provider_module,
          export_.target.declaration_name,
        )
      }),
      facade.object.terms.length(),
      facade.object.exports.length(),
      main.object.imports.any(fn(import_) {
        import_.module_path_text == "Provider"
      }),
      main.object.imports.any(fn(import_) {
        import_.module_path_text == "Facade"
      }),
    ),
    (
      [
        (TypeNamespace, "Box", "Provider", "Box"),
        (ValueNamespace, "base", "Provider", "base"),
      ],
      0,
      0,
      true,
      false,
    ),
  )
}

///|
test "public exports survive separate interface artifact compilation" {
  let provider = compile_modules_for_test(re_export_provider_source(), [])
  guard provider.modules is Some(provider_modules) else {
    abort("expected provider module")
  }
  guard @module_compile.find_compiled_module(
      provider_modules.modules,
      "Provider",
    )
    is Some(provider_module) else {
    abort("expected provider module")
  }
  let provider_interface = provider_module.to_interface_artifact()
  let facade = compile_module_with_interfaces_for_test(
    re_export_facade_source(),
    [provider_interface],
  )
  assert_eq(facade.diagnostics, [])
  guard facade.modules is Some(facade_modules) else {
    abort("expected facade module")
  }
  guard @module_compile.find_compiled_module(facade_modules.modules, "Facade")
    is Some(facade_module) else {
    abort("expected facade module")
  }
  let facade_interface = facade_module.to_interface_artifact()
  let binary = @artifact.module_interface_artifact_to_binary(facade_interface)
  let decoded = @artifact.parse_module_interface_artifact_binary(binary).unwrap()
  assert_eq(decoded, facade_interface)
  let consumer = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Facade
      #|pub fn answer(box : Facade.Box) -> I64 {
      #|  box.value
      #|}
    ),
    [provider_interface, decoded],
  )
  assert_eq(consumer.diagnostics, [])
}

///|
test "interface validation rejects a stale public export fingerprint" {
  let compiled = compile_modules_for_test(re_export_facade_source(), [
    re_export_provider_source(),
  ])
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Provider")
    is Some(provider) else {
    abort("expected provider module")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Facade")
    is Some(facade) else {
    abort("expected facade module")
  }
  let provider_interface = provider.to_interface_artifact()
  let facade_artifact = facade.to_interface_artifact()
  let damaged_interface = {
    ..facade_artifact.interface,
    exports: facade_artifact.interface.exports.mapi(fn(index, export_) {
      if index == 0 {
        { ..export_, expected_target_fingerprint: { value: "sha256:stale" } }
      } else {
        export_
      }
    }),
  }
  let damaged = @artifact.ModuleInterfaceArtifact::{
    ..facade_artifact,
    interface: damaged_interface,
    interface_fingerprint: @artifact.interface_fingerprint(damaged_interface),
    module_fingerprint: @artifact.module_fingerprint(
      damaged_interface,
      facade_artifact.imported_interface_fingerprints,
    ),
  }
  let consumer = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Facade
      #|pub let answer : I64 = Facade.base
    ),
    [provider_interface, damaged],
  )
  assert_eq(
    consumer.diagnostics.map(fn(diagnostic) {
      (diagnostic.code, diagnostic.message)
    }),
    [(Some("E4105"), "invalid module interface export")],
  )
}

///|
test "facade interface invalidation is selective while compilation is conservative" {
  let compile_facade = fn(selected_type : String, unrelated_type : String) {
    let compiled = compile_modules_for_test(
      (
        #|module Facade
        #|pub import Provider.{ selected }
      ),
      [
        "module Provider\npub let selected : \{selected_type} = " +
        (if selected_type == "I64" { "1" } else { "true" }) +
        "\npub let unrelated : \{unrelated_type} = " +
        (if unrelated_type == "I64" { "2" } else { "false" }),
      ],
    )
    guard compiled.modules is Some(modules) else {
      abort("expected compiled facade")
    }
    guard @module_compile.find_compiled_module(modules.modules, "Facade")
      is Some(facade) else {
      abort("expected facade module")
    }
    facade.to_interface_artifact()
  }
  let initial = compile_facade("I64", "I64")
  let unrelated_change = compile_facade("I64", "Bool")
  let selected_change = compile_facade("Bool", "Bool")
  assert_eq(
    (
      initial.interface_fingerprint == unrelated_change.interface_fingerprint,
      initial.module_fingerprint == unrelated_change.module_fingerprint,
      initial.interface_fingerprint == selected_change.interface_fingerprint,
    ),
    (true, false, false),
  )
}
