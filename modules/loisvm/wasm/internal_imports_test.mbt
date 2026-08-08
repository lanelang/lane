///|
test "float formatting and host objects share internal imports safely" {
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
  let image = {
    ..wasm_bytes_image(body),
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      import_.callable_abi(),
    ],
    functions: [BytecodeBody(body), RuntimeImport(import_)],
    layouts: [Reference],
  }
  assert_true(compile(image) is Ok(_))
}
