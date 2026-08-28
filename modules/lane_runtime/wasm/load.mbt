///|
pub(all) suberror WasmLoadError {
  InvalidWasm(detail~ : String)
  RuntimeImportResolution(error~ : @lane_runtime.RuntimeImportResolutionError)
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
  imports : Array[(@lane_runtime.RuntimeImport, @lane_runtime.RuntimeBinding)]
  control_globals : RuntimeControlGlobals
  priv runtime_services : RuntimeServices
  priv backend : LoadedExecutionBackend
}

///|
pub struct ExecutionInstance {
  store : @wasmoon_runtime.Store
  instance : @wasmoon_runtime.ModuleInstance
  priv backend : InstanceExecutionBackend
  priv failure : RuntimeFailureState
  priv host_objects : WasmHostObjects
  priv control_globals : RuntimeControlGlobals
  mut ready : Bool
}

///|
/// Loads the unique persisted execution target. Parsing, validation, runtime
/// import resolution and backend preparation are atomic.
pub fn load_wasm(
  wasm : Bytes,
  runtime_imports : Array[@lane_runtime.RuntimeImport],
  registry : @lane_runtime.RuntimeRegistry,
  mode? : ExecutionMode = Jit,
) -> Result[LoadedImage, WasmLoadError] {
  let module_ = @parser.parse_module(wasm) catch {
    error => return Err(InvalidWasm(detail=error.to_string()))
  }
  @validator.validate_module(module_) catch {
    error =>
      return Err(InvalidWasm(detail=@validator.format_validation_error(error)))
  }
  load_module(module_, runtime_imports, registry, mode)
}

