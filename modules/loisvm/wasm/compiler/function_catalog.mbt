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
    HostObjectNew => wasm_function_type([I64], [I32])
    ByteSequenceMake => wasm_function_type([I64, I32], [I32])
    ByteSequenceIndex | ByteSequenceGet => wasm_function_type([I32, I64], [I32])
    ByteSequenceSet => wasm_function_type([I32, I64, I32], [I32])
    ByteSequenceIsValidUtf8 => wasm_function_type([I32], [I32])
    InstanceGlobalCleanup => wasm_function_type([], [])
  }
}

///|
fn helper_function_type(role : WasmHelperFunctionRole) -> WasmFunctionType {
  match role {
    NoopErased
    | RetainReferenceErased
    | ReleaseReferenceErased
    | RetainCallable
    | ReleaseCallable => wasm_function_type([I64], [])
    DestroyNoop | DestroyHostObject | DestroyShape(_) =>
      wasm_function_type([I32], [])
    ByteSequenceSizer => wasm_function_type([I32], [I32])
  }
}

///|
fn runtime_function_roles() -> Array[WasmRuntimeFunctionRole] {
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
    HostObjectNew,
    ByteSequenceMake,
    ByteSequenceIndex,
    ByteSequenceGet,
    ByteSequenceSet,
    ByteSequenceIsValidUtf8,
  ]
}

///|
fn helper_function_roles(shape_count : Int) -> Array[WasmHelperFunctionRole] {
  let roles = [
    NoopErased,
    RetainReferenceErased,
    ReleaseReferenceErased,
    RetainCallable,
    ReleaseCallable,
    DestroyNoop,
    DestroyHostObject,
  ]
  for shape in 0..<shape_count {
    roles.push(DestroyShape(shape~))
  }
  roles.push(ByteSequenceSizer)
  roles
}

