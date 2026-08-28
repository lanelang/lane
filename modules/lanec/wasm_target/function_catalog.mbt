///|
priv struct WasmFunctionHandle {
  index : Int
} derive(Debug, Eq)

///|
priv struct WasmTableSlot {
  index : Int
} derive(Debug)

///|
priv struct WasmFunctionType {
  parameters : Array[@wasm_types.ValueType]
  results : Array[@wasm_types.ValueType]
} derive(Debug, Eq)

///|
priv enum WasmFunctionDeclaration {
  Import(module_name~ : String, name~ : String)
  Defined
} derive(Debug)

///|
#warnings("-unused_value")
priv struct WasmFunctionCatalogEntry {
  handle : WasmFunctionHandle
  origin : WasmFunctionOrigin
  type_ : WasmFunctionType
  type_index : Int
  declaration : WasmFunctionDeclaration
  table_slot : WasmTableSlot?
} derive(Debug)

///|
priv struct WasmFunctionCatalog {
  entries : Array[WasmFunctionCatalogEntry]
  image_functions : Array[WasmFunctionHandle]
  physical_imports : Array[WasmFunctionHandle?]
  table_entries : Array[WasmFunctionHandle]
  roots : Array[WasmFunctionOrigin]
  required : Array[WasmFunctionOrigin]
  runtime_layouts : WasmRuntimeLayoutIds
}

///|
fn wasm_function_type(
  parameters : Array[@wasm_types.ValueType],
  results : Array[@wasm_types.ValueType],
) -> WasmFunctionType {
  { parameters, results, }
}

///|
fn runtime_function_type(role : WasmRuntimeFunctionRole) -> WasmFunctionType {
  match role {
    Allocate => wasm_function_type([I32], [I32])
    Free | RetainReference | ReleaseReference | RequireByteSequenceLayout =>
      wasm_function_type([I32], [])
    ByteSequenceNew => wasm_function_type([I32], [I32])
    ByteSequenceEqual | ByteSequenceConcat =>
      wasm_function_type([I32, I32], [I32])
    ByteSequenceSlice => wasm_function_type([I32, I64, I64], [I32])
    ByteSequenceMake => wasm_function_type([I64, I32], [I32])
    ByteSequenceIndex | ByteSequenceGet => wasm_function_type([I32, I64], [I32])
    ByteSequenceSet => wasm_function_type([I32, I64, I32], [I32])
    ByteSequenceIsValidUtf8 => wasm_function_type([I32], [I32])
    ArrayNew => wasm_function_type([I32, I32], [I32])
    RequireArrayLayout => wasm_function_type([I32], [I32])
    ArrayMake => wasm_function_type([I64, I64, I32], [I32])
    ArrayIndex => wasm_function_type([I32, I64, I32], [I32])
    ArrayLength => wasm_function_type([I32], [I64])
    ArrayGet => wasm_function_type([I32, I64, I32], [I64])
    ArraySet => wasm_function_type([I32, I64, I64, I32], [I32])
    InstanceGlobalCleanup => wasm_function_type([], [])
  }
}

///|
fn helper_function_type(role : WasmHelperFunctionRole) -> WasmFunctionType {
  match role {
    CallableAbiGuard => wasm_function_type([I64, I32], [])
    NoopErased
    | RetainReferenceErased
    | ReleaseReferenceErased
    | RetainCallable
    | ReleaseCallable => wasm_function_type([I64], [])
    CleanupLiveReference => wasm_function_type([I32], [])
    CleanupLiveCallable => wasm_function_type([I64], [])
    CleanupLiveErased => wasm_function_type([I64, I32, I32], [])
    DestroyNoop | DestroyShape(_) | DestroyArray =>
      wasm_function_type([I32], [])
    ByteSequenceSizer | ArraySizer => wasm_function_type([I32], [I32])
  }
}