///|
fn load_module(
  wasm_module : @wasm_types.Module,
  runtime_imports : Array[@lane_runtime.RuntimeImport],
  registry : @lane_runtime.RuntimeRegistry,
  mode : ExecutionMode,
) -> Result[LoadedImage, WasmLoadError] {
  let control_globals = match resolve_runtime_control_globals(wasm_module) {
    Ok(globals) => globals
    Err(detail) => return Err(InvalidWasm(detail~))
  }
  if !wasm_imports_belong_to_lane_abi(wasm_module) {
    return Err(
      InvalidWasm(detail="Wasm module imports an unsupported host ABI"),
    )
  }
  if !internal_runtime_imports_match(wasm_module) {
    return Err(
      InvalidWasm(
        detail="internal runtime imports do not match the Lane Wasm ABI",
      ),
    )
  }
  if !runtime_import_manifest_matches(wasm_module, runtime_imports) {
    return Err(
      InvalidWasm(
        detail="runtime import manifest does not match the Wasm import contracts",
      ),
    )
  }
  let runtime_services = match
    resolve_runtime_services(wasm_module, runtime_imports) {
    Ok(services) => services
    Err(detail) => return Err(InvalidWasm(detail~))
  }
  let imports : Array[
    (@lane_runtime.RuntimeImport, @lane_runtime.RuntimeBinding),
  ] = []
  for import_ in runtime_imports {
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
  let backend = match mode {
    Jit =>
      match compile_wasm_module_for_jit(wasm_module) {
        Ok(precompiled) => LoadedExecutionBackend::Jit(precompiled)
        Err(detail) => return Err(BackendCompileFailure(detail~))
      }
    Interpreter => Interpreter
  }
  Ok({ wasm_module, imports, control_globals, runtime_services, backend, })
}

///|
fn wasm_imports_belong_to_lane_abi(wasm_module : @wasm_types.Module) -> Bool {
  wasm_module.imports.all(import_ => {
    import_.mod_name == "lane.runtime.v1" ||
    import_.mod_name == @internal_abi.module_name()
  })
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
fn runtime_import_manifest_matches(
  wasm_module : @wasm_types.Module,
  runtime_imports : Array[@lane_runtime.RuntimeImport],
) -> Bool {
  let mut manifest_index = 0
  for wasm_import in wasm_module.imports {
    guard wasm_import.mod_name == "lane.runtime.v1" else { continue }
    guard wasm_import.desc is Func(type_index) else { return false }
    guard manifest_index < runtime_imports.length() else { return false }
    let manifest_import = runtime_imports[manifest_index]
    let wasm_type = wasm_module.validated_func_type_at(type_index)
    if wasm_import.name != manifest_import.symbol ||
      wasm_type.params !=
      @internal_abi.runtime_import_parameters(manifest_import) ||
      wasm_type.results != @internal_abi.runtime_import_results(manifest_import) {
      return false
    }
    manifest_index += 1
  }
  manifest_index == runtime_imports.length()
}

///|
struct RuntimeServices {
  string_new : Int?
  host_object_new : Int?
}

///|
fn RuntimeServices::function(
  self : RuntimeServices,
  service : @internal_abi.RuntimeService,
) -> Int raise @wasmoon_runtime.RuntimeError {
  let function = match service {
    StringNew => self.string_new
    HostObjectNew => self.host_object_new
  }
  match function {
    Some(index) => index
    None => raise UndefinedElement
  }
}

///|
fn wasm_function_type(
  wasm_module : @wasm_types.Module,
  function_index : Int,
) -> @wasm_types.FuncType? {
  let mut imported_function_index = 0
  for import_ in wasm_module.imports {
    guard import_.desc is Func(type_index) else { continue }
    if imported_function_index == function_index {
      return Some(wasm_module.validated_func_type_at(type_index))
    }
    imported_function_index += 1
  }
  let defined_index = function_index - imported_function_index
  if defined_index < 0 || defined_index >= wasm_module.funcs.length() {
    return None
  }
  Some(wasm_module.validated_func_type_at(wasm_module.funcs[defined_index]))
}

///|
fn runtime_service_required(
  service : @internal_abi.RuntimeService,
  wasm_module : @wasm_types.Module,
  runtime_imports : Array[@lane_runtime.RuntimeImport],
) -> Bool {
  if runtime_imports.any(import_ => {
      service.required_by_import_result(import_.result)
    }) {
    return true
  }
  @internal_abi.functions().any(function => {
    service.required_by_internal_import(function) &&
    wasm_module.imports.any(import_ => {
      import_.mod_name == @internal_abi.module_name() &&
      import_.name == function.name()
    })
  })
}

///|
fn resolve_runtime_services(
  wasm_module : @wasm_types.Module,
  runtime_imports : Array[@lane_runtime.RuntimeImport],
) -> Result[RuntimeServices, String] {
  let mut string_new : Int? = None
  let mut host_object_new : Int? = None
  for service in @internal_abi.runtime_services() {
    let required = runtime_service_required(
      service, wasm_module, runtime_imports,
    )
    let mut exported : Int? = None
    for export_ in wasm_module.exports {
      if export_.name == service.name() {
        guard export_.desc is Func(index) else {
          return Err(
            "Wasm runtime service `\{service.name()}` is not a function",
          )
        }
        exported = Some(index)
      }
    }
    match (required, exported) {
      (true, None) =>
        return Err("Wasm runtime service `\{service.name()}` is missing")
      (false, Some(_)) =>
        return Err(
          "Wasm runtime service `\{service.name()}` is not required by the retained host imports",
        )
      (true, Some(index)) => {
        if wasm_function_type(wasm_module, index) != Some(service.type_()) {
          return Err(
            "Wasm runtime service `\{service.name()}` has the wrong function type",
          )
        }
        match service {
          StringNew => string_new = Some(index)
          HostObjectNew => host_object_new = Some(index)
        }
      }
      (false, None) => ()
    }
  }
  Ok({ string_new, host_object_new, })
}

///|
struct RuntimeControlGlobals {
  max_live_heap_bytes : Int
  max_call_depth : Int
  failure_code : Int
  runtime_import_failed : Int
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
  let max_call_depth = match
    runtime_control_global_index(wasm_module, MaxCallDepth) {
    Ok(index) => index
    Err(detail) => return Err(detail)
  }
  let failure_code = match
    runtime_control_global_index(wasm_module, FailureCode) {
    Ok(index) => index
    Err(detail) => return Err(detail)
  }
  let runtime_import_failed = match
    runtime_control_global_index(wasm_module, RuntimeImportFailed) {
    Ok(index) => index
    Err(detail) => return Err(detail)
  }
  Ok({
    max_live_heap_bytes,
    max_call_depth,
    failure_code,
    runtime_import_failed,
  })
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
  let imports = @wasmoon_runtime.Imports::Imports()
  let failure : RuntimeFailureState = { error: None, }
  let runtime = @lane_runtime.ExecutionRuntime::new(config~)
  let host_objects = WasmHostObjects::new(runtime)
  let runtime_context = runtime.context()
  let format_f32 : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
    guard values is [F32(value)] else { raise TypeMismatch }
    [
      I32(
        copy_host_string(
          caller,
          @utf8.encode(@float_format.format_f32(value)),
          self.runtime_services,
        ),
      ),
    ]
  }
  let format_f64 : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
    guard values is [F64(value)] else { raise TypeMismatch }
    [
      I32(
        copy_host_string(
          caller,
          @utf8.encode(@float_format.format_f64(value)),
          self.runtime_services,
        ),
      ),
    ]
  }
  let fatal_string : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
    guard values is [I32(pointer), I32(length)] else { raise TypeMismatch }
    let memory = match caller.get_exported_memory("lane.memory") {
      Some(value) => value
      None => raise UndefinedElement
    }
    let bytes = @lane_runtime.HostStringView::new(length~, read_byte=index => {
      memory.read_byte(pointer + index)
    }).to_bytes()
    let message = @utf8.decode(bytes) catch {
      _ => {
        record_runtime_failure(
          caller,
          failure,
          InternalRuntimeFailure(detail="Fatal message is not valid UTF-8"),
          self.control_globals,
        )
        return []
      }
    }
    record_runtime_failure(
      caller,
      failure,
      Fatal(message~),
      self.control_globals,
    )
    []
  }
  let release_host_object : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
    @wasm_types.Value,
  ] raise @wasmoon_runtime.RuntimeError = (_caller, values) => {
    guard values is [I64(token)] else { raise TypeMismatch }
    host_objects.release(token) catch {
      error => {
        failure.error = Some(
          InternalRuntimeFailure(detail=wasm_host_object_failure_detail(error)),
        )
        raise TypeMismatch
      }
    }
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
      HostObjectRelease =>
        store.alloc_host_func_with_caller(release_host_object, func_type=type_)
    }
    imports.add_func(@internal_abi.module_name(), function.name(), address)
  }
  for resolved in self.imports {
    let descriptor = resolved.0
    let binding = resolved.1
    let host_function : (@wasmoon_runtime.Caller, Array[@wasm_types.Value]) -> Array[
      @wasm_types.Value,
    ] raise @wasmoon_runtime.RuntimeError = (caller, values) => {
      invoke_runtime_binding(
        caller,
        binding,
        failure,
        runtime,
        runtime_context,
        host_objects,
        self.control_globals,
        self.runtime_services,
        values,
      )
    }
    let address = store.alloc_host_func_with_caller(host_function, func_type={
      params: @internal_abi.runtime_import_parameters(descriptor),
      results: @internal_abi.runtime_import_results(descriptor),
    })
    imports.add_func("lane.runtime.v1", binding.symbol(), address)
  }
  let instance = @executor.instantiate_module_with_imports(
    store,
    self.wasm_module,
    imports,
  )
  store
  .get_global(instance.global_addrs[self.control_globals.max_live_heap_bytes])
  .set(I32(encode_execution_limit(config.max_live_heap_bytes)))
  store
  .get_global(instance.global_addrs[self.control_globals.max_call_depth])
  .set(I32(encode_execution_limit(config.max_call_depth)))
  {
    store,
    instance,
    backend: Interpreter,
    failure,
    host_objects,
    control_globals: self.control_globals,
    ready: true,
  }
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
) -> Result[Unit, @lane_runtime.ExecutionError] {
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
) -> Result[Unit, @lane_runtime.ExecutionError] {
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
