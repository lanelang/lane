///|
fn compile_initializer_wrapper(
  image : @physical.PhysicalProgram,
  function_catalog : WasmFunctionCatalog,
) -> Array[@wasm_types.Instruction] {
  match image.initializer {
    Some(initializer) =>
      [I32Const(0), function_catalog.image_function(initializer).call(), Return]
    None => [Return]
  }
}

///|
fn compile_export_wrapper(
  image : @physical.PhysicalProgram,
  export_ : @physical.PhysicalExport,
  function_catalog : WasmFunctionCatalog,
) -> Array[@wasm_types.Instruction] {
  let body : Array[@wasm_types.Instruction] = [I32Const(0)]
  let abi = image.function_callable_abi(export_.function()).unwrap()
  for parameter_index, _ in abi.parameters {
    body.push(LocalGet(parameter_index))
  }
  body.push(function_catalog.image_function(export_.function()).call())
  body.push(Return)
  body
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
