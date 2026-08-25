// Compiling against interface artifacts requires the Reachable Interface
// Closure, not every module an import was itself compiled against. A module
// that stays inside another module's implementation must not appear in a
// consumer's required inputs.

///|
fn interface_closure_artifact(
  source : String,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> @artifact.ModuleInterfaceArtifact {
  let result = compile_module_with_interfaces({
    root: { source_id: "input.lane", text: source, },
    interfaces,
  })
  guard result is Succeeded(modules, _) else {
    abort("expected the module to compile")
  }
  guard modules.artifact().modules is [compiled] else {
    abort("expected exactly one compiled module")
  }
  compiled.interface
}

///|
fn interface_closure_provider() -> @artifact.ModuleInterfaceArtifact {
  interface_closure_artifact(
    (
      #|module Z
      #|
      #|pub struct TypeZ {
      #|  field : I64
      #|}
      #|
      #|pub fn mk() -> TypeZ {
      #|  TypeZ::{ field: 7 }
      #|}
    ),
    [],
  )
}

///|
test "a module kept inside an implementation is not required downstream" {
  let z = interface_closure_provider()
  // `Y` imports `Z` but never mentions it in a public signature.
  let y = interface_closure_artifact(
    (
      #|module Y
      #|
      #|import Z
      #|
      #|pub fn total() -> I64 {
      #|  Z.mk().field
      #|}
    ),
    [z],
  )
  let main =
    #|module Main
    #|
    #|import Y.{ total }
    #|
    #|pub fn read() -> I64 {
    #|  total()
    #|}
  let result = compile_module_with_interfaces({
    root: { source_id: "Main.lane", text: main, },
    interfaces: [y],
  })
  assert_true(result is Succeeded(_, _))
  assert_eq(result.diagnostics(), [])
}

///|
test "a module named in a public signature is still required downstream" {
  let z = interface_closure_provider()
  // This time `Z` reaches the surface, so a consumer cannot resolve `Y`
  // without it.
  let y = interface_closure_artifact(
    (
      #|module Y
      #|
      #|import Z
      #|
      #|pub fn expose() -> Z.TypeZ {
      #|  Z.mk()
      #|}
    ),
    [z],
  )
  let main =
    #|module Main
    #|
    #|import Y.{ expose }
    #|
    #|pub fn read() -> I64 {
    #|  expose().field
    #|}
  let without_provider = compile_module_with_interfaces({
    root: { source_id: "Main.lane", text: main, },
    interfaces: [y],
  })
  assert_true(without_provider is Failed(_))
  let with_provider = compile_module_with_interfaces({
    root: { source_id: "Main.lane", text: main, },
    interfaces: [y, z],
  })
  assert_true(with_provider is Succeeded(_, _))
  assert_eq(with_provider.diagnostics(), [])
}

///|
test "a required interface is still checked against its recorded fingerprint" {
  let z = interface_closure_provider()
  let y = interface_closure_artifact(
    (
      #|module Y
      #|
      #|import Z
      #|
      #|pub fn expose() -> Z.TypeZ {
      #|  Z.mk()
      #|}
    ),
    [z],
  )
  // `Z` gains an export without `Y` being recompiled against it.
  let stale_z = interface_closure_artifact(
    (
      #|module Z
      #|
      #|pub struct TypeZ {
      #|  field : I64
      #|}
      #|
      #|pub fn mk() -> TypeZ {
      #|  TypeZ::{ field: 7 }
      #|}
      #|
      #|pub fn added() -> I64 {
      #|  1
      #|}
    ),
    [],
  )
  let main =
    #|module Main
    #|
    #|import Y.{ expose }
    #|
    #|pub fn read() -> I64 {
    #|  expose().field
    #|}
  let result = compile_module_with_interfaces({
    root: { source_id: "Main.lane", text: main, },
    interfaces: [y, stale_z],
  })
  assert_true(result is Failed(_))
}
