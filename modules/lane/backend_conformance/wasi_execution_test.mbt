///|
fn compile_wasi_fd_write_fixture() -> @physical.PhysicalProgram raise {
  compile_effect_conformance_image(
    (
      #|module Main
      #|
      #|import Basic.Io.{ println }
      #|pub fn main() -> Unit ! Io {
      #|  println("hello")
      #|}
    ),
  )
}

///|
fn execute_wasi_fd_write_fixture(
  mode : @lane_wasm_runtime.ExecutionMode,
) -> (Result[Unit, @lane_runtime.ExecutionError], Bytes) raise {
  let output : Array[Byte] = []
  let loaded = match
    load_physical(
      compile_wasi_fd_write_fixture(),
      mode~,
      wasi_stdout=Some(bytes => output.append(bytes.to_array())),
    ) {
    Ok(loaded) => loaded
    Err(error) => fail("WASI fixture load failed: \{Repr(error)}")
  }
  (loaded.execute(), Bytes::from_array(output))
}

///|
test "Basic's narrow fd_write bridge reaches WASI in both engines" {
  assert_eq(
    [
      execute_wasi_fd_write_fixture(Interpreter),
      execute_wasi_fd_write_fixture(Jit),
    ],
    [(Ok(()), b"hello\n"), (Ok(()), b"hello\n")],
  )
}
