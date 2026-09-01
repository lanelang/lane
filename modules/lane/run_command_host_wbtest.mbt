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
#cfg(not(platform="windows"))
test "native run-command adapter preserves process termination" {
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
test "native run-command adapter never interprets an implicit shell command" {
  assert_eq(
    execute_native_command(native_command_request("true; false", [])),
    (ExecutableNotFound, None),
  )
}

///|
#cfg(not(platform="windows"))
test "native run-command adapter applies working directory and environment" {
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
test "native run-command adapter preserves Windows process termination" {
  assert_eq(
    execute_native_command(
      native_command_request("cmd.exe", ["/d", "/c", "exit", "7"]),
    ),
    (Succeeded, Some(Exited(code=7))),
  )
}
