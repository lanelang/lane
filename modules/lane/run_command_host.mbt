///|
async fn execute_native_command(
  request : @wasm_abi.RunCommandRequest,
) -> (@wasm_abi.RunCommandHostStatus, @wasm_abi.RunCommandTermination?) {
  let environment : Map[String, String] = Map([])
  for entry in request.environment {
    environment[entry.key] = entry.value
  }
  try
    @process.run(
      request.executable,
      request.arguments,
      extra_env=environment,
      inherit_env=request.inherit_environment,
      cwd?=request.working_directory.map(directory => directory[:]),
    )
  catch {
    error if @async.is_cancellation_error(error) => raise error
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      (ExecutableNotFound, None)
    @os_error.OSError(_) as error if error.is_EACCES() =>
      (PermissionDenied, None)
    _ => (SystemFailure, None)
  } noraise {
    code if code < 0 => (Succeeded, Some(Signaled(signal=-code)))
    code => (Succeeded, Some(Exited(code~)))
  }
}

///|
async fn run_command_host_call(
  caller : @wasmoon_runtime.Caller,
  values : Array[@wasm_types.Value],
) -> Array[@wasm_types.Value] {
  guard values
    is [I32(request_address), I32(request_length), I32(response_address)] else {
    raise @wasmoon_runtime.TypeMismatch
  }
  guard caller.get_exported_memory("memory") is Some(memory) else {
    return [I32(@wasm_abi.RunCommandHostStatus::InvalidRequest.wire_code())]
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
    return [I32(@wasm_abi.RunCommandHostStatus::InvalidRequest.wire_code())]
  }
  let request_frame = memory.read_bytes(request_address, request_length)
  let request = match @wasm_abi.decode_run_command_request(request_frame) {
    Ok(request) => request
    Err(_) =>
      return [I32(@wasm_abi.RunCommandHostStatus::InvalidRequest.wire_code())]
  }
  let (status, termination) = execute_native_command(request)
  if termination is Some(termination) {
    let (tag, code) = termination.response_words()
    memory.store_i32(response_address, tag)
    memory.store_i32(response_address + 4, code)
  }
  [I32(status.wire_code())]
}

///|
fn configure_lane_runtime_v1(
  linker : @wasmoon_runtime.Linker,
) -> Unit raise @wasmoon_runtime.RuntimeError {
  let contract = @wasm_abi.LaneRuntimeV1Import::RunCommand.contract()
  linker.add_async_host_func_with_caller(
    contract.module_name,
    contract.field_name,
    run_command_host_call,
    func_type=@lane_wasm_runtime.project_core_import_func_type(contract),
  )
}
