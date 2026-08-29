///|
priv struct WasmFunctionRequirements {
  roots : Array[WasmFunctionOrigin]
  required : Array[WasmFunctionOrigin]
}

///|
fn require_wasm_function(
  functions : Array[WasmFunctionOrigin],
  origin : WasmFunctionOrigin,
) -> Unit {
  if !functions.contains(origin) {
    functions.push(origin)
  }
}

///|
fn image_function_origin(
  image : @physical.PhysicalProgram,
  function : @physical.FunctionId,
) -> WasmFunctionOrigin {
  match image.functions[function.value - 1] {
    PhysicalBody(_) => PhysicalFunction(function~)
    RuntimeImport(import_) =>
      RuntimeImportAdapter(
        function~,
        module_name=import_.module_name,
        field_name=import_.field_name,
      )
  }
}

///|
fn require_reference_operation(
  dependencies : Array[WasmFunctionOrigin],
  cleanup : @physical.Cleanup,
  retain : Bool,
) -> Unit {
  match cleanup {
    OwnedRef | OwnedCallable =>
      require_wasm_function(
        dependencies,
        RuntimeFunction(if retain { RetainReference } else { ReleaseReference }),
      )
    Trivial | OwnedErased => ()
  }
}

///|
fn require_physical_instruction_dependencies(
  image : @physical.PhysicalProgram,
  body : @physical.FunctionBody,
  instruction : @physical.Instruction,
  dependencies : Array[WasmFunctionOrigin],
) -> Unit {
  match instruction {
    RetainCopy(destination, _) =>
      require_reference_operation(
        dependencies,
        body.slots[destination.value].cleanup,
        true,
      )
    Release(source) =>
      require_reference_operation(
        dependencies,
        body.slots[source.value].cleanup,
        false,
      )
    ConstFunction(_, target) | MakeClosure(_, target, _) =>
      require_wasm_function(dependencies, image_function_origin(image, target))
    CallDirect(target, _, _, _, _) =>
      require_wasm_function(dependencies, image_function_origin(image, target))
    CallPackedDirect(target, _, _, _, _) => {
      require_wasm_function(dependencies, image_function_origin(image, target))
      require_wasm_function(
        dependencies,
        HelperFunction(PackedCallableTargetGuard),
      )
    }
    CallValue(_, _, _, _, _) =>
      require_wasm_function(dependencies, HelperFunction(CallableAbiGuard))
    MakeData(_, _, _, _, _) | MakeEnv(_, _, _, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(Allocate))
    ConsumeFields(shape, _, selections)
    | ConsumeCaptures(shape, _, selections) => {
      require_wasm_function(dependencies, RuntimeFunction(ReleaseReference))
      let members = match image.object_shapes[shape.value] {
        Data(shape) => shape.members
        Environment(shape) => shape.members
      }
      for selection in selections {
        require_reference_operation(
          dependencies,
          members[selection.member_index].cleanup,
          true,
        )
      }
    }
    ByteSequenceMake(_, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceMake))
    ByteSequenceLength(_, _) =>
      require_wasm_function(
        dependencies,
        RuntimeFunction(RequireByteSequenceLayout),
      )
    ByteSequenceGet(_, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceGet))
    ByteSequenceSet(_, _, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceSet))
    ByteSequenceEqual(_, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceEqual))
    ByteSequenceConcat(_, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceConcat))
    ByteSequenceSlice(_, _, _, _) =>
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceSlice))
    ByteSequenceIsValidUtf8(_, _) =>
      require_wasm_function(
        dependencies,
        RuntimeFunction(ByteSequenceIsValidUtf8),
      )
    WasiFdWrite(_, _, _) => {
      require_wasm_function(dependencies, WasiPreview1Import(FdWrite))
      require_wasm_function(
        dependencies,
        RuntimeFunction(RequireByteSequenceLayout),
      )
    }
    F32ToString(_, _) => {
      require_wasm_function(dependencies, InternalRuntimeImport(F32ToString))
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceNew))
    }
    F64ToString(_, _) => {
      require_wasm_function(dependencies, InternalRuntimeImport(F64ToString))
      require_wasm_function(dependencies, RuntimeFunction(ByteSequenceNew))
    }
    _ => ()
  }
}

