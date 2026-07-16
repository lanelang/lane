///|
pub(all) suberror WasmLoadError {
  RuntimeImportResolution(error~ : @loisvm_runtime.RuntimeImportResolutionError)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub struct LoadedImage {
  wasm_module : @wasm_types.Module
  imports : Array[(@bytecode.RuntimeImport, @loisvm_runtime.RuntimeBinding)]
}

///|
pub struct ExecutionInstance {
  store : @wasmoon_runtime.Store
  instance : @wasmoon_runtime.ModuleInstance
  priv failure : RuntimeFailureState
  priv host_objects : WasmHostObjects
  mut ready : Bool
}

///|
pub fn load(
  image : @bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
) -> Result[LoadedImage, WasmLoadError] {
  let imports : Array[(@bytecode.RuntimeImport, @loisvm_runtime.RuntimeBinding)] = []
  for entry in image.functions {
    if entry is RuntimeImport(import_) {
      let binding = match
        registry.resolve(
          import_.symbol,
          expected_abi_major=import_.abi_major,
          expected_parameters=import_.parameters,
          expected_result=import_.result,
        ) {
        Ok(binding) => binding
        Err(error) => return Err(RuntimeImportResolution(error~))
      }
      imports.push((import_, binding))
    }
  }
  let compiled = compile(image)
  match compiled {
    Ok(wasm_module) => Ok({ wasm_module, imports })
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
  let failure : RuntimeFailureState = { error: None }
  let runtime = @loisvm_runtime.ExecutionRuntime::new(config~)
  let host_objects = WasmHostObjects::new(runtime)
  let runtime_context = runtime.context()
  if self.imports.any(resolved => runtime_import_uses_host_objects(resolved.0)) {
    let release_host_object : (
      @wasmoon_runtime.Caller,
      Array[@wasm_types.Value],
    ) -> Array[@wasm_types.Value] raise @wasmoon_runtime.RuntimeError = (
      _caller,
      values,
    ) => {
      guard values is [I64(token)] else { raise TypeMismatch }
      host_objects.release(token) catch {
        error => {
          failure.error = Some(
            InternalRuntimeFailure(
              detail=wasm_host_object_failure_detail(error),
            ),
          )
          raise TypeMismatch
        }
      }
      []
    }
    let address = store.alloc_host_func_with_caller(release_host_object, func_type={
      params: [I64],
      results: [],
    })
    imports.add_func("lane.runtime.internal.v1", "host_object.release", address)
  }
  for resolved in self.imports {
    let descriptor = resolved.0
    let binding = resolved.1
    let host_function : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
      @wasm_types.Value,
    ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
      invoke_runtime_binding(
        caller, binding, failure, runtime, runtime_context, host_objects, values,
      )
    }
    let address = store.alloc_host_func_with_caller(host_function, func_type={
      params: @compiler.physical_runtime_parameters_for_import(descriptor),
      results: @compiler.runtime_results_for_import(descriptor),
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
  { store, instance, failure, host_objects, ready: true }
}

///|
pub fn ExecutionInstance::execute(
  self : ExecutionInstance,
  cancel? : (() -> Bool)? = None,
) -> Result[Unit, @loisvm_runtime.ExecutionError] {
  ignore(self.host_objects)
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
      } else if self.failure.error is Some(error) {
        Err(error)
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