///|
fn runtime_function_order() -> Array[WasmRuntimeFunctionRole] {
  [
    Allocate,
    Free,
    RetainReference,
    ReleaseReference,
    ByteSequenceNew,
    RequireByteSequenceLayout,
    ByteSequenceEqual,
    ByteSequenceConcat,
    ByteSequenceSlice,
    ByteSequenceMake,
    ByteSequenceIndex,
    ByteSequenceGet,
    ByteSequenceSet,
    ByteSequenceIsValidUtf8,
    ArrayNew,
    RequireArrayLayout,
    ArrayMake,
    ArrayIndex,
    ArrayLength,
    ArrayGet,
    ArraySet,
    InstanceGlobalCleanup,
  ]
}

///|
fn helper_function_order(
  image : @physical.PhysicalProgram,
) -> Array[WasmHelperFunctionRole] {
  let roles : Array[WasmHelperFunctionRole] = [
    CallableAbiGuard,
    NoopErased,
    RetainReferenceErased,
    ReleaseReferenceErased,
    RetainCallable,
    ReleaseCallable,
    CleanupLiveReference,
    CleanupLiveCallable,
    CleanupLiveErased,
    DestroyNoop,
  ]
  for shape in 0..<image.object_shapes.length() {
    roles.push(DestroyShape(shape~))
  }
  roles.push(ByteSequenceSizer)
  roles.push(ArraySizer)
  roles.push(DestroyArray)
  roles
}

///|
fn helper_is_layout_callback(role : WasmHelperFunctionRole) -> Bool {
  match role {
    CallableAbiGuard
    | CleanupLiveReference
    | CleanupLiveCallable
    | CleanupLiveErased => false
    _ => true
  }
}

///|
fn address_taken_functions(image : @physical.PhysicalProgram) -> Array[Bool] {
  let address_taken = Array::make(image.functions.length(), false)
  for entry in image.functions {
    guard entry is PhysicalBody(body) else { continue }
    for block in body.blocks {
      for instruction in block.instructions {
        match instruction {
          ConstFunction(_, function) | MakeClosure(_, function, _) =>
            address_taken[function.value - 1] = true
          _ => ()
        }
      }
    }
  }
  address_taken
}

///|
fn WasmFunctionCatalog::new(
  image : @physical.PhysicalProgram,
  requirements : WasmFunctionRequirements,
  runtime_layouts : WasmRuntimeLayoutIds,
) -> WasmFunctionCatalog {
  {
    entries: [],
    image_functions: Array::make(image.functions.length(), { index: -1, }),
    physical_imports: Array::make(image.functions.length(), None),
    table_entries: [],
    roots: requirements.roots,
    required: requirements.required,
    runtime_layouts,
  }
}

///|
fn WasmFunctionCatalog::add_entry(
  self : WasmFunctionCatalog,
  wasm_module : @wasm_types.Module,
  origin : WasmFunctionOrigin,
  type_ : WasmFunctionType,
  declaration : WasmFunctionDeclaration,
  callable : Bool,
) -> WasmFunctionHandle raise WasmCompileError {
  if self.entries.any(entry => entry.origin == origin) {
    raise InvalidFunctionCatalog(
      detail="duplicate function role: \{Repr(origin)}",
    )
  }
  if declaration is Import(_) &&
    self.entries.any(entry => entry.declaration is Defined) {
    raise InvalidFunctionCatalog(detail="function import follows a definition")
  }
  if callable && declaration is Import(_) {
    raise InvalidFunctionCatalog(
      detail="callable table entry is not a defined body",
    )
  }
  let handle : WasmFunctionHandle = { index: self.entries.length(), }
  let table_slot = if callable {
    let slot : WasmTableSlot = { index: self.table_entries.length() + 1, }
    self.table_entries.push(handle)
    Some(slot)
  } else {
    None
  }
  let type_index = intern_function_type(
    wasm_module,
    type_.parameters,
    type_.results,
  )
  self.entries.push({
    handle,
    origin,
    type_,
    type_index,
    declaration,
    table_slot,
  })
  handle
}