///|
fn require_physical_terminator_dependencies(
  image : @physical.PhysicalProgram,
  terminator : @physical.Terminator,
  dependencies : Array[WasmFunctionOrigin],
) -> Unit {
  match terminator {
    TailCallDirect(target, _, _, _) =>
      require_wasm_function(dependencies, image_function_origin(image, target))
    TailCallPackedDirect(target, _, _, _) => {
      require_wasm_function(dependencies, image_function_origin(image, target))
      require_wasm_function(
        dependencies,
        HelperFunction(PackedCallableTargetGuard),
      )
    }
    TailCallValue(_, _, _, _) =>
      require_wasm_function(dependencies, HelperFunction(CallableAbiGuard))
    Fatal(_) =>
      require_wasm_function(dependencies, InternalRuntimeImport(FatalString))
    _ => ()
  }
}

///|
fn physical_body_dependencies(
  image : @physical.PhysicalProgram,
  body : @physical.FunctionBody,
) -> Array[WasmFunctionOrigin] {
  let dependencies : Array[WasmFunctionOrigin] = []
  for slot in body.slots {
    require_reference_operation(dependencies, slot.cleanup, false)
  }
  for block in body.blocks {
    for instruction in block.instructions {
      require_physical_instruction_dependencies(
        image, body, instruction, dependencies,
      )
    }
    require_physical_terminator_dependencies(
      image,
      block.terminator,
      dependencies,
    )
  }
  dependencies
}

///|
fn runtime_import_adapter_dependencies(
  function : @physical.FunctionId,
  import_ : @wasm_abi.ImportContract,
) -> Array[WasmFunctionOrigin] {
  let dependencies : Array[WasmFunctionOrigin] = [
    PhysicalRuntimeImport(
      function~,
      module_name=import_.module_name,
      field_name=import_.field_name,
    ),
  ]
  dependencies
}

///|
fn runtime_function_dependencies(
  role : WasmRuntimeFunctionRole,
  global_lifecycle : @physical.GlobalLifecyclePlan,
) -> Array[WasmFunctionOrigin] {
  let dependencies : Array[WasmFunctionOrigin] = []
  match role {
    Allocate | Free | RetainReference | RequireByteSequenceLayout => ()
    ReleaseReference => dependencies.push(RuntimeFunction(Free))
    ByteSequenceNew => dependencies.push(RuntimeFunction(Allocate))
    ByteSequenceEqual | ByteSequenceIndex | ByteSequenceIsValidUtf8 =>
      dependencies.push(RuntimeFunction(RequireByteSequenceLayout))
    ByteSequenceConcat | ByteSequenceSlice =>
      dependencies.append([
        RuntimeFunction(RequireByteSequenceLayout),
        RuntimeFunction(ByteSequenceNew),
        RuntimeFunction(ReleaseReference),
      ])
    ByteSequenceMake => dependencies.push(RuntimeFunction(ByteSequenceNew))
    ByteSequenceGet => dependencies.push(RuntimeFunction(ByteSequenceIndex))
    ByteSequenceSet =>
      dependencies.append([
        RuntimeFunction(ByteSequenceNew),
        RuntimeFunction(ByteSequenceIndex),
        RuntimeFunction(ReleaseReference),
      ])
    InstanceGlobalCleanup =>
      for root in global_lifecycle.owned_roots {
        require_reference_operation(dependencies, root.cleanup, false)
      }
  }
  dependencies
}

///|
fn helper_function_dependencies(
  image : @physical.PhysicalProgram,
  role : WasmHelperFunctionRole,
) -> Array[WasmFunctionOrigin] {
  let dependencies : Array[WasmFunctionOrigin] = []
  match role {
    CallableAbiGuard
    | PackedCallableTargetGuard
    | NoopErased
    | DestroyNoop
    | ByteSequenceSizer => ()
    RetainReferenceErased | RetainCallable =>
      dependencies.push(RuntimeFunction(RetainReference))
    ReleaseReferenceErased | ReleaseCallable =>
      dependencies.push(RuntimeFunction(ReleaseReference))
    DestroyShape(shape~) => {
      let members = match image.object_shapes[shape] {
        Data(shape) => shape.members
        Environment(shape) => shape.members
      }
      for schema in members {
        require_reference_operation(dependencies, schema.cleanup, false)
      }
    }
  }
  dependencies
}

