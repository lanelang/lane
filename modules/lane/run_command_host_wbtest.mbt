///|
fn native_command_request(
  executable : String,
  arguments : Array[String],
) -> @wasm_abi.RunCommandRequest {
  {
    executable,
    arguments,
    working_directory: None,
    environment: [],
    inherit_environment: true,
  }
}

///|
fn async_run_command_probe() -> Bytes {
  let module_ = @wat.parse(
    (
      #|(module
      #|  (type $run-command (func (param i32 i32 i32) (result i32)))
      #|  (import "lane_runtime_v1" "run_command" (func $run-command (type $run-command)))
      #|  (memory (export "memory") 1)
      #|  (func (export "_start")
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.const 0
      #|    call $run-command
      #|    i32.const 1
      #|    i32.ne
      #|    if unreachable end))
    ),
  ) catch {
    error => abort(@wat.format_wat_error(error, "async run-command probe"))
  }
  Bytes::from_iter(
    @wasm_encoder.encode(module_).iter().map(value => value.to_byte()),
  )
}

///|
async test "lane runtime executes its async host import in both backends" {
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    let loaded = match
      @lane_wasm_runtime.load_wasm(
        async_run_command_probe(),
        mode~,
        configure_host=configure_lane_runtime_v1,
      ) {
      Ok(loaded) => loaded
      Err(error) => abort("load failed: \{Repr(error)}")
    }
    assert_eq(loaded.execute_async(), Ok(Returned))
  }
}

///|
#cfg(not(platform="windows"))
async test "native run-command adapter preserves process termination" {
  assert_eq(
    execute_native_command(native_command_request("/usr/bin/true", [])),
    (Succeeded, Some(Exited(code=0))),
  )
  assert_eq(
    execute_native_command(native_command_request("/usr/bin/false", [])),
    (Succeeded, Some(Exited(code=1))),
  )
}

///|
#cfg(not(platform="windows"))
async test "native run-command adapter never interprets an implicit shell command" {
  assert_eq(
    execute_native_command(native_command_request("true; false", [])),
    (ExecutableNotFound, None),
  )
}

///|
#cfg(not(platform="windows"))
async test "native run-command adapter applies working directory and environment" {
  assert_eq(
    execute_native_command({
      executable: "/bin/sh",
      arguments: [
        "-c", "[ \"$LANE_RUN_COMMAND_TEST\" = ready ] && [ \"$PWD\" = / ]",
      ],
      working_directory: Some("/"),
      environment: [{ key: "LANE_RUN_COMMAND_TEST", value: "ready", }],
      inherit_environment: false,
    }),
    (Succeeded, Some(Exited(code=0))),
  )
}

///|
#cfg(platform="windows")
async test "native run-command adapter preserves Windows process termination" {
  assert_eq(
    execute_native_command(
      native_command_request("cmd.exe", ["/d", "/c", "exit", "7"]),
    ),
    (Succeeded, Some(Exited(code=7))),
  )
}
