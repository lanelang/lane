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
  control_globals : RuntimeControlGlobals
  priv backend : LoadedExecutionBackend
  priv wasi_stdout : ((Bytes) -> Unit)?
  priv configure_host : HostLinkerConfiguration
}

///|
pub struct ExecutionInstance {
  store : @wasmoon_runtime.Store
  instance : @wasmoon_runtime.ModuleInstance
  priv backend : InstanceExecutionBackend
  priv failure : RuntimeFailureState
  priv control_globals : RuntimeControlGlobals
  mut ready : Bool
}

///|
struct RuntimeFailureState {
  mut error : @lane_runtime.ExecutionError?
}

///|
fn record_runtime_failure(
  failure : RuntimeFailureState,
  error : @lane_runtime.ExecutionError,
) -> Unit {
  failure.error = Some(error)
}

///|
/// Loads the unique persisted execution target. Parsing, validation, runtime
/// import resolution and backend preparation are atomic.
pub fn load_wasm(
  wasm : Bytes,
  mode? : ExecutionMode = Jit,
  wasi_stdout? : ((Bytes) -> Unit)? = None,
  configure_host? : HostLinkerConfiguration = _ => (),
) -> Result[LoadedImage, WasmLoadError] {
  let module_ = @parser.parse_module(wasm) catch {
    error => return Err(InvalidWasm(detail=error.to_string()))
  }
  @validator.validate_module(module_) catch {
    error =>
      return Err(InvalidWasm(detail=@validator.format_validation_error(error)))
  }
  load_module(module_, mode, wasi_stdout, configure_host)
}