///|
fn entry_wrapper_dependencies(
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
) -> Array[WasmFunctionOrigin] {
  let dependencies : Array[WasmFunctionOrigin] = [
    image_function_origin(image, image.entry),
  ]
  if image.initializer is Some(initializer) {
    require_wasm_function(
      dependencies,
      image_function_origin(image, initializer),
    )
  }
  if !global_lifecycle.owned_roots.is_empty() {
    dependencies.push(RuntimeFunction(InstanceGlobalCleanup))
  }
  dependencies
}

///|
fn wasm_function_dependencies(
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
  origin : WasmFunctionOrigin,
) -> Array[WasmFunctionOrigin] raise WasmCompileError {
  match origin {
    WasiPreview1Import(_) => []
    InternalRuntimeImport(_) => []
    PhysicalRuntimeImport(function~, ..) =>
      match image.functions[function.value - 1] {
        RuntimeImport(_) => []
        PhysicalBody(_) =>
          raise InvalidFunctionCatalog(
            detail="physical import requirement names a physical body",
          )
      }
    PhysicalFunction(function~) =>
      match image.functions[function.value - 1] {
        PhysicalBody(body) => physical_body_dependencies(image, body)
        RuntimeImport(_) =>
          raise InvalidFunctionCatalog(
            detail="physical function requirement names a runtime import",
          )
      }
    RuntimeImportAdapter(function~, ..) =>
      match image.functions[function.value - 1] {
        RuntimeImport(import_) =>
          runtime_import_adapter_dependencies(function, import_)
        PhysicalBody(_) =>
          raise InvalidFunctionCatalog(
            detail="runtime adapter requirement names a physical body",
          )
      }
    RuntimeFunction(role) =>
      runtime_function_dependencies(role, global_lifecycle)
    HelperFunction(role) => helper_function_dependencies(image, role)
    EntryWrapper => entry_wrapper_dependencies(image, global_lifecycle)
  }
}

///|
fn require_layout_support(
  roots : Array[WasmFunctionOrigin],
  layout : @physical.LayoutRecipe,
) -> Unit {
  match layout {
    Unit | Bool | I64 | I32 | Char | F64 | F32 | Byte => {
      require_wasm_function(roots, HelperFunction(NoopErased))
      require_wasm_function(roots, HelperFunction(DestroyNoop))
    }
    Callable => {
      require_wasm_function(roots, HelperFunction(RetainCallable))
      require_wasm_function(roots, HelperFunction(ReleaseCallable))
      require_wasm_function(roots, HelperFunction(DestroyNoop))
    }
    ByteSequence => {
      require_wasm_function(roots, HelperFunction(ByteSequenceSizer))
      require_wasm_function(roots, HelperFunction(RetainReferenceErased))
      require_wasm_function(roots, HelperFunction(ReleaseReferenceErased))
      require_wasm_function(roots, HelperFunction(DestroyNoop))
    }
    Data(shape) | Environment(shape) => {
      require_wasm_function(roots, HelperFunction(RetainReferenceErased))
      require_wasm_function(roots, HelperFunction(ReleaseReferenceErased))
      require_wasm_function(
        roots,
        HelperFunction(DestroyShape(shape=shape.value)),
      )
    }
    Reference => {
      require_wasm_function(roots, HelperFunction(RetainReferenceErased))
      require_wasm_function(roots, HelperFunction(ReleaseReferenceErased))
      require_wasm_function(roots, HelperFunction(DestroyNoop))
    }
  }
}

///|
fn close_wasm_function_roots(
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
  roots : Array[WasmFunctionOrigin],
) -> Array[WasmFunctionOrigin] raise WasmCompileError {
  let required = roots.copy()
  let mut cursor = 0
  while cursor < required.length() {
    let origin = required[cursor]
    for
      dependency in wasm_function_dependencies(image, global_lifecycle, origin) {
      require_wasm_function(required, dependency)
    }
    cursor += 1
  }
  required
}

///|
fn plan_wasm_function_requirements(
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
) -> WasmFunctionRequirements raise WasmCompileError {
  let roots : Array[WasmFunctionOrigin] = []
  for index, _ in image.functions {
    let function : @physical.FunctionId = { value: index + 1, }
    require_wasm_function(roots, image_function_origin(image, function))
  }
  for layout in image.layouts {
    require_layout_support(roots, layout)
  }
  require_wasm_function(roots, EntryWrapper)
  let required = close_wasm_function_roots(image, global_lifecycle, roots)
  { roots, required, }
}
