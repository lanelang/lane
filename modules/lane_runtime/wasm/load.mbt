///|
pub(all) suberror WasmLoadError {
  InvalidWasm(detail~ : String)
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
pub type HostLinkerConfiguration = (@wasmoon_runtime.Linker) -> Unit raise @wasmoon_runtime.RuntimeError

///|
pub struct LoadedImage {
  wasm_module : @wasm_types.Module
  priv backend : LoadedExecutionBackend
  priv wasi_stdout : ((Bytes) -> Unit)?
  priv wasi_stderr : ((Bytes) -> Unit)?
  priv configure_host : HostLinkerConfiguration
}

///|
pub struct ExecutionInstance {
  store : @wasmoon_runtime.Store
  instance : @wasmoon_runtime.ModuleInstance
  priv backend : InstanceExecutionBackend
  priv wasi_context : @wasi.WasiContext
  mut ready : Bool
}

///|
/// Loads the unique persisted execution target. Parsing, validation, runtime
/// import resolution and backend preparation are atomic.
pub fn load_wasm(
  wasm : Bytes,
  mode? : ExecutionMode = Jit,
  wasi_stdout? : ((Bytes) -> Unit)? = None,
  wasi_stderr? : ((Bytes) -> Unit)? = None,
  configure_host? : HostLinkerConfiguration = _ => (),
) -> Result[LoadedImage, WasmLoadError] {
  let module_ = @parser.parse_module(wasm) catch {
    error => return Err(InvalidWasm(detail=error.to_string()))
  }
  @validator.validate_module(module_) catch {
    error =>
      return Err(InvalidWasm(detail=@validator.format_validation_error(error)))
  }
  load_module(module_, mode, wasi_stdout, wasi_stderr, configure_host)
}

///|
fn load_module(
  wasm_module : @wasm_types.Module,
  mode : ExecutionMode,
  wasi_stdout : ((Bytes) -> Unit)?,
  wasi_stderr : ((Bytes) -> Unit)?,
  configure_host : HostLinkerConfiguration,
) -> Result[LoadedImage, WasmLoadError] {
  if !wasm_imports_are_functions(wasm_module) {
    return Err(
      InvalidWasm(detail="Lane Wasm modules may only import functions"),
    )
  }
  if !wasi_preview1_imports_match(wasm_module) {
    return Err(
      InvalidWasm(
        detail="WASI Preview 1 imports do not match the canonical ABI",
      ),
    )
  }
  if !lane_runtime_v1_imports_match(wasm_module) {
    return Err(
      InvalidWasm(
        detail="Lane Runtime V1 imports do not match the canonical ABI",
      ),
    )
  }
  let backend = match mode {
    Jit =>
      match compile_wasm_module_for_jit(wasm_module) {
        Ok(precompiled) => LoadedExecutionBackend::Jit(precompiled)
        Err(detail) => return Err(BackendCompileFailure(detail~))
      }
    Interpreter => Interpreter
  }
  Ok({ wasm_module, backend, wasi_stdout, wasi_stderr, configure_host, })
}

///|
fn wasm_imports_are_functions(wasm_module : @wasm_types.Module) -> Bool {
  wasm_module.imports.all(import_ => import_.desc is Func(_))
}

///|
fn core_value_type(type_ : @wasm_abi.CoreValueType) -> @wasm_types.ValueType {
  match type_ {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
  }
}

///|
pub fn project_core_import_func_type(
  contract : @wasm_abi.ImportContract,
) -> @wasm_types.FuncType {
  {
    params: contract.core_parameters().map(core_value_type),
    results: contract.core_results().map(core_value_type),
  }
}

///|
fn wasi_preview1_imports_match(wasm_module : @wasm_types.Module) -> Bool {
  canonical_imports_match(
    wasm_module,
    "wasi_snapshot_preview1",
    @wasm_abi.wasi_preview1_imports().map(import_ => import_.contract()),
  )
}

///|
fn lane_runtime_v1_imports_match(wasm_module : @wasm_types.Module) -> Bool {
  canonical_imports_match(
    wasm_module,
    "lane_runtime_v1",
    @wasm_abi.lane_runtime_v1_imports().map(import_ => import_.contract()),
  )
}

///|
fn canonical_imports_match(
  wasm_module : @wasm_types.Module,
  module_name : String,
  canonical : Array[@wasm_abi.ImportContract],
) -> Bool {
  let mut previous_index = -1
  for wasm_import in wasm_module.imports {
    guard wasm_import.mod_name == module_name else { continue }
    guard wasm_import.desc is Func(type_index) else { return false }
    let mut matched_index : Int? = None
    for index, contract in canonical {
      if contract.field_name == wasm_import.name {
        matched_index = Some(index)
        break
      }
    }
    guard matched_index is Some(index) && index > previous_index else {
      return false
    }
    let contract = canonical[index]
    let expected = project_core_import_func_type(contract)
    if wasm_module.validated_func_type_at(type_index) != expected {
      return false
    }
    previous_index = index
  }
  true
}

///|
pub fn LoadedImage::wasm_module(self : LoadedImage) -> @wasm_types.Module {
  self.wasm_module
}

///|
pub fn LoadedImage::new_instance(
  self : LoadedImage,
) -> Result[ExecutionInstance, @lane_runtime.ExecutionError] {
  let instance = self.new_instance_or_raise() catch {
    error => return Err(EngineTrap(detail=error.to_string()))
  }
  match self.create_instance_backend(instance.store, instance.instance) {
    Ok(backend) => Ok({ ..instance, backend, })
    Err(error) => Err(error)
  }
}

///|
/// Executes one fresh instance. This is the ordinary single-shot interface;
/// callers that need cancellation or instance inspection can construct the
/// instance explicitly.
pub fn LoadedImage::execute(
  self : LoadedImage,
) -> Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError] {
  match self.new_instance() {
    Ok(instance) => instance.execute()
    Err(error) => Err(error)
  }
}

