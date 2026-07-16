///|
struct RuntimeFailureState {
  mut error : @loisvm_runtime.ExecutionError?
}

///|
fn invoke_runtime_binding(
  caller : @wasmoon_runtime.Caller,
  binding : @loisvm_runtime.RuntimeBinding,
  failure : RuntimeFailureState,
  runtime : @loisvm_runtime.ExecutionRuntime,
  runtime_context : @loisvm_runtime.RuntimeContext,
  host_objects : WasmHostObjects,
  values : Array[@wasm_types.Value],
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  let arguments : Array[@loisvm_runtime.HostValue] = []
  let mut value_index = 0
  for kind in binding.parameters() {
    match kind {
      Unit => arguments.push(Unit)
      Bool => {
        guard values[value_index] is I32(value) else { raise TypeMismatch }
        arguments.push(Bool(value != 0))
        value_index += 1
      }
      Int => {
        guard values[value_index] is I64(value) else { raise TypeMismatch }
        arguments.push(Int(value))
        value_index += 1
      }
      Double => {
        guard values[value_index] is F64(value) else { raise TypeMismatch }
        arguments.push(Double(value))
        value_index += 1
      }
      String => {
        guard values[value_index] is I32(pointer) else { raise TypeMismatch }
        guard values[value_index + 1] is I32(length) else { raise TypeMismatch }
        let memory = match caller.get_exported_memory("lane.memory") {
          Some(value) => value
          None => raise UndefinedElement
        }
        for index in 0..<length {
          let byte = memory.read_byte(pointer + index)
          if byte.to_int() > 0x7F {
            raise TypeMismatch
          }
        }
        arguments.push(
          BorrowedString(
            @loisvm_runtime.HostStringView::new(length~, read_byte=index => {
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
          caller.instance().global_addrs[@compiler.failure_code_global()],
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
          caller.instance().global_addrs[@compiler.runtime_import_failed_global()],
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
fn runtime_import_uses_host_objects(import_ : @bytecode.RuntimeImport) -> Bool {
  import_.result is Opaque || import_.parameters.any(kind => kind is Opaque)
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
  error : @loisvm_runtime.ExecutionError,
) -> Unit raise @wasmoon_runtime.RuntimeError {
  failure.error = Some(error)
  caller
  .store()
  .get_global(
    caller.instance().global_addrs[@compiler.runtime_import_failed_global()],
  )
  .set(I32(1))
}

///|
fn default_runtime_result(
  kind : @loisvm_runtime.RuntimeValueKind,
) -> Array[@wasm_types.Value] {
  match kind {
    Unit => []
    Bool => [I32(0)]
    Int => [I64(0L)]
    Double => [F64(0.0)]
    String => [I32(0)]
    Opaque => [I32(0)]
  }
}

///|
fn host_result_to_wasm(
  caller : @wasmoon_runtime.Caller,
  symbol : String,
  kind : @loisvm_runtime.RuntimeValueKind,
  value : @loisvm_runtime.HostValue,
  failure : RuntimeFailureState,
  runtime : @loisvm_runtime.ExecutionRuntime,
  host_objects : WasmHostObjects,
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  match (kind, value) {
    (Unit, Unit) => []
    (Bool, Bool(value)) => [I32(if value { 1 } else { 0 })]
    (Int, Int(value)) => [I64(value)]
    (Double, Double(value)) => [F64(value)]
    (String, String(value)) => [I32(copy_host_string(caller, value))]
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
  value : String,
) -> Int raise @wasmoon_runtime.RuntimeError {
  let bytes = @utf8.encode(value)
  for byte in bytes {
    if byte.to_int() > 0x7F {
      raise TypeMismatch
    }
  }
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
