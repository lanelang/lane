///|
pub(all) suberror WasmLoadError {
  RuntimeImportResolution(error~ : @loisvm_runtime.RuntimeImportResolutionError)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
struct ImportFailureState {
  mut symbol : String?
  mut message : String?
}

///|
pub struct LoadedImage {
  wasm_module : @wasm_types.Module
  bindings : Array[@loisvm_runtime.RuntimeBinding]
}

///|
pub struct ExecutionInstance {
  store : @wasmoon_runtime.Store
  instance : @wasmoon_runtime.ModuleInstance
  failure : ImportFailureState
  mut ready : Bool
}

///|
pub fn load(
  image : @bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
) -> Result[LoadedImage, WasmLoadError] {
  let bindings : Array[@loisvm_runtime.RuntimeBinding] = []
  for entry in image.functions {
    if entry is RuntimeImport(import_) {
      let binding = match
        registry.resolve(
          import_.symbol,
          expected_abi_major=import_.abi_major,
          expected_arity=import_.user_arity,
        ) {
        Ok(binding) => binding
        Err(error) => return Err(RuntimeImportResolution(error~))
      }
      bindings.push(binding)
    }
  }
  let compiled = compile_with_runtime_bindings(image, bindings)
  match compiled {
    Ok(wasm_module) => Ok({ wasm_module, bindings })
    Err(error) => Err(BackendCompileFailure(detail=to_repr(error).to_string()))
  }
}

///|
pub fn LoadedImage::wasm_module(self : LoadedImage) -> @wasm_types.Module {
  self.wasm_module
}

///|
fn encode_execution_limit(limit : Int?) -> Int {
  match limit {
    None => -1
    Some(value) if value > 0 => value
    Some(_) => 0
  }
}

///|
pub fn LoadedImage::new_instance(
  self : LoadedImage,
  config? : @loisvm_runtime.ExecutionConfig = @loisvm_runtime.ExecutionConfig::defaults(),
) -> Result[ExecutionInstance, @loisvm_runtime.ExecutionError] {
  Ok(self.new_instance_or_raise(config)) catch {
    error => Err(EngineTrap(detail=error.to_string()))
  }
}

///|
fn LoadedImage::new_instance_or_raise(
  self : LoadedImage,
  config : @loisvm_runtime.ExecutionConfig,
) -> ExecutionInstance raise @wasmoon_runtime.RuntimeError {
  let store = @wasmoon_runtime.Store::Store()
  let imports = @wasmoon_runtime.Imports::Imports()
  let failure : ImportFailureState = { symbol: None, message: None }
  let runtime_context = @loisvm_runtime.RuntimeContext::new()
  for binding in self.bindings {
    let host_function : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
      @wasm_types.Value,
    ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
      invoke_runtime_binding(caller, binding, failure, runtime_context, values)
    }
    let address = store.alloc_host_func_with_caller(host_function, func_type={
      params: @compiler.physical_runtime_parameters_for_binding(binding),
      results: @compiler.runtime_results_for_binding(binding),
    })
    imports.add_func("lane.runtime.v1", binding.symbol(), address)
  }
  let instance = @executor.instantiate_module_with_imports(
    store,
    self.wasm_module,
    imports,
  )
  store
  .get_global(instance.global_addrs[@compiler.max_live_heap_bytes_global()])
  .set(I32(encode_execution_limit(config.max_live_heap_bytes)))
  store
  .get_global(instance.global_addrs[@compiler.max_call_depth_global()])
  .set(I32(encode_execution_limit(config.max_call_depth)))
  { store, instance, failure, ready: true }
}

///|
pub fn ExecutionInstance::execute(
  self : ExecutionInstance,
  cancel? : (() -> Bool)? = None,
) -> Result[Unit, @loisvm_runtime.ExecutionError] {
  if !self.ready {
    return Err(InstanceNotReady)
  }
  self.ready = false
  let result = @executor.call_exported_func_with_options(
    self.store,
    self.instance,
    "lane.entry",
    [],
    options=CallExportOptions(cancel~),
  )
  match result {
    Ok(_) => Ok(())
    Err(failure) =>
      if failure.kind is Cancelled {
        Err(Interrupted)
      } else if self.failure.symbol is Some(symbol) &&
        self.failure.message is Some(message) {
        Err(RuntimeImportFailure(symbol~, message~))
      } else {
        let failure_code = self.store
          .get_global(
            self.instance.global_addrs[@compiler.failure_code_global()],
          )
          .get() catch {
            _ => I32(0)
          }
        match failure_code {
          I32(1) => Err(ExecutionResourceLimit(kind=CallDepth))
          I32(2) => Err(ExecutionResourceLimit(kind=LiveHeapBytes))
          I32(3) => Err(EngineTrap(detail="Wasm allocation or ARC failure"))
          I32(4) =>
            Err(
              InternalRuntimeFailure(
                detail="Wasm instance-global lifecycle failure",
              ),
            )
          _ => Err(EngineTrap(detail=failure.message))
        }
      }
  }
}

///|
fn invoke_runtime_binding(
  caller : @wasmoon_runtime.Caller,
  binding : @loisvm_runtime.RuntimeBinding,
  failure : ImportFailureState,
  runtime_context : @loisvm_runtime.RuntimeContext,
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
    }
  }
  let result = try binding.call(runtime_context, arguments) catch {
    Failure(message~) => {
      failure.symbol = Some(binding.symbol())
      failure.message = Some(message)
      caller
      .store()
      .get_global(
        caller.instance().global_addrs[@compiler.runtime_import_failed_global()],
      )
      .set(I32(1))
      return default_runtime_result(binding.result())
    }
  } noraise {
    value => value
  }
  try host_result_to_wasm(caller, binding.result(), result) catch {
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
        failure.symbol = Some(binding.symbol())
        failure.message = Some(error.to_string())
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
fn default_runtime_result(
  kind : @loisvm_runtime.PrimitiveKind,
) -> Array[@wasm_types.Value] {
  match kind {
    Unit => []
    Bool => [I32(0)]
    Int => [I64(0L)]
    Double => [F64(0.0)]
    String => [I32(0)]
  }
}

///|
fn host_result_to_wasm(
  caller : @wasmoon_runtime.Caller,
  kind : @loisvm_runtime.PrimitiveKind,
  value : @loisvm_runtime.HostValue,
) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError {
  match (kind, value) {
    (Unit, Unit) => []
    (Bool, Bool(value)) => [I32(if value { 1 } else { 0 })]
    (Int, Int(value)) => [I64(value)]
    (Double, Double(value)) => [F64(value)]
    (String, String(value)) => [I32(copy_host_string(caller, value))]
    _ => raise TypeMismatch
  }
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