///|
fn WasmFunctionCatalog::declare_internal_import(
  self : WasmFunctionCatalog,
  wasm_module : @wasm_types.Module,
  function : @internal_abi.InternalRuntimeFunction,
) -> Unit raise WasmCompileError {
  let type_ = function.type_()
  ignore(
    self.add_entry(
      wasm_module,
      InternalRuntimeImport(function),
      wasm_function_type(type_.params, type_.results),
      Import(module_name=@internal_abi.module_name(), name=function.name()),
      false,
    ),
  )
}

///|
fn WasmFunctionCatalog::declare_wasi_preview1_import(
  self : WasmFunctionCatalog,
  wasm_module : @wasm_types.Module,
  import_ : @wasm_abi.WasiPreview1Import,
) -> Unit raise WasmCompileError {
  let contract = import_.contract()
  ignore(
    self.add_entry(
      wasm_module,
      WasiPreview1Import(import_),
      wasm_function_type(
        contract.core_parameters().map(core_value_type),
        contract.core_results().map(core_value_type),
      ),
      Import(module_name=contract.module_name, name=contract.field_name),
      false,
    ),
  )
}

///|
fn WasmFunctionCatalog::entry(
  self : WasmFunctionCatalog,
  handle : WasmFunctionHandle,
) -> WasmFunctionCatalogEntry {
  self.entries[handle.index]
}

///|
fn WasmFunctionCatalog::find(
  self : WasmFunctionCatalog,
  origin : WasmFunctionOrigin,
) -> WasmFunctionHandle? {
  for entry in self.entries {
    if entry.origin == origin {
      return Some(entry.handle)
    }
  }
  None
}

///|
fn WasmFunctionCatalog::requires(
  self : WasmFunctionCatalog,
  origin : WasmFunctionOrigin,
) -> Bool {
  self.required.contains(origin)
}

///|
fn WasmFunctionCatalog::unreachable_support_role_count(
  self : WasmFunctionCatalog,
) -> Int {
  self.entries.fold(init=0, fn(count, entry) {
    let is_support = match entry.origin {
      RuntimeFunction(_) | HelperFunction(_) => true
      _ => false
    }
    let delta = if is_support && !self.requires(entry.origin) { 1 } else { 0 }
    count + delta
  })
}

///|
fn WasmFunctionCatalog::require(
  self : WasmFunctionCatalog,
  origin : WasmFunctionOrigin,
) -> WasmFunctionHandle {
  self.find(origin).unwrap()
}

///|
fn WasmFunctionCatalog::runtime(
  self : WasmFunctionCatalog,
  role : WasmRuntimeFunctionRole,
) -> WasmFunctionHandle {
  self.require(RuntimeFunction(role))
}

///|
fn WasmFunctionCatalog::helper(
  self : WasmFunctionCatalog,
  role : WasmHelperFunctionRole,
) -> WasmFunctionHandle {
  self.require(HelperFunction(role))
}

///|
fn WasmFunctionCatalog::internal_import(
  self : WasmFunctionCatalog,
  function : @internal_abi.InternalRuntimeFunction,
) -> WasmFunctionHandle {
  self.require(InternalRuntimeImport(function))
}

///|
fn WasmFunctionCatalog::wasi_preview1_import(
  self : WasmFunctionCatalog,
  import_ : @wasm_abi.WasiPreview1Import,
) -> WasmFunctionHandle {
  self.require(WasiPreview1Import(import_))
}

///|
fn WasmFunctionCatalog::image_function(
  self : WasmFunctionCatalog,
  function : @physical.FunctionId,
) -> WasmFunctionHandle {
  self.image_functions[function.value - 1]
}

///|
fn WasmFunctionCatalog::physical_import(
  self : WasmFunctionCatalog,
  function : @physical.FunctionId,
) -> WasmFunctionHandle {
  self.physical_imports[function.value - 1].unwrap()
}

