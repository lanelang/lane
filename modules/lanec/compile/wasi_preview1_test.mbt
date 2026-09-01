///|
fn compile_single_module_artifact(
  source_id : String,
  source : String,
  interfaces : Array[@artifact.ModuleInterfaceArtifact],
) -> @artifact.CompiledModuleArtifact {
  let outcome = compile_module_with_interfaces({
    root: { source_id, text: source, },
    interfaces,
  })
  guard outcome is Succeeded(modules, _) else {
    abort("module compilation failed: \{Repr(outcome.diagnostics())}")
  }
  guard modules.artifact().modules is [module_] else {
    abort("expected exactly one compiled module")
  }
  module_
}

///|
test "selective WASI import does not require unrelated canonical ABI providers" {
  let abi = compile_single_module_artifact(
    "abi",
    (
      #|module Basic.Wasm.Abi
      #|pub struct WasmAddress {
      #|  storage : ByteBuffer
      #|  offset : I32
      #|}
    ),
    [],
  )
  let platform = compile_single_module_artifact(
    "platform",
    (
      #|module Basic.Platform.Wasip1
      #|import Basic.Wasm.Abi.{ WasmAddress }
      #|pub let fd_write : (I32, WasmAddress, I32, WasmAddress) -> I32 ! Io =
      #|  extern("wasi_snapshot_preview1", "fd_write")
      #|pub let sched_yield : () -> I32 ! Io =
      #|  extern("wasi_snapshot_preview1", "sched_yield")
    ),
    [abi.interface],
  )
  let main = compile_single_module_artifact(
    "main",
    (
      #|module Main
      #|import Basic.Platform.Wasip1.{ sched_yield }
      #|pub fn main() -> Unit ! Io {
      #|  let _errno = sched_yield()
      #|  ()
      #|}
    ),
    [abi.interface, platform.interface],
  )
  let outcome = link_module_objects([abi.object, platform.object, main.object])
  guard outcome is Succeeded(_) else {
    fail("module-object linking failed: \{Repr(outcome.diagnostics())}")
  }
}
