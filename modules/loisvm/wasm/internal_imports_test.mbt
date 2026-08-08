///|
fn complete_internal_import_image() -> @bytecode.BytecodeImage {
  let body = wasm_bytes_body(
    [
      wasm_bytes_trivial_slot(F32),
      wasm_bytes_trivial_slot(F64),
      wasm_bytes_owned_slot(),
      wasm_bytes_owned_slot(),
    ],
    [
      {
        parameters: [],
        instructions: [
          ConstF32({ value: 0 }, 0),
          F32ToString({ value: 2 }, { value: 0 }),
          Release({ value: 2 }),
          ConstF64({ value: 1 }, 0L),
          F64ToString({ value: 3 }, { value: 1 }),
          Release({ value: 3 }),
        ],
        terminator: Return(None),
      },
    ],
  )
  let import_ : @bytecode.RuntimeImport = {
    abi_major: 1,
    parameters: [Opaque],
    result: Unit,
    symbol: "lane.test.consume_host_object",
  }
  {
    ..wasm_bytes_image(body),
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      import_.callable_abi(),
    ],
    functions: [BytecodeBody(body), RuntimeImport(import_)],
    layouts: [Reference],
  }
}

///|
test "float formatting and host objects share internal imports safely" {
  let image = complete_internal_import_image()
  assert_true(compile(image) is Ok(_))
}

///|
test "compiler emits the package-owned internal runtime ABI" {
  let wasm_module = match compile(complete_internal_import_image()) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
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
  assert_eq(
    imports,
    @internal_abi.functions().map(fn(function) {
      (function.name(), function.type_())
    }),
  )
}