///|
fn WasmFunctionCatalog::table_slot(
  self : WasmFunctionCatalog,
  handle : WasmFunctionHandle,
) -> WasmTableSlot {
  self.entry(handle).table_slot.unwrap()
}

///|
fn WasmFunctionCatalog::image_table_slot(
  self : WasmFunctionCatalog,
  function : @physical.FunctionId,
) -> WasmTableSlot? {
  self.entry(self.image_function(function)).table_slot
}

///|
fn WasmFunctionCatalog::callable_value_table_size(
  self : WasmFunctionCatalog,
) -> Int {
  let mut size = 1
  for handle in self.image_functions {
    if self.entry(handle).table_slot is Some(slot) {
      size = slot.index + 1
    }
  }
  size
}

///|
fn WasmFunctionCatalog::provenance(
  self : WasmFunctionCatalog,
) -> Array[WasmFunctionProvenance] {
  self.entries.map(entry => { index: entry.handle.index, origin: entry.origin, })
}

///|
fn expected_function_type(
  image : @physical.PhysicalProgram,
  origin : WasmFunctionOrigin,
) -> WasmFunctionType raise WasmCompileError {
  match origin {
    InternalRuntimeImport(function) => {
      let type_ = function.type_()
      wasm_function_type(type_.params, type_.results)
    }
    WasiPreview1Import(import_) => {
      let contract = import_.contract()
      wasm_function_type(
        contract.core_parameters().map(core_value_type),
        contract.core_results().map(core_value_type),
      )
    }
    PhysicalRuntimeImport(function~, ..) => {
      if function.value <= 0 || function.value > image.functions.length() {
        raise InvalidFunctionCatalog(
          detail="physical import role has an invalid FunctionId",
        )
      }
      let import_ = match image.functions[function.value - 1] {
        RuntimeImport(import_) => import_
        PhysicalBody(_) =>
          raise InvalidFunctionCatalog(
            detail="physical import role names a physical body",
          )
      }
      wasm_function_type(
        physical_runtime_parameters(import_),
        runtime_results(import_),
      )
    }
    PhysicalFunction(function~) | RuntimeImportAdapter(function~, ..) => {
      if function.value <= 0 || function.value > image.functions.length() {
        raise InvalidFunctionCatalog(
          detail="image function role has an invalid FunctionId",
        )
      }
      let abi = image.functions[function.value - 1].callable_abi().unwrap()
      wasm_function_type(
        wasm_callable_parameters(abi),
        wasm_function_results(abi.result),
      )
    }
    RuntimeFunction(role) => runtime_function_type(role)
    HelperFunction(role) => helper_function_type(role)
    EntryWrapper => wasm_function_type([], [])
  }
}

