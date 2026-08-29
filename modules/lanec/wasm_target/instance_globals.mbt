///|
fn compile_entry_lifecycle(
  image : @physical.PhysicalProgram,
  function_catalog : WasmFunctionCatalog,
) -> Array[@wasm_types.Instruction] {
  let guarded : Array[@wasm_types.Instruction] = []
  if image.initializer is Some(initializer) {
    guarded.append([
      I32Const(0),
      function_catalog.image_function(initializer).call(),
    ])
  }
  guarded.append([
    I32Const(0),
    function_catalog.image_function(image.entry).call(),
  ])
  match function_catalog.find(RuntimeFunction(InstanceGlobalCleanup)) {
    None => guarded + [Return]
    Some(cleanup_function) => {
      guarded.push(cleanup_function.call())
      guarded.push(Return)
      [Block(Empty, [TryTable(Empty, [Catch(0, 0)], guarded), Unreachable])] +
      [cleanup_function.call(), Throw(0)]
    }
  }
}

///|
fn compile_global_initialization(
  locals : FunctionLocalPlan,
  slots : Array[@physical.SlotMetadata],
  static_image : StaticImage,
  global : @physical.GlobalId,
  source : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  let metadata = static_image.globals[global.value]
  let address = global_address(static_image, global)
  let instructions : Array[@wasm_types.Instruction] = []
  if metadata.cleanup is OwnedErased {
    let companion = metadata.erased_companion.unwrap()
    let companion_address = global_address(static_image, companion)
    let source_companion = slots[source.value].erased_companion.unwrap()
    instructions.append([
      I32Const(companion_address),
      LocalGet(locals.slot_local(source_companion)),
      I32Store(0, 2, 0L),
    ])
  }
  instructions.push(I32Const(address))
  instructions.push(LocalGet(locals.slot_local(source)))
  instructions.push(global_store(metadata.representation, 0L))
  let root_ordinal = static_image.global_lifecycle.root_ordinals[global.value]
  if static_image.global_lifecycle.roots[root_ordinal].owned_ordinal
    is Some(owned_ordinal) {
    instructions.append([
      I32Const(owned_ordinal + 1),
      GlobalSet(initialized_owned_root_count_global_index),
    ])
  }
  instructions.append(locals.mark_slot_dead(source))
  instructions
}

///|
fn compile_global_borrow(
  locals : FunctionLocalPlan,
  slots : Array[@physical.SlotMetadata],
  static_image : StaticImage,
  destination : @physical.SlotId,
  global : @physical.GlobalId,
) -> Array[@wasm_types.Instruction] {
  let metadata = static_image.globals[global.value]
  let address = global_address(static_image, global)
  let instructions : Array[@wasm_types.Instruction] = []
  if metadata.cleanup is OwnedErased {
    let companion = metadata.erased_companion.unwrap()
    let companion_address = global_address(static_image, companion)
    let destination_companion = slots[destination.value].erased_companion.unwrap()
    instructions.append([
      I32Const(companion_address),
      I32Load(0, 2, 0L),
      LocalSet(locals.slot_local(destination_companion)),
    ])
  }
  instructions.push(I32Const(address))
  instructions.push(global_load(metadata.representation, 0L))
  instructions.push(LocalSet(locals.slot_local(destination)))
  instructions
}

///|
fn compile_global_cleanup_function(
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
  wasm_module : @wasm_types.Module,
) -> @wasm_types.FunctionCode {
  {
    locals: [I32, I32, I32],
    body: global_cleanup_body(
      static_image,
      function_catalog,
      intern_function_type(wasm_module, [I64], []),
    ),
  }
}

///|
fn global_cleanup_body(
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
  erased_release_type : Int,
) -> Array[@wasm_types.Instruction] {
  [
    Block(Empty, [
      Loop(Empty, [
        GlobalGet(initialized_owned_root_count_global_index),
        I32Eqz,
        BrIf(1),
        GlobalGet(initialized_owned_root_count_global_index),
        I32Const(1),
        I32Sub,
        LocalTee(0),
        GlobalSet(initialized_owned_root_count_global_index),
        LocalGet(0),
        I32Const(4),
        I32Mul,
        I32Const(static_image.global_cleanup_table_base),
        I32Add,
        I32Load(0, 2, 0L),
        LocalTee(1),
        I32Const(2),
        I32ShrU,
        I32Const(8),
        I32Mul,
        I32Const(static_image.global_table_base),
        I32Add,
        LocalSet(2),
        LocalGet(1),
        I32Const(3),
        I32And,
        I32Const(1),
        I32Eq,
        If(
          Empty,
          [
            LocalGet(2),
            I32Load(0, 2, 0L),
            function_catalog.runtime(ReleaseReference).call(),
          ],
          [],
        ),
        LocalGet(1),
        I32Const(3),
        I32And,
        I32Const(2),
        I32Eq,
        If(
          Empty,
          [
            LocalGet(2),
            I64Load(0, 3, 0L),
            I64Const(32L),
            I64ShrU,
            I32WrapI64,
            function_catalog.runtime(ReleaseReference).call(),
          ],
          [],
        ),
        LocalGet(1),
        I32Const(3),
        I32And,
        I32Const(3),
        I32Eq,
        If(
          Empty,
          [
            LocalGet(2),
            I64Load(0, 3, 0L),
            LocalGet(2),
            I32Const(8),
            I32Sub,
            I32Load(0, 2, 0L),
            I32Const(5),
            I32Shl,
            GlobalGet(layout_table_base_global_index),
            I32Add,
            I32Load(0, 2, 20L),
            CallIndirect(erased_release_type, 0),
          ],
          [],
        ),
        Br(0),
      ]),
    ]),
    Return,
  ]
}

///|
fn global_address(
  static_image : StaticImage,
  global : @physical.GlobalId,
) -> Int {
  static_image.global_table_base + global.value * 8
}

///|
fn global_store(
  representation : @physical.Representation,
  offset : Int64,
) -> @wasm_types.Instruction {
  match representation {
    I32 => I32Store(0, 2, offset)
    I64 => I64Store(0, 3, offset)
    F64 => F64Store(0, 3, offset)
    F32 => F32Store(0, 2, offset)
  }
}

///|
fn global_load(
  representation : @physical.Representation,
  offset : Int64,
) -> @wasm_types.Instruction {
  match representation {
    I32 => I32Load(0, 2, offset)
    I64 => I64Load(0, 3, offset)
    F64 => F64Load(0, 3, offset)
    F32 => F32Load(0, 2, offset)
  }
}
