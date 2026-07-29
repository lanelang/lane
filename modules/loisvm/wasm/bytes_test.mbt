///|
fn wasm_bytes_trivial_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, erased_companion: None }
}

///|
fn wasm_bytes_owned_slot() -> @bytecode.SlotMetadata {
  { representation: I32, cleanup: OwnedRef, erased_companion: None }
}

///|
test "Wasm executes Byte conversion and shared Bytes update" {
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let owned = wasm_bytes_owned_slot()
  let slots = [
    i64, i32, i64, i64, owned, owned, i64, i64, i32, owned, i32, i32, i64, i64, i32,
    i64, i64,
  ]
  let block = fn(
    instructions : Array[@bytecode.Instruction],
    terminator : @bytecode.Terminator,
  ) -> @bytecode.Block {
    { parameters: [], instructions, terminator }
  }
  let edge = fn(target : Int) -> @bytecode.Edge {
    { target: { value: target }, arguments: [] }
  }
  let entry : @bytecode.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      block(
        [
          ConstInt({ value: 0 }, 511L),
          IntToByte({ value: 1 }, { value: 0 }),
          ByteToInt({ value: 2 }, { value: 1 }),
          ConstInt({ value: 15 }, 255L),
          IntEq({ value: 14 }, { value: 2 }, { value: 15 }),
        ],
        BranchBool({ value: 14 }, edge(1), edge(5)),
      ),
      block(
        [
          ConstInt({ value: 3 }, 2L),
          BytesMake({ value: 4 }, { value: 3 }, { value: 1 }),
          BytesLength({ value: 16 }, { value: 4 }),
          IntEq({ value: 14 }, { value: 16 }, { value: 3 }),
        ],
        BranchBool({ value: 14 }, edge(2), edge(5)),
      ),
      block(
        [
          RetainCopy({ value: 5 }, { value: 4 }),
          ConstInt({ value: 6 }, 1L),
          ConstInt({ value: 7 }, 0L),
          IntToByte({ value: 8 }, { value: 7 }),
          BytesSet({ value: 9 }, { value: 4 }, { value: 6 }, { value: 8 }),
          BytesGet({ value: 10 }, { value: 5 }, { value: 6 }),
          BytesGet({ value: 11 }, { value: 9 }, { value: 6 }),
          ByteToInt({ value: 12 }, { value: 10 }),
          ByteToInt({ value: 13 }, { value: 11 }),
          IntEq({ value: 14 }, { value: 12 }, { value: 15 }),
        ],
        BranchBool({ value: 14 }, edge(3), edge(5)),
      ),
      block(
        [IntEq({ value: 14 }, { value: 13 }, { value: 7 })],
        BranchBool({ value: 14 }, edge(4), edge(5)),
      ),
      block([Release({ value: 5 }), Release({ value: 9 })], Return(None)),
      block([], Unreachable),
    ],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Bytes],
    object_shapes: [],
    constants: [],
  }
  let wasm_module = match compile(image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}
