///|
fn append_i32_le(bytes : Array[Byte], value : Int) -> Unit {
  let value = value.reinterpret_as_uint()
  bytes.push(value.to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 24).to_byte())
}

///|
fn run_command_fixture() -> Bytes {
  let bytes = []
  for value in [1, 68, 4, 36, 2, 88, 10, 52, 1] {
    append_i32_le(bytes, value)
  }
  for value in [72, 11, 83, 5] {
    append_i32_le(bytes, value)
  }
  for value in [98, 4, 102, 7] {
    append_i32_le(bytes, value)
  }
  for byte in b"toolhello world$HOME/tmp/buildMODErelease" {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
test "Lane Runtime V1 catalog owns the run-command contract" {
  debug_inspect(
    lane_runtime_v1_imports().map(LaneRuntimeV1Import::contract),
    content=(
      #|[
      #|  {
      #|    module_name: "lane_runtime_v1",
      #|    field_name: "run_command",
      #|    parameters: [GuestAddress, Direct(I32), GuestAddress],
      #|    result: Direct(I32),
      #|  },
      #|]
    ),
  )
}

///|
test "run-command request frame decodes structured process input" {
  assert_eq(
    decode_run_command_request(run_command_fixture()),
    Ok({
      executable: "tool",
      arguments: ["hello world", "$HOME"],
      working_directory: Some("/tmp/build"),
      environment: [{ key: "MODE", value: "release", }],
      inherit_environment: true,
    }),
  )
}

///|
test "run-command request frame rejects unknown flags" {
  let frame = run_command_fixture().to_array()
  frame[0] = b'\x02'
  assert_eq(
    decode_run_command_request(Bytes::from_array(frame)),
    Err(InvalidRunCommandFrame(detail="the request contains unknown flags")),
  )
}
