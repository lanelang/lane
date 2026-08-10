///|
fn internal_import_image(
  uses_f32~ : Bool,
  uses_f64~ : Bool,
  uses_host_objects~ : Bool,
) -> @bytecode.BytecodeImage {
  let slots : Array[@bytecode.SlotMetadata] = []
  let instructions : Array[@bytecode.Instruction] = []
  if uses_f32 {
    let source : @bytecode.SlotId = { value: slots.length() }
    slots.push(wasm_bytes_trivial_slot(F32))
    let destination : @bytecode.SlotId = { value: slots.length() }
    slots.push(wasm_bytes_owned_slot())
    instructions.push(ConstF32(source, 0))
    instructions.push(F32ToString(destination, source))
    instructions.push(Release(destination))
  }
  if uses_f64 {
    let source : @bytecode.SlotId = { value: slots.length() }
    slots.push(wasm_bytes_trivial_slot(F64))
    let destination : @bytecode.SlotId = { value: slots.length() }
    slots.push(wasm_bytes_owned_slot())
    instructions.push(ConstF64(source, 0L))
    instructions.push(F64ToString(destination, source))
    instructions.push(Release(destination))
  }
  let body = wasm_bytes_body(slots, [
    { parameters: [], instructions, terminator: Return(None) },
  ])
  let image = wasm_bytes_image(body)
  if !uses_host_objects {
    return image
  }
  let import_ : @bytecode.RuntimeImport = {
    abi_major: 1,
    parameters: [Opaque],
    result: Unit,
    symbol: "lane.test.consume_host_object",
  }
  {
    ..image,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      import_.callable_abi(),
    ],
    functions: [BytecodeBody(body), RuntimeImport(import_)],
    layouts: [ByteSequence, Reference],
  }
}

///|
fn internal_import_observation(
  wasm_module : @wasm_types.Module,
) -> Array[(String, @wasm_types.FuncType)] raise {
  let imports = []
  for import_ in wasm_module.imports {
    guard import_.mod_name == @internal_abi.module_name() else { continue }
    guard import_.desc is Func(type_index) else {
      fail("internal runtime import is not a function")
    }
    guard wasm_module.types[type_index].composite is Func(type_) else {
      fail("internal runtime import does not reference a function type")
    }
    imports.push((import_.name, type_))
  }
  imports
}

///|
test "compiler emits selected internal imports in canonical order" {
  let cases : Array[
    (Bool, Bool, Bool, Array[@internal_abi.InternalRuntimeFunction]),
  ] = [
    (false, false, false, []),
    (true, false, false, [F32ToString]),
    (false, true, false, [F64ToString]),
    (true, true, false, [F32ToString, F64ToString]),
    (false, false, true, [HostObjectRelease]),
    (true, false, true, [F32ToString, HostObjectRelease]),
    (false, true, true, [F64ToString, HostObjectRelease]),
    (true, true, true, @internal_abi.functions()),
  ]
  let actual = []
  let expected = []
  for case in cases {
    let (uses_f32, uses_f64, uses_host_objects, functions) = case
    let image = internal_import_image(uses_f32~, uses_f64~, uses_host_objects~)
    let wasm_module = match compile(image) {
      Ok(module_) => module_
      Err(error) => fail("compile failed: \{Repr(error)}")
    }
    actual.push(internal_import_observation(wasm_module))
    expected.push(
      functions.map(fn(function) { (function.name(), function.type_()) }),
    )
  }
  assert_eq(actual, expected)
}
