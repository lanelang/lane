///|
let instance_global_failure_code = 4

///|
fn compile_entry_lifecycle(
  image : @bytecode.BytecodeImage,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
) -> Array[@wasm_types.Instruction] {
  let guarded : Array[@wasm_types.Instruction] = []
  if image.initializer is Some(initializer) {
    guarded.append([
      I32Const(1),
      GlobalSet(initializing_global_index),
      I32Const(0),
      Call(static_image.wasm_function_offset + initializer.value - 1),
    ])
    guarded.append(compile_global_completeness_check(static_image))
    guarded.append([I32Const(0), GlobalSet(initializing_global_index)])
  }
  guarded.append([
    I32Const(0),
    Call(static_image.wasm_function_offset + image.entry.value - 1),
  ])
  guarded.append(
    compile_global_cleanup(static_image, wasm_module, runtime_functions),
  )
  guarded.push(Return)
  let exceptional_cleanup = compile_global_cleanup(
    static_image, wasm_module, runtime_functions,
  )
  [Block(Empty, [TryTable(Empty, [Catch(0, 0)], guarded), Unreachable])] +
  exceptional_cleanup +
  [Throw(0)]
}

///|
fn compile_global_initialization(
  parameter_count : Int,
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  static_image : StaticImage,
  global : @bytecode.GlobalId,
  source : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  if is_companion_global(static_image, global) {
    return global_failure()
  }
  let metadata = static_image.globals[global.value]
  let address = global_address(static_image, global)
  let instructions : Array[@wasm_types.Instruction] = [
    GlobalGet(initializing_global_index),
    I32Eqz,
    If(Empty, global_failure(), []),
    I32Const(address),
    I32Load(0, 2, 0L),
    If(Empty, global_failure(), []),
  ]
  if metadata.cleanup is OwnedErased {
    let companion = metadata.erased_companion.unwrap()
    let companion_address = global_address(static_image, companion)
    let source_companion = slots[source.value].erased_companion.unwrap()
    instructions.append([
      I32Const(companion_address),
      I32Load(0, 2, 0L),
      If(Empty, global_failure(), []),
      I32Const(companion_address),
      LocalGet(slot_local(parameter_count, source_companion)),
      I32Store(0, 2, 8L),
      I32Const(companion_address),
      I32Const(1),
      I32Store(0, 2, 0L),
    ])
  }
  instructions.push(I32Const(address))
  instructions.push(LocalGet(slot_local(parameter_count, source)))
  instructions.push(global_store(metadata.representation, 8L))
  instructions.append([I32Const(address), I32Const(1), I32Store(0, 2, 0L)])
  instructions.append(mark_slot_dead(live_base, slots, source))
  instructions
}

///|
fn compile_global_borrow(
  parameter_count : Int,
  slots : Array[@bytecode.SlotMetadata],
  static_image : StaticImage,
  destination : @bytecode.SlotId,
  global : @bytecode.GlobalId,
) -> Array[@wasm_types.Instruction] {
  let metadata = static_image.globals[global.value]
  let address = global_address(static_image, global)
  let instructions : Array[@wasm_types.Instruction] = [
    I32Const(address),
    I32Load(0, 2, 0L),
    I32Eqz,
    If(Empty, global_failure(), []),
  ]
  if metadata.cleanup is OwnedErased {
    let companion = metadata.erased_companion.unwrap()
    let companion_address = global_address(static_image, companion)
    let destination_companion = slots[destination.value].erased_companion.unwrap()
    instructions.append([
      I32Const(companion_address),
      I32Load(0, 2, 0L),
      I32Eqz,
      If(Empty, global_failure(), []),
      I32Const(companion_address),
      I32Load(0, 2, 8L),
      LocalSet(slot_local(parameter_count, destination_companion)),
    ])
  }
  instructions.push(I32Const(address))
  instructions.push(global_load(metadata.representation, 8L))
  instructions.push(LocalSet(slot_local(parameter_count, destination)))
  instructions
}

