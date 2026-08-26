///|
struct RuntimeFailureState {
  mut error : @lane_runtime.ExecutionError?
}

///|
fn invoke_runtime_binding(
  caller : @wasmoon_runtime.Caller,
  binding : @lane_runtime.RuntimeBinding,
  failure : RuntimeFailureState,
  runtime : @lane_runtime.ExecutionRuntime,
  runtime_context : @lane_runtime.RuntimeContext,
  host_objects : WasmHostObjects,
  control_globals : RuntimeControlGlobals,
  values : Array[@wasm_types.Value],
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  let arguments : Array[@lane_runtime.HostValue] = []
  let mut value_index = 0
  for kind in binding.parameters() {
    match kind {
      Unit => arguments.push(Unit)
      Bool => {
        guard values[value_index] is I32(value) else { raise TypeMismatch }
        arguments.push(Bool(value != 0))
        value_index += 1
      }
      I64 => {
        guard values[value_index] is I64(value) else { raise TypeMismatch }
        arguments.push(I64(value))
        value_index += 1
      }
      F64 => {
        guard values[value_index] is F64(value) else { raise TypeMismatch }
        arguments.push(F64(value))
        value_index += 1
      }
      F32 => {
        guard values[value_index] is F32(value) else { raise TypeMismatch }
        arguments.push(F32(value))
        value_index += 1
      }
      String => {
        guard values[value_index] is I32(pointer) else { raise TypeMismatch }
        guard values[value_index + 1] is I32(length) else { raise TypeMismatch }
        let memory = match caller.get_exported_memory("lane.memory") {
          Some(value) => value
          None => raise UndefinedElement
        }
        arguments.push(
          BorrowedString(
            @lane_runtime.HostStringView::new(length~, read_byte=index => {
              memory.read_byte(pointer + index)
            }),
          ),
        )
        value_index += 2
      }
      Opaque => {
        guard values[value_index] is I64(token) else { raise TypeMismatch }
        let borrowed = host_objects.borrow(token) catch {
          error => {
            record_runtime_failure(
              caller,
              failure,
              InternalRuntimeFailure(
                detail=wasm_host_object_failure_detail(error),
              ),
              control_globals,
            )
            return default_runtime_result(binding.result())
          }
        }
        arguments.push(BorrowedOpaque(borrowed))
        value_index += 1
      }
    }
  }
  let result = try binding.call(runtime_context, arguments) catch {
    Failure(message~) => {
      record_runtime_failure(
        caller,
        failure,
        RuntimeImportFailure(symbol=binding.symbol(), message~),
        control_globals,
      )
      return default_runtime_result(binding.result())
    }
  } noraise {
    value => value
  }
  try
    host_result_to_wasm(
      caller,
      binding.symbol(),
      binding.result(),
      result,
      failure,
      runtime,
      host_objects,
    )
  catch {
    error => {
      let failure_code = caller
        .store()
        .get_global(
          caller.instance().global_addrs[control_globals.failure_code],
        )
        .get() catch {
          _ => I32(0)
        }
      if failure_code is I32(0) {
        if failure.error is None {
          failure.error = Some(
            RuntimeImportFailure(
              symbol=binding.symbol(),
              message=error.to_string(),
            ),
          )
        }
        caller
        .store()
        .get_global(
          caller.instance().global_addrs[control_globals.runtime_import_failed],
        )
        .set(I32(1))
      }
      default_runtime_result(binding.result())
    }
  } noraise {
    value => value
  }
}

///|
fn wasm_host_object_failure_detail(failure : WasmHostObjectFailure) -> String {
  match failure {
    InvalidHostObjectToken(detail~) | HostObjectRuntimeFailure(detail~) =>
      detail
  }
}

///|
fn record_runtime_failure(
  caller : @wasmoon_runtime.Caller,
  failure : RuntimeFailureState,
  error : @lane_runtime.ExecutionError,
  control_globals : RuntimeControlGlobals,
) -> Unit raise @wasmoon_runtime.RuntimeError {
  failure.error = Some(error)
  caller
  .store()
  .get_global(
    caller.instance().global_addrs[control_globals.runtime_import_failed],
  )
  .set(I32(1))
}