///|
fn address_taken_functions(image : @bytecode.BytecodeImage) -> Array[Bool] {
  let address_taken = Array::make(image.functions.length(), false)
  for entry in image.functions {
    guard entry is BytecodeBody(body) else { continue }
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
fn required_internal_runtime_functions(
  image : @bytecode.BytecodeImage,
  host_objects_enabled : Bool,
) -> Array[@internal_abi.InternalRuntimeFunction] {
  let mut uses_f32 = false
  let mut uses_f64 = false
  let mut uses_fatal = false
  for entry in image.functions {
    if entry is BytecodeBody(body) {
      for block in body.blocks {
        for instruction in block.instructions {
          match instruction {
            F32ToString(_, _) => uses_f32 = true
            F64ToString(_, _) => uses_f64 = true
            _ => ()
          }
        }
        if block.terminator is Fatal(_) {
          uses_fatal = true
        }
      }
    }
  }
  @internal_abi.functions().filter(function => {
    match function {
      F32ToString => uses_f32
      F64ToString => uses_f64
      FatalString => uses_fatal
      HostObjectRelease => host_objects_enabled
    }
  })
}

///|
fn WasmFunctionCatalog::new(
  image : @bytecode.BytecodeImage,
) -> WasmFunctionCatalog {
  {
    entries: [],
    image_functions: Array::make(image.functions.length(), { index: -1, }),
    physical_imports: Array::make(image.functions.length(), None),
    table_entries: [],
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
fn WasmFunctionCatalog::image_function(
  self : WasmFunctionCatalog,
  function : @bytecode.FunctionId,
) -> WasmFunctionHandle {
  self.image_functions[function.value - 1]
}

///|
fn WasmFunctionCatalog::physical_import(
  self : WasmFunctionCatalog,
  function : @bytecode.FunctionId,
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
  function : @bytecode.FunctionId,
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
  image : @bytecode.BytecodeImage,
  origin : WasmFunctionOrigin,
) -> WasmFunctionType raise WasmCompileError {
  match origin {
    InternalRuntimeImport(function) => {
      let type_ = function.type_()
      wasm_function_type(type_.params, type_.results)
    }
    PhysicalRuntimeImport(function~, symbol=_) => {
      if function.value <= 0 || function.value > image.functions.length() {
        raise InvalidFunctionCatalog(
          detail="physical import role has an invalid FunctionId",
        )
      }
      let import_ = match image.functions[function.value - 1] {
        RuntimeImport(import_) => import_
        BytecodeBody(_) =>
          raise InvalidFunctionCatalog(
            detail="physical import role names a bytecode body",
          )
      }
      wasm_function_type(
        physical_runtime_parameters(import_),
        runtime_results(import_),
      )
    }
    BytecodeFunction(function~) | RuntimeImportAdapter(function~, symbol=_) => {
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
  image : @bytecode.BytecodeImage,
  global_lifecycle : @bytecode.GlobalLifecyclePlan,
  host_objects_enabled : Bool,
  wasm_module : @wasm_types.Module,
) -> Unit raise WasmCompileError {
  let mut definitions_started = false
  let expected_table_entries : Array[WasmFunctionHandle] = []
  for index, entry in self.entries {
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
    let function : @bytecode.FunctionId = { value: index + 1, }
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
      BytecodeBody(_) =>
        if self.entry(handle).origin != BytecodeFunction(function~) ||
          self.physical_imports[index] is Some(_) {
          raise InvalidFunctionCatalog(
            detail="bytecode function mapping is inconsistent",
          )
        }
      RuntimeImport(import_) =>
        if self.entry(handle).origin !=
          RuntimeImportAdapter(function~, symbol=import_.symbol) ||
          self.physical_imports[index] is None ||
          self.entry(self.physical_imports[index].unwrap()).origin !=
          PhysicalRuntimeImport(function~, symbol=import_.symbol) {
          raise InvalidFunctionCatalog(
            detail="runtime import mapping is inconsistent",
          )
        }
    }
  }
  for role in runtime_function_roles() {
    if self.find(RuntimeFunction(role)) is None {
      raise InvalidFunctionCatalog(
        detail="missing runtime function: \{Repr(role)}",
      )
    }
  }
  let cleanup = self.find(RuntimeFunction(InstanceGlobalCleanup))
  if (cleanup is Some(_)) != !global_lifecycle.owned_roots.is_empty() {
    raise InvalidFunctionCatalog(
      detail="instance-global cleanup does not match lifecycle plan",
    )
  }
  for role in helper_function_roles(image.object_shapes.length()) {
    let handle = match self.find(HelperFunction(role)) {
      Some(handle) => handle
      None =>
        raise InvalidFunctionCatalog(
          detail="missing helper function: \{Repr(role)}",
        )
    }
    if self.entry(handle).table_slot is None {
      raise InvalidFunctionCatalog(
        detail="helper function is missing its callable-table slot: \{Repr(role)}",
      )
    }
  }
  for
    function in required_internal_runtime_functions(image, host_objects_enabled) {
    if self.find(InternalRuntimeImport(function)) is None {
      raise InvalidFunctionCatalog(
        detail="missing internal runtime import: \{Repr(function)}",
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
  image : @bytecode.BytecodeImage,
  global_lifecycle : @bytecode.GlobalLifecyclePlan,
  host_objects_enabled : Bool,
  wasm_module : @wasm_types.Module,
) -> WasmFunctionCatalog raise WasmCompileError {
  let catalog = WasmFunctionCatalog::new(image)
  for
    function in required_internal_runtime_functions(image, host_objects_enabled) {
    catalog.declare_internal_import(wasm_module, function)
  }
  for index, entry in image.functions {
    if entry is RuntimeImport(import_) {
      let function : @bytecode.FunctionId = { value: index + 1, }
      let handle = catalog.add_entry(
        wasm_module,
        PhysicalRuntimeImport(function~, symbol=import_.symbol),
        wasm_function_type(
          physical_runtime_parameters(import_),
          runtime_results(import_),
        ),
        Import(module_name="lane.runtime.v1", name=import_.symbol),
        false,
      )
      catalog.physical_imports[index] = Some(handle)
    }
  }
  let address_taken = address_taken_functions(image)
  for index, entry in image.functions {
    let function : @bytecode.FunctionId = { value: index + 1, }
    let abi = entry.callable_abi().unwrap()
    let origin = match entry {
      BytecodeBody(_) => BytecodeFunction(function~)
      RuntimeImport(import_) =>
        RuntimeImportAdapter(function~, symbol=import_.symbol)
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
  for role in runtime_function_roles() {
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
  for role in helper_function_roles(image.object_shapes.length()) {
    ignore(
      catalog.add_entry(
        wasm_module,
        HelperFunction(role),
        helper_function_type(role),
        Defined,
        true,
      ),
    )
  }
  if !global_lifecycle.owned_roots.is_empty() {
    ignore(
      catalog.add_entry(
        wasm_module,
        RuntimeFunction(InstanceGlobalCleanup),
        runtime_function_type(InstanceGlobalCleanup),
        Defined,
        false,
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
  catalog.validate(image, global_lifecycle, host_objects_enabled, wasm_module)
  catalog
}
