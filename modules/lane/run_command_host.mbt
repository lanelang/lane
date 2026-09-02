///|
priv struct CapturedCommand {
  termination : @wasm_abi.RunCommandTermination
  stdout : Bytes
  stderr : Bytes
}

///|
fn store_command_output(
  outputs : Map[Int, CapturedCommand],
  next_handle : Array[Int],
  output : CapturedCommand,
) -> Int {
  let handle = next_handle[0]
  next_handle[0] = handle + 1
  outputs[handle] = output
  handle
}

///|
async fn execute_native_command(
  request : @wasm_abi.RunCommandRequest,
) -> (@wasm_abi.RunCommandHostStatus, CapturedCommand?) {
  let environment : Map[String, String] = Map([])
  for entry in request.environment {
    environment[entry.key] = entry.value
  }
  try {
    let (child_stdin, stdin_writer) = @process.write_to_process()
    @async.with_task_group() <| group => {
      group.spawn_bg() <| () => {
        defer stdin_writer.close()
        stdin_writer.write(request.stdin)
      }
      let (code, stdout, stderr) = @process.collect_output(
        request.executable,
        request.arguments,
        extra_env=environment,
        inherit_env=request.inherit_environment,
        stdin=child_stdin,
        cwd?=request.working_directory.map(directory => directory[:]),
      )
      let termination = if code < 0 {
        @wasm_abi.RunCommandTermination::Signaled(signal=-code)
      } else {
        Exited(code~)
      }
      { termination, stdout: stdout.binary(), stderr: stderr.binary(), }
    }
  } catch {
    error if @async.is_cancellation_error(error) => raise error
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      (ExecutableNotFound, None)
    @os_error.OSError(_) as error if error.is_EACCES() =>
      (PermissionDenied, None)
    _ => (SystemFailure, None)
  } noraise {
    output => (Succeeded, Some(output))
  }
}

///|
async fn run_command_host_call(
  outputs : Map[Int, CapturedCommand],
  next_handle : Array[Int],
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
  let (status, output) = execute_native_command(request)
  if output is Some(output) {
    let (tag, code) = output.termination.response_words()
    let handle = store_command_output(outputs, next_handle, output)
    memory.store_i32(response_address, tag)
    memory.store_i32(response_address + 4, code)
    memory.store_i32(response_address + 8, handle)
    memory.store_i32(response_address + 12, output.stdout.length())
    memory.store_i32(response_address + 16, output.stderr.length())
  }
  [I32(status.wire_code())]
}

///|
fn take_command_output_host_call(
  outputs : Map[Int, CapturedCommand],
  caller : @wasmoon_runtime.Caller,
  values : Array[@wasm_types.Value],
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  guard values is [I32(handle), I32(address), I32(length)] else {
    raise TypeMismatch
  }
  guard caller.get_exported_memory("memory") is Some(memory) else {
    return [I32(@wasm_abi.RunCommandHostStatus::InvalidRequest.wire_code())]
  }
  guard outputs.get(handle) is Some(output) else {
    return [I32(@wasm_abi.RunCommandHostStatus::InvalidRequest.wire_code())]
  }
  let expected_length = output.stdout.length() + output.stderr.length()
  let memory_length = memory.byte_len()
  if address < 0 ||
    length != expected_length ||
    address.to_int64() > memory_length ||
    length.to_int64() > memory_length - address.to_int64() {
    return [I32(@wasm_abi.RunCommandHostStatus::InvalidRequest.wire_code())]
  }
  for index, byte in output.stdout {
    memory.store_byte(address + index, byte)
  }
  for index, byte in output.stderr {
    memory.store_byte(address + output.stdout.length() + index, byte)
  }
  outputs.remove(handle)
  [I32(@wasm_abi.RunCommandHostStatus::Succeeded.wire_code())]
}

///|
fn configure_lane_runtime_v1(
  linker : @wasmoon_runtime.Linker,
) -> Unit raise @wasmoon_runtime.RuntimeError {
  let outputs : Map[Int, CapturedCommand] = Map([])
  let next_handle = [1]
  let run_contract = @wasm_abi.LaneRuntimeV1Import::RunCommand.contract()
  linker.add_async_host_func_with_caller(
    run_contract.module_name,
    run_contract.field_name,
    async fn(caller, values) {
      run_command_host_call(outputs, next_handle, caller, values)
    },
    func_type=@lane_wasm_runtime.project_core_import_func_type(run_contract),
  )
  let output_contract = @wasm_abi.LaneRuntimeV1Import::TakeCommandOutput.contract()
  linker.add_host_func_with_caller(
    output_contract.module_name,
    output_contract.field_name,
    (caller, values) => take_command_output_host_call(outputs, caller, values),
    func_type=@lane_wasm_runtime.project_core_import_func_type(output_contract),
  )
}
