///|
pub(all) suberror WasmLoadError {
  RuntimeImportResolution(error~ : @loisvm_runtime.RuntimeImportResolutionError)
  BackendCompileFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub(all) enum ExecutionMode {
  Jit
  Interpreter
} derive(Debug, Eq)

///|
enum LoadedExecutionBackend {
  Jit(@wasmoon_jit.LoadedArtifact)
  Interpreter
}

///|
enum InstanceExecutionBackend {
  Jit(@wasmoon_jit_runtime.JITModule, @wasmoon_wast.JITModuleContext)
  Interpreter
}

///|
pub struct LoadedImage {
  wasm_module : @wasm_types.Module
  imports : Array[(@bytecode.RuntimeImport, @loisvm_runtime.RuntimeBinding)]
  priv backend : LoadedExecutionBackend
}

///|
pub struct ExecutionInstance {
  store : @wasmoon_runtime.Store
  instance : @wasmoon_runtime.ModuleInstance
  priv backend : InstanceExecutionBackend
  priv failure : RuntimeFailureState
  priv host_objects : WasmHostObjects
  mut ready : Bool
}

///|
pub fn load(
  image : @bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
  mode? : ExecutionMode = Jit,
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
    Ok(wasm_module) => {
      let backend = match mode {
        Jit =>
          match compile_wasm_module_for_jit(wasm_module) {
            Ok(precompiled) => LoadedExecutionBackend::Jit(precompiled)
            Err(detail) => return Err(BackendCompileFailure(detail~))
          }
        Interpreter => Interpreter
      }
      Ok({ wasm_module, imports, backend })
    }
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
  let instance = self.new_instance_or_raise(config) catch {
    error => return Err(EngineTrap(detail=error.to_string()))
  }
  match self.create_instance_backend(instance.store, instance.instance) {
    Ok(backend) => Ok({ ..instance, backend, })
    Err(error) => Err(error)
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
  { store, instance, backend: Interpreter, failure, host_objects, ready: true }
}

///|
fn LoadedImage::create_instance_backend(
  self : LoadedImage,
  store : @wasmoon_runtime.Store,
  instance : @wasmoon_runtime.ModuleInstance,
) -> Result[InstanceExecutionBackend, @loisvm_runtime.ExecutionError] {
  match self.backend {
    Interpreter => Ok(Interpreter)
    Jit(artifact) => {
      let signatures = @wasmoon_wast.build_func_signatures(self.wasm_module)
      let external_imports = @wasmoon_wast.build_external_imports_for_jit(
        self.wasm_module,
        instance,
        store,
      )
      let jit_module = try
        @wasmoon_jit_runtime.JITModule::load_artifact_with_imports(
          artifact,
          signatures,
          external_imports,
          function_names=jit_function_names(self.wasm_module),
        )
      catch {
        error =>
          return Err(
            EngineTrap(detail="Wasmoon JIT load failed: \{error.to_string()}"),
          )
      } noraise {
        module_ => module_
      }
      @wasmoon_wast.register_instance_funcrefs_for_jit(jit_module, instance)
      @wasmoon_wast.install_jit_hostcall_dispatcher(jit_module, store, instance)
      jit_module.alloc_wasm_stack(16L * 1024L * 1024L) |> ignore
      guard @wasmoon_wast.init_jit_memories_from_store(
          instance, store, jit_module,
        )
        is Some(_) else {
        return Err(
          EngineTrap(detail="Wasmoon JIT memory initialization failed"),
        )
      }
      let globals_ptr = @wasmoon_wast.init_jit_globals_from_store(
        instance, store, jit_module,
      )
      @wasmoon_wast.init_elem_segments(
        self.wasm_module,
        jit_module,
        instance,
        store,
      )
      @wasmoon_wast.init_bulk_segments(
        self.wasm_module,
        jit_module,
        instance,
        store,
      ) catch {
        error =>
          return Err(
            EngineTrap(
              detail="Wasmoon JIT segment initialization failed: \{error.to_string()}",
            ),
          )
      }
      let context = @wasmoon_wast.JITModuleContext::JITModuleContext(
        jit_module,
        globals_ptr,
        instance.global_addrs,
        instance.table_addrs,
        instance.func_addrs,
        instance.func_type_indices,
        instance.canonical_type_indices,
        self.wasm_module.types,
        self.wasm_module.type_rec_groups,
        false,
      )
      Ok(Jit(jit_module, context))
    }
  }
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
  match self.backend {
    Interpreter => self.execute_interpreted(cancel)
    Jit(jit_module, context) => self.execute_jit(jit_module, context, cancel)
  }
}

///|
fn ExecutionInstance::execute_interpreted(
  self : ExecutionInstance,
  cancel : (() -> Bool)?,
) -> Result[Unit, @loisvm_runtime.ExecutionError] {
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
      } else {
        self.execution_failure(failure.message)
      }
  }
}

///|
fn ExecutionInstance::execute_jit(
  self : ExecutionInstance,
  jit_module : @wasmoon_jit_runtime.JITModule,
  context : @wasmoon_wast.JITModuleContext,
  cancel : (() -> Bool)?,
) -> Result[Unit, @loisvm_runtime.ExecutionError] {
  guard jit_module.get_func_by_name("lane.entry") is Some(entry) else {
    return Err(EngineTrap(detail="Wasmoon JIT entry `lane.entry` is missing"))
  }
  let result = jit_module.call_with_context_controlled(entry, [], cancel~)
  let host_failure_code = self.failure_code()
  @wasmoon_wast.sync_jit_globals_to_store(context, self.store)
  let failure_code = if host_failure_code != 0 {
    host_failure_code
  } else {
    self.failure_code()
  }
  @wasmoon_wast.sync_jit_tables_to_store(context, self.store)
  jit_module.clear_hostcall_callback()
  jit_module.clear_segments()
  match result {
    Completed(_) =>
      if self.failure.error is Some(_) || failure_code != 0 {
        self.execution_failure("Wasm JIT execution failed", failure_code~)
      } else {
        Ok(())
      }
    Cancelled => Err(Interrupted)
    Failed(error) => self.execution_failure(error.to_string(), failure_code~)
    UnsupportedCancellation =>
      Err(
        EngineTrap(
          detail="Wasmoon JIT was not compiled with cancellation safepoints",
        ),
      )
  }
}

///|
fn ExecutionInstance::failure_code(self : ExecutionInstance) -> Int {
  let value = self.store
    .get_global(self.instance.global_addrs[@compiler.failure_code_global()])
    .get() catch {
      _ => I32(0)
    }
  match value {
    I32(code) => code
    _ => 0
  }
}

///|
fn ExecutionInstance::execution_failure(
  self : ExecutionInstance,
  engine_detail : String,
  failure_code? : Int = self.failure_code(),
) -> Result[Unit, @loisvm_runtime.ExecutionError] {
  if self.failure.error is Some(error) {
    return Err(error)
  }
  match failure_code {
    1 => Err(ExecutionResourceLimit(kind=CallDepth))
    2 => Err(ExecutionResourceLimit(kind=LiveHeapBytes))
    3 => Err(EngineTrap(detail="Wasm allocation or ARC failure"))
    4 =>
      Err(
        InternalRuntimeFailure(detail="Wasm instance-global lifecycle failure"),
      )
    _ => Err(EngineTrap(detail=engine_detail))
  }
}