///|
fn default_runtime_result(
  kind : @lane_runtime.RuntimeValueKind,
) -> Array[@wasm_types.Value] {
  match kind {
    Unit => []
    Bool => [I32(0)]
    I64 => [I64(0L)]
    F64 => [F64(0.0)]
    F32 => [F32(0.0F)]
    String => [I32(0)]
    Opaque => [I32(0)]
  }
}

///|
fn host_result_to_wasm(
  caller : @wasmoon_runtime.Caller,
  symbol : String,
  kind : @lane_runtime.RuntimeValueKind,
  value : @lane_runtime.HostValue,
  failure : RuntimeFailureState,
  runtime : @lane_runtime.ExecutionRuntime,
  host_objects : WasmHostObjects,
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  match (kind, value) {
    (Unit, Unit) => []
    (Bool, Bool(value)) => [I32(if value { 1 } else { 0 })]
    (I64, I64(value)) => [I64(value)]
    (F64, F64(value)) => [F64(value)]
    (F32, F32(value)) => [F32(value)]
    (String, String(bytes)) => {
      ignore(
        @utf8.decode(bytes) catch {
          _ => {
            failure.error = Some(
              RuntimeImportFailure(
                symbol~,
                message="runtime import returned invalid UTF-8 String",
              ),
            )
            raise TypeMismatch
          }
        },
      )
      [I32(copy_host_string(caller, bytes))]
    }
    (Opaque, OwnedOpaque(object)) => {
      let adopted : Result[Int, @wasmoon_runtime.RuntimeError] = runtime.adopt_host_object(
        object,
        handle => {
          let token = host_objects.insert(handle)
          let allocated : Result[Int, @wasmoon_runtime.RuntimeError] = Ok(
            copy_host_object(caller, token),
          ) catch {
            error => Err(error)
          }
          match allocated {
            Ok(reference) => Ok(reference)
            Err(error) => {
              host_objects.rollback(token) catch {
                rollback_error => {
                  failure.error = Some(
                    InternalRuntimeFailure(
                      detail=wasm_host_object_failure_detail(rollback_error),
                    ),
                  )
                  return Err(TypeMismatch)
                }
              }
              Err(error)
            }
          }
        },
      ) catch {
        HostObjectLimitExceeded => {
          failure.error = Some(ExecutionResourceLimit(kind=HostObjects))
          raise TypeMismatch
        }
        InvalidOwnedResult(detail~) => {
          failure.error = Some(RuntimeImportFailure(symbol~, message=detail))
          raise TypeMismatch
        }
        InvalidHostObjectHandle(detail~) => {
          failure.error = Some(InternalRuntimeFailure(detail~))
          raise TypeMismatch
        }
      }
      match adopted {
        Ok(reference) => [I32(reference)]
        Err(error) => raise error
      }
    }
    _ => raise TypeMismatch
  }
}

///|
fn copy_host_object(
  caller : @wasmoon_runtime.Caller,
  token : Int64,
) -> Int raise @wasmoon_runtime.RuntimeError {
  let instance = caller.instance()
  let mut service_index = -1
  for export_ in instance.exports {
    if export_.name == "lane.runtime.host_object.new" &&
      export_.desc is Func(index) {
      service_index = index
    }
  }
  if service_index < 0 {
    raise UndefinedElement
  }
  let allocated = @executor.call_func_by_index(
    caller.store(),
    instance,
    service_index,
    [I64(token)],
  )
  guard allocated is [I32(reference)] else { raise TypeMismatch }
  reference
}

///|
fn copy_host_string(
  caller : @wasmoon_runtime.Caller,
  bytes : Bytes,
) -> Int raise @wasmoon_runtime.RuntimeError {
  let instance = caller.instance()
  let mut service_index = -1
  for export_ in instance.exports {
    if export_.name == "lane.runtime.string.new" && export_.desc is Func(index) {
      service_index = index
    }
  }
  if service_index < 0 {
    raise UndefinedElement
  }
  let allocated = @executor.call_func_by_index(
    caller.store(),
    instance,
    service_index,
    [I32(bytes.length())],
  )
  guard allocated is [I32(reference)] else { raise TypeMismatch }
  let memory = match caller.get_exported_memory("lane.memory") {
    Some(value) => value
    None => raise UndefinedElement
  }
  for index, byte in bytes {
    memory.store_byte(reference + 12 + index, byte)
  }
  reference
}