///|
fn load_module(
  wasm_module : @wasm_types.Module,
  mode : ExecutionMode,
  wasi_stdout : ((Bytes) -> Unit)?,
  configure_host : HostLinkerConfiguration,
) -> Result[LoadedImage, WasmLoadError] {
  let control_globals = match resolve_runtime_control_globals(wasm_module) {
    Ok(globals) => globals
    Err(detail) => return Err(InvalidWasm(detail~))
  }
  if !wasm_imports_are_functions(wasm_module) {
    return Err(
      InvalidWasm(detail="Lane Wasm modules may only import functions"),
    )
  }
  if !internal_runtime_imports_match(wasm_module) {
    return Err(
      InvalidWasm(
        detail="internal runtime imports do not match the Lane Wasm ABI",
      ),
    )
  }
  if !wasi_preview1_imports_match(wasm_module) {
    return Err(
      InvalidWasm(
        detail="WASI Preview 1 imports do not match the canonical ABI",
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
  Ok({ wasm_module, control_globals, backend, wasi_stdout, configure_host, })
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
fn wasi_preview1_imports_match(wasm_module : @wasm_types.Module) -> Bool {
  let mut previous_index = -1
  let canonical = @wasm_abi.wasi_preview1_imports()
  for wasm_import in wasm_module.imports {
    guard wasm_import.mod_name == "wasi_snapshot_preview1" else { continue }
    guard wasm_import.desc is Func(type_index) else { return false }
    let mut matched_index : Int? = None
    for index, import_ in canonical {
      if import_.contract().field_name == wasm_import.name {
        matched_index = Some(index)
        break
      }
    }
    guard matched_index is Some(index) && index > previous_index else {
      return false
    }
    let contract = canonical[index].contract()
    let expected : @wasm_types.FuncType = {
      params: contract.core_parameters().map(core_value_type),
      results: contract.core_results().map(core_value_type),
    }
    if wasm_module.validated_func_type_at(type_index) != expected {
      return false
    }
    previous_index = index
  }
  true
}

///|
fn internal_runtime_imports_match(wasm_module : @wasm_types.Module) -> Bool {
  let canonical = @internal_abi.functions()
  let mut previous_index = -1
  for wasm_import in wasm_module.imports {
    guard wasm_import.mod_name == @internal_abi.module_name() else { continue }
    guard wasm_import.desc is Func(type_index) else { return false }
    let mut matched_index : Int? = None
    for index, function in canonical {
      if function.name() == wasm_import.name {
        matched_index = Some(index)
        break
      }
    }
    guard matched_index is Some(index) && index > previous_index else {
      return false
    }
    if wasm_module.validated_func_type_at(type_index) !=
      canonical[index].type_() {
      return false
    }
    previous_index = index
  }
  true
}

///|
struct RuntimeControlGlobals {
  max_live_heap_bytes : Int
  failure_code : Int
}

///|
fn runtime_control_global_index(
  wasm_module : @wasm_types.Module,
  control : @internal_abi.RuntimeControlGlobal,
) -> Result[Int, String] {
  for export_ in wasm_module.exports {
    if export_.name == control.name() {
      guard export_.desc is Global(index) else {
        return Err("Wasm export `\{control.name()}` is not a global")
      }
      return Ok(index)
    }
  }
  Err("Wasm runtime control global `\{control.name()}` is missing")
}

///|
fn resolve_runtime_control_globals(
  wasm_module : @wasm_types.Module,
) -> Result[RuntimeControlGlobals, String] {
  let max_live_heap_bytes = match
    runtime_control_global_index(wasm_module, MaxLiveHeapBytes) {
    Ok(index) => index
    Err(detail) => return Err(detail)
  }
  let failure_code = match
    runtime_control_global_index(wasm_module, FailureCode) {
    Ok(index) => index
    Err(detail) => return Err(detail)
  }
  Ok({ max_live_heap_bytes, failure_code, })
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
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
) -> Result[ExecutionInstance, @lane_runtime.ExecutionError] {
  let instance = self.new_instance_or_raise(config) catch {
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
  config? : @lane_runtime.ExecutionConfig = @lane_runtime.ExecutionConfig::defaults(),
) -> Result[Unit, @lane_runtime.ExecutionError] {
  match self.new_instance(config~) {
    Ok(instance) => instance.execute()
    Err(error) => Err(error)
  }
}

///|
fn LoadedImage::new_instance_or_raise(
  self : LoadedImage,
  config : @lane_runtime.ExecutionConfig,
) -> ExecutionInstance raise @wasmoon_runtime.RuntimeError {
  let store = @wasmoon_runtime.Store::Store()
  let linker = @wasmoon_runtime.Linker::with_store(store)
  let wasi_builder = @wasi.WasiContextBuilder::WasiContextBuilder()
  if self.wasi_stdout is Some(write) {
    ignore(wasi_builder.stdout(write))
  }
  @wasi.register_wasi(linker, wasi_builder.build())
  (self.configure_host)(linker)
  let imports = linker.build_imports()
  let failure : RuntimeFailureState = { error: None, }
  let format_f32 : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
    guard values is [F32(value), I32(pointer)] else { raise TypeMismatch }
    [I32(write_float_text(caller, pointer, @float_format.format_f32(value)))]
  }
  let format_f64 : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
    guard values is [F64(value), I32(pointer)] else { raise TypeMismatch }
    [I32(write_float_text(caller, pointer, @float_format.format_f64(value)))]
  }
  let fatal_string : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
    guard values is [I32(pointer), I32(length)] else { raise TypeMismatch }
    let memory = match caller.get_exported_memory("memory") {
      Some(value) => value
      None => raise UndefinedElement
    }
    let bytes = Array::make(length, b'\x00')
    for index in 0..<length {
      bytes[index] = memory.read_byte(pointer + index)
    }
    let message = @utf8.decode(Bytes::from_array(bytes)) catch {
      _ => {
        record_runtime_failure(
          failure,
          InternalRuntimeFailure(detail="Fatal message is not valid UTF-8"),
        )
        return []
      }
    }
    record_runtime_failure(failure, Fatal(message~))
    []
  }
  for function in @internal_abi.functions() {
    guard self.wasm_module.imports.any(import_ => {
      import_.mod_name == @internal_abi.module_name() &&
      import_.name == function.name()
    }) else {
      continue
    }
    let type_ = function.type_()
    let address = match function {
      F32ToString =>
        store.alloc_host_func_with_caller(format_f32, func_type=type_)
      F64ToString =>
        store.alloc_host_func_with_caller(format_f64, func_type=type_)
      FatalString =>
        store.alloc_host_func_with_caller(fatal_string, func_type=type_)
    }
    imports.add_func(@internal_abi.module_name(), function.name(), address)
  }
  let instance = @executor.instantiate_module_with_imports(
    store,
    self.wasm_module,
    imports,
  )
  store
  .get_global(instance.global_addrs[self.control_globals.max_live_heap_bytes])
  .set(I32(encode_execution_limit(config.max_live_heap_bytes)))
  {
    store,
    instance,
    backend: Interpreter,
    failure,
    control_globals: self.control_globals,
    ready: true,
  }
}

///|
fn write_float_text(
  caller : @wasmoon_runtime.Caller,
  pointer : Int,
  text : String,
) -> Int raise @wasmoon_runtime.RuntimeError {
  let bytes = @utf8.encode(text)
  if bytes.length() > @internal_abi.float_text_capacity() {
    raise OutOfBoundsMemoryAccess
  }
  let memory = match caller.get_exported_memory("memory") {
    Some(value) => value
    None => raise UndefinedElement
  }
  for index, byte in bytes {
    memory.store_byte(pointer + index, byte)
  }
  bytes.length()
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
      jit_module.init_wasi_with_stdio([], [], [], self.wasi_stdout, None, None)
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
) -> Result[Unit, @lane_runtime.ExecutionError] {
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
) -> Result[Unit, @lane_runtime.ExecutionError] {
  let result = @executor.call_exported_func_with_options(
    self.store,
    self.instance,
    "_start",
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
) -> Result[Unit, @lane_runtime.ExecutionError] {
  guard jit_module.get_func_by_name("_start") is Some(entry) else {
    return Err(EngineTrap(detail="Wasmoon JIT entry `_start` is missing"))
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
    .get_global(self.instance.global_addrs[self.control_globals.failure_code])
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
) -> Result[Unit, @lane_runtime.ExecutionError] {
  if self.failure.error is Some(error) {
    return Err(error)
  }
  match @internal_abi.RuntimeFailureCode::from_code(failure_code) {
    Some(LiveHeapBytes) => Err(ExecutionResourceLimit(kind=LiveHeapBytes))
    Some(AllocationOrArc) =>
      Err(EngineTrap(detail="Wasm allocation or ARC failure"))
    None => Err(EngineTrap(detail=engine_detail))
  }
}