///|
fn WasmFunctionCatalog::validate(
  self : WasmFunctionCatalog,
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
  wasm_module : @wasm_types.Module,
) -> Unit raise WasmCompileError {
  let actual_layouts = wasm_runtime_layout_ids(image)
  if self.runtime_layouts.byte_sequence != actual_layouts.byte_sequence ||
    self.runtime_layouts.array != actual_layouts.array ||
    self.runtime_layouts.reference != actual_layouts.reference {
    raise InvalidFunctionCatalog(
      detail="runtime layout identities differ from the physical layout table",
    )
  }
  for root in self.roots {
    if !self.requires(root) {
      raise InvalidFunctionCatalog(
        detail="function root is absent from the dependency closure: \{Repr(root)}",
      )
    }
  }
  for origin in self.required {
    if self.find(origin) is None {
      raise InvalidFunctionCatalog(
        detail="required function is absent from the catalog: \{Repr(origin)}",
      )
    }
    for
      dependency in wasm_function_dependencies(image, global_lifecycle, origin) {
      if !self.requires(dependency) {
        raise InvalidFunctionCatalog(
          detail="function dependency is absent from the closure: \{Repr(origin)} -> \{Repr(dependency)}",
        )
      }
    }
  }
  let closed = close_wasm_function_roots(image, global_lifecycle, self.roots)
  for origin in self.required {
    if !closed.contains(origin) {
      raise InvalidFunctionCatalog(
        detail="function dependency closure contains an unreachable function: \{Repr(origin)}",
      )
    }
  }
  let mut definitions_started = false
  let expected_table_entries : Array[WasmFunctionHandle] = []
  for index, entry in self.entries {
    if !self.requires(entry.origin) {
      raise InvalidFunctionCatalog(
        detail="catalog contains an unreachable function: \{Repr(entry.origin)}",
      )
    }
    if entry.handle.index != index {
      raise InvalidFunctionCatalog(detail="function handles are not dense")
    }
    if self.entries[:index].any(previous => previous.origin == entry.origin) {
      raise InvalidFunctionCatalog(
        detail="duplicate function role: \{Repr(entry.origin)}",
      )
    }
    match entry.declaration {
      Import(_) =>
        if definitions_started {
          raise InvalidFunctionCatalog(
            detail="function import follows a definition",
          )
        }
      Defined => definitions_started = true
    }
    if entry.type_ != expected_function_type(image, entry.origin) {
      raise InvalidFunctionCatalog(
        detail="function type does not match role: \{Repr(entry.origin)}",
      )
    }
    let encoded_type = @wasm_types.SubType::func(
      entry.type_.parameters,
      entry.type_.results,
    )
    if entry.type_index < 0 ||
      entry.type_index >= wasm_module.types.length() ||
      wasm_module.types[entry.type_index] != encoded_type {
      raise InvalidFunctionCatalog(
        detail="function type index does not match role: \{Repr(entry.origin)}",
      )
    }
    if entry.table_slot is Some(slot) {
      if entry.declaration is Import(_) {
        raise InvalidFunctionCatalog(
          detail="callable table entry is not a defined body",
        )
      }
      if slot.index != expected_table_entries.length() + 1 {
        raise InvalidFunctionCatalog(
          detail="callable table slots are not dense",
        )
      }
      expected_table_entries.push(entry.handle)
    }
  }
  if expected_table_entries != self.table_entries {
    raise InvalidFunctionCatalog(
      detail="callable table entries differ from catalog slots",
    )
  }
  let address_taken = address_taken_functions(image)
  for index, image_entry in image.functions {
    let function : @physical.FunctionId = { value: index + 1, }
    let handle = self.image_functions[index]
    if handle.index < 0 || handle.index >= self.entries.length() {
      raise InvalidFunctionCatalog(detail="image function has no Wasm body")
    }
    if (self.entry(handle).table_slot is Some(_)) != address_taken[index] {
      raise InvalidFunctionCatalog(
        detail="image callable-table membership is inconsistent",
      )
    }
    match image_entry {
      PhysicalBody(_) =>
        if self.entry(handle).origin != PhysicalFunction(function~) ||
          self.physical_imports[index] is Some(_) {
          raise InvalidFunctionCatalog(
            detail="physical function mapping is inconsistent",
          )
        }
      RuntimeImport(import_) =>
        if self.entry(handle).origin !=
          RuntimeImportAdapter(
            function~,
            module_name=import_.module_name,
            field_name=import_.field_name,
          ) ||
          self.physical_imports[index] is None ||
          self.entry(self.physical_imports[index].unwrap()).origin !=
          PhysicalRuntimeImport(
            function~,
            module_name=import_.module_name,
            field_name=import_.field_name,
          ) {
          raise InvalidFunctionCatalog(
            detail="runtime import mapping is inconsistent",
          )
        }
    }
  }
  let cleanup = self.find(RuntimeFunction(InstanceGlobalCleanup))
  if (cleanup is Some(_)) != !global_lifecycle.owned_roots.is_empty() {
    raise InvalidFunctionCatalog(
      detail="instance-global cleanup does not match lifecycle plan",
    )
  }
  for role in helper_function_order(image) {
    guard self.find(HelperFunction(role)) is Some(handle) else { continue }
    let is_layout_helper = helper_is_layout_callback(role)
    if (self.entry(handle).table_slot is Some(_)) != is_layout_helper {
      raise InvalidFunctionCatalog(
        detail="helper function table membership does not match its role: \{Repr(role)}",
      )
    }
  }
  if self.find(EntryWrapper) is None {
    raise InvalidFunctionCatalog(detail="missing entry wrapper")
  }
}

