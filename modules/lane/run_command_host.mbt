///|
let native_command_exited = 0

///|
let native_command_signaled = 1

///|
let native_command_not_found = 2

///|
let native_command_permission_denied = 3

///|
#borrow(executable, arguments, working_directory, environment_keys, environment_values, outcome)
extern "C" fn run_command_native(
  executable : String,
  arguments : FixedArray[String],
  working_directory : String,
  has_working_directory : Bool,
  environment_keys : FixedArray[String],
  environment_values : FixedArray[String],
  inherit_environment : Bool,
  outcome : FixedArray[Int],
) -> Unit = "lane_run_command"

///|
fn execute_native_command(
  request : @wasm_abi.RunCommandRequest,
) -> (@wasm_abi.RunCommandHostStatus, @wasm_abi.RunCommandTermination?) {
  let arguments = FixedArray::from_array(request.arguments)
  let environment_keys = FixedArray::from_array(
    request.environment.map(entry => entry.key),
  )
  let environment_values = FixedArray::from_array(
    request.environment.map(entry => entry.value),
  )
  let (working_directory, has_working_directory) = match
    request.working_directory {
    Some(directory) => (directory, true)
    None => ("", false)
  }
  let outcome = FixedArray::make(2, 0)
  run_command_native(
    request.executable,
    arguments,
    working_directory,
    has_working_directory,
    environment_keys,
    environment_values,
    request.inherit_environment,
    outcome,
  )
  match outcome[0] {
    category if category == native_command_exited =>
      (Succeeded, Some(Exited(code=outcome[1])))
    category if category == native_command_signaled =>
      (Succeeded, Some(Signaled(signal=outcome[1])))
    category if category == native_command_not_found =>
      (ExecutableNotFound, None)
    category if category == native_command_permission_denied =>
      (PermissionDenied, None)
    _ => (SystemFailure, None)
  }
}

///|
fn run_command_host_call(
  caller : @wasmoon_runtime.Caller,
  values : Array[@wasm_types.Value],
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  guard values
    is [I32(request_address), I32(request_length), I32(response_address)] else {
    raise TypeMismatch
  }
  guard caller.get_exported_memory("memory") is Some(memory) else {
    return [I32(1)]
  }
  let memory_length = memory.byte_len()
  if request_address < 0 ||
    request_length < 0 ||
    request_address.to_int64() > memory_length ||
    request_length.to_int64() > memory_length - request_address.to_int64() ||
    response_address < 0 ||
    response_address.to_int64() > memory_length ||
    @wasm_abi.run_command_response_size().to_int64() >
    memory_length - response_address.to_int64() {
    return [I32(1)]
  }
  let request_frame = memory.read_bytes(request_address, request_length)
  let request = match @wasm_abi.decode_run_command_request(request_frame) {
    Ok(request) => request
    Err(_) => return [I32(1)]
  }
  let (status, termination) = execute_native_command(request)
  match termination {
    Some(Exited(code~)) => {
      memory.store_i32(response_address, 0)
      memory.store_i32(response_address + 4, code)
    }
    Some(Signaled(signal~)) => {
      memory.store_i32(response_address, 1)
      memory.store_i32(response_address + 4, signal)
    }
    None => ()
  }
  [
    I32(
      match status {
        Succeeded => 0
        InvalidRequest => 1
        ExecutableNotFound => 2
        PermissionDenied => 3
        SystemFailure => 4
      },
    ),
  ]
}

///|
fn configure_lane_runtime_v1(
  linker : @wasmoon_runtime.Linker,
) -> Unit raise @wasmoon_runtime.RuntimeError {
  linker.add_host_func_with_caller(
    "lane_runtime_v1",
    "run_command",
    run_command_host_call,
    func_type={ params: [I32, I32, I32], results: [I32], },
  )
}