///|
fn compile_global_completeness_check(
  static_image : StaticImage,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = []
  for index in 0..<static_image.globals.length() {
    instructions.append([
      I32Const(global_address(static_image, { value: index })),
      I32Load(0, 2, 0L),
      I32Eqz,
      If(Empty, global_failure(), []),
    ])
  }
  instructions
}

///|
fn compile_global_cleanup(
  static_image : StaticImage,
  wasm_module : @wasm_types.Module,
  runtime_functions : RuntimeFunctions,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = []
  let mut index = static_image.globals.length() - 1
  while index >= 0 {
    let global : @bytecode.GlobalId = { value: index }
    if !is_companion_global(static_image, global) {
      let metadata = static_image.globals[index]
      let address = global_address(static_image, global)
      let cleanup : Array[@wasm_types.Instruction] = [
        I32Const(address),
        I32Const(0),
        I32Store(0, 2, 0L),
      ]
      if metadata.cleanup is OwnedErased {
        let companion = metadata.erased_companion.unwrap()
        cleanup.append([
          I32Const(global_address(static_image, companion)),
          I32Const(0),
          I32Store(0, 2, 0L),
        ])
      }
      cleanup.append(
        compile_global_release(
          metadata, address, static_image, wasm_module, runtime_functions,
        ),
      )
      instructions.append([
        I32Const(address),
        I32Load(0, 2, 0L),
        If(Empty, cleanup, []),
      ])
    }
    index -= 1
  }
  instructions
}

///|
fn compile_global_release(
  metadata : @bytecode.GlobalMetadata,
  address : Int,
  static_image : StaticImage,
  wasm_module : @wasm_types.Module,
  runtime_functions : RuntimeFunctions,
) -> Array[@wasm_types.Instruction] {
  match metadata.cleanup {
    Trivial => []
    OwnedRef =>
      [
        I32Const(address),
        I32Load(0, 2, 8L),
        Call(runtime_functions.release_ref),
      ]
    OwnedCallable =>
      [
        I32Const(address),
        I64Load(0, 3, 8L),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
        Call(runtime_functions.release_ref),
      ]
    OwnedErased => {
      let companion = metadata.erased_companion.unwrap()
      let type_index = intern_function_type(wasm_module, [I64], [])
      [
        I32Const(address),
        I64Load(0, 3, 8L),
        I32Const(global_address(static_image, companion)),
        I32Load(0, 2, 8L),
        I32Const(5),
        I32Shl,
        GlobalGet(layout_table_base_global_index),
        I32Add,
        I32Load(0, 2, 20L),
        CallIndirect(type_index, 0),
      ]
    }
  }
}

///|
fn global_address(
  static_image : StaticImage,
  global : @bytecode.GlobalId,
) -> Int {
  static_image.global_table_base + global.value * 16
}

///|
fn is_companion_global(
  static_image : StaticImage,
  global : @bytecode.GlobalId,
) -> Bool {
  static_image.globals.any(metadata => metadata.erased_companion == Some(global))
}

///|
fn global_store(
  representation : @bytecode.Representation,
  offset : Int64,
) -> @wasm_types.Instruction {
  match representation {
    I32 => I32Store(0, 2, offset)
    I64 => I64Store(0, 3, offset)
    F64 => F64Store(0, 3, offset)
  }
}

///|
fn global_load(
  representation : @bytecode.Representation,
  offset : Int64,
) -> @wasm_types.Instruction {
  match representation {
    I32 => I32Load(0, 2, offset)
    I64 => I64Load(0, 3, offset)
    F64 => F64Load(0, 3, offset)
  }
}

///|
fn global_failure() -> Array[@wasm_types.Instruction] {
  [
    I32Const(instance_global_failure_code),
    GlobalSet(failure_code_global_index),
    Throw(0),
  ]
}