///|
fn LoadedImage::new_instance_or_raise(
  self : LoadedImage,
) -> ExecutionInstance raise @wasmoon_runtime.RuntimeError {
  let store = @wasmoon_runtime.Store::Store()
  let linker = @wasmoon_runtime.Linker::with_store(store)
  let wasi_builder = @wasi.WasiContextBuilder::WasiContextBuilder()
  if self.wasi_stdout is Some(write) {
    ignore(wasi_builder.stdout(write))
  }
  if self.wasi_stderr is Some(write) {
    ignore(wasi_builder.stderr(write))
  }
  let wasi_context = wasi_builder.build()
  @wasi.register_wasi(linker, wasi_context)
  (self.configure_host)(linker)
  let imports = linker.build_imports()
  let instance = @executor.instantiate_module_with_imports(
    store,
    self.wasm_module,
    imports,
  )
  { store, instance, backend: Interpreter, wasi_context, ready: true, }
}

///|
fn LoadedImage::create_instance_backend(
  self : LoadedImage,
  store : @wasmoon_runtime.Store,
  instance : @wasmoon_runtime.ModuleInstance,
) -> Result[InstanceExecutionBackend, @lane_runtime.ExecutionError] {
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
      @wasmoon_wast.register_instance_funcrefs_for_jit(
        jit_module, instance, store,
      )
      jit_module.configure_native_fiber_stack_size(16L * 1024L * 1024L)
      |> ignore
      jit_module.init_wasi_with_stdio(
        [],
        [],
        [],
        self.wasi_stdout,
        self.wasi_stderr,
        None,
      )
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
      @wasmoon_wast.install_jit_hostcall_dispatcher(
        jit_module,
        store,
        instance,
        before_dispatch=fn() {
          @wasmoon_wast.sync_jit_globals_to_store(context, store)
        },
        after_dispatch=fn() {
          @wasmoon_wast.sync_store_globals_to_jit(context, store)
        },
      )
      Ok(Jit(jit_module, context))
    }
  }
}

///|
pub fn ExecutionInstance::execute(
  self : ExecutionInstance,
  cancel? : (() -> Bool)? = None,
) -> Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError] {
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
) -> Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError] {
  let result = @executor.call_exported_func_with_options(
    self.store,
    self.instance,
    "_start",
    [],
    options=CallExportOptions(cancel~),
  )
  if self.wasi_context.get_exit_code() is Some(code) {
    return process_exit_result(code)
  }
  match result {
    Ok(_) => Ok(Returned)
    Err(failure) =>
      if failure.kind is Cancelled {
        Err(Interrupted)
      } else {
        execution_failure(failure.message)
      }
  }
}

///|
fn ExecutionInstance::execute_jit(
  self : ExecutionInstance,
  jit_module : @wasmoon_jit_runtime.JITModule,
  context : @wasmoon_wast.JITModuleContext,
  cancel : (() -> Bool)?,
) -> Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError] {
  guard jit_module.get_func_by_name("_start") is Some(entry) else {
    return Err(EngineTrap(detail="Wasmoon JIT entry `_start` is missing"))
  }
  let result = jit_module.call_with_context_controlled(entry, [], cancel~)
  @wasmoon_wast.sync_jit_globals_to_store(context, self.store)
  @wasmoon_wast.sync_jit_tables_to_store(context, self.store)
  jit_module.clear_hostcall_callback()
  jit_module.clear_segments()
  match result {
    Completed(_) => Ok(Returned)
    Cancelled => Err(Interrupted)
    Failed(JITExit(code)) => process_exit_result(code)
    Failed(error) => execution_failure(error.to_string())
    UnsupportedCancellation =>
      Err(
        EngineTrap(
          detail="Wasmoon JIT was not compiled with cancellation safepoints",
        ),
      )
  }
}

///|
fn process_exit_result(
  code : Int,
) -> Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError] {
  Ok(ProcessExit(code~))
}

///|
fn execution_failure(
  engine_detail : String,
) -> Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError] {
  Err(EngineTrap(detail=engine_detail))
}
