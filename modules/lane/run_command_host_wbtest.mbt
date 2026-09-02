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
    stdin: b"",
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
  let (true_status, true_termination) = execute_native_command(
    native_command_request("/usr/bin/true", []),
  )
  assert_eq(true_status, Succeeded)
  assert_true(true_termination is Some({ termination: Exited(code=0), .. }))
  let (false_status, false_termination) = execute_native_command(
    native_command_request("/usr/bin/false", []),
  )
  assert_eq(false_status, Succeeded)
  assert_true(false_termination is Some({ termination: Exited(code=1), .. }))
}

///|
#cfg(not(platform="windows"))
async test "native run-command adapter never interprets an implicit shell command" {
  let (status, termination) = execute_native_command(
    native_command_request("true; false", []),
  )
  assert_eq(status, ExecutableNotFound)
  assert_true(termination is None)
}

///|
#cfg(not(platform="windows"))
async test "native run-command adapter applies working directory and environment" {
  let (status, termination) = execute_native_command({
    executable: "/bin/sh",
    arguments: [
      "-c", "[ \"$LANE_RUN_COMMAND_TEST\" = ready ] && [ \"$PWD\" = / ]",
    ],
    working_directory: Some("/"),
    environment: [{ key: "LANE_RUN_COMMAND_TEST", value: "ready", }],
    inherit_environment: false,
    stdin: b"",
  })
  assert_eq(status, Succeeded)
  assert_true(termination is Some({ termination: Exited(code=0), .. }))
}

///|
#cfg(not(platform="windows"))
async test "native run-command adapter writes stdin and captures both outputs" {
  let (status, output) = execute_native_command({
    executable: "/bin/sh",
    arguments: ["-c", "cat; printf stdout; printf stderr >&2"],
    working_directory: None,
    environment: [],
    inherit_environment: true,
    stdin: b"input",
  })
  assert_eq(status, Succeeded)
  guard output is Some({ termination, stdout, stderr, }) else {
    abort("expected captured command output")
  }
  assert_eq(
    (termination, stdout, stderr),
    (Exited(code=0), b"inputstdout", b"stderr"),
  )
}

///|
#cfg(platform="windows")
async test "native run-command adapter preserves Windows process termination" {
  let (status, termination) = execute_native_command(
    native_command_request("cmd.exe", ["/d", "/c", "exit", "7"]),
  )
  assert_eq(status, Succeeded)
  assert_true(termination is Some({ termination: Exited(code=7), .. }))
}