///|
fn WasmFunctionHandle::call(
  self : WasmFunctionHandle,
) -> @wasm_types.Instruction {
  Call(self.index)
}

///|
fn WasmFunctionHandle::return_call(
  self : WasmFunctionHandle,
) -> @wasm_types.Instruction {
  ReturnCall(self.index)
}

///|
fn WasmFunctionHandle::ref_func(
  self : WasmFunctionHandle,
) -> @wasm_types.Instruction {
  RefFunc(self.index)
}

///|
fn plan_wasm_function_catalog(
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
  wasm_module : @wasm_types.Module,
) -> WasmFunctionCatalog raise WasmCompileError {
  let requirements = plan_wasm_function_requirements(image, global_lifecycle)
  let runtime_layouts = wasm_runtime_layout_ids(image)
  let catalog = WasmFunctionCatalog::new(image, requirements, runtime_layouts)
  for function in @internal_abi.functions() {
    if catalog.requires(InternalRuntimeImport(function)) {
      catalog.declare_internal_import(wasm_module, function)
    }
  }
  for import_ in @wasm_abi.wasi_preview1_imports() {
    if catalog.requires(WasiPreview1Import(import_)) {
      catalog.declare_wasi_preview1_import(wasm_module, import_)
    }
  }
  for index, entry in image.functions {
    if entry is RuntimeImport(import_) {
      let function : @physical.FunctionId = { value: index + 1, }
      let origin = PhysicalRuntimeImport(
        function~,
        module_name=import_.module_name,
        field_name=import_.field_name,
      )
      guard catalog.requires(origin) else { continue }
      let handle = catalog.add_entry(
        wasm_module,
        origin,
        wasm_function_type(
          physical_runtime_parameters(import_),
          runtime_results(import_),
        ),
        Import(module_name=import_.module_name, name=import_.field_name),
        false,
      )
      catalog.physical_imports[index] = Some(handle)
    }
  }
  let address_taken = address_taken_functions(image)
  for index, entry in image.functions {
    let function : @physical.FunctionId = { value: index + 1, }
    let abi = entry.callable_abi().unwrap()
    let origin = match entry {
      PhysicalBody(_) => PhysicalFunction(function~)
      RuntimeImport(import_) =>
        RuntimeImportAdapter(
          function~,
          module_name=import_.module_name,
          field_name=import_.field_name,
        )
    }
    catalog.image_functions[index] = catalog.add_entry(
      wasm_module,
      origin,
      wasm_function_type(
        wasm_callable_parameters(abi),
        wasm_function_results(abi.result),
      ),
      Defined,
      address_taken[index],
    )
  }
  for role in runtime_function_order() {
    guard catalog.requires(RuntimeFunction(role)) else { continue }
    ignore(
      catalog.add_entry(
        wasm_module,
        RuntimeFunction(role),
        runtime_function_type(role),
        Defined,
        false,
      ),
    )
  }
  for role in helper_function_order(image) {
    guard catalog.requires(HelperFunction(role)) else { continue }
    ignore(
      catalog.add_entry(
        wasm_module,
        HelperFunction(role),
        helper_function_type(role),
        Defined,
        helper_is_layout_callback(role),
      ),
    )
  }
  ignore(
    catalog.add_entry(
      wasm_module,
      EntryWrapper,
      wasm_function_type([], []),
      Defined,
      false,
    ),
  )
  catalog.validate(image, global_lifecycle, wasm_module)
  catalog
}
