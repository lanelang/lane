///|
fn i32_test_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  {
    representation,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
}

///|
fn i32_test_edge(target : Int) -> @bytecode.Edge {
  { target: { value: target }, arguments: [] }
}

///|
fn i32_test_image() -> @bytecode.BytecodeImage {
  let slots = [
    i32_test_slot(I32),
    i32_test_slot(I32),
    i32_test_slot(I32),
    i32_test_slot(I64),
    i32_test_slot(I64),
    i32_test_slot(I32),
    i32_test_slot(I64),
    i32_test_slot(I32),
    i32_test_slot(I32),
    i32_test_slot(I32),
  ]
  {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [
      BytecodeBody({
        slots,
        inputs: { environment: None, witnesses: [], user_parameters: [] },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstI32({ value: 0 }, 2147483647),
              ConstI32({ value: 1 }, 1),
              I32Add({ value: 2 }, { value: 0 }, { value: 1 }),
              I32ToI64({ value: 3 }, { value: 2 }),
              ConstI64({ value: 4 }, -2147483647L - 1L),
              I64Eq({ value: 5 }, { value: 3 }, { value: 4 }),
            ],
            terminator: BranchBool(
              { value: 5 },
              i32_test_edge(1),
              i32_test_edge(3),
            ),
          },
          {
            parameters: [],
            instructions: [
              ConstI64({ value: 6 }, 4294967295L),
              I64ToI32({ value: 7 }, { value: 6 }),
              ConstI32({ value: 8 }, -1),
              I32Eq({ value: 9 }, { value: 7 }, { value: 8 }),
            ],
            terminator: BranchBool(
              { value: 9 },
              i32_test_edge(2),
              i32_test_edge(3),
            ),
          },
          { parameters: [], instructions: [], terminator: Return(None) },
          { parameters: [], instructions: [], terminator: Unreachable },
        ],
      }),
    ],
    globals: [],
    layouts: [I32],
    object_shapes: [],
    constants: [],
  }
}

///|
test "interpreter executes I32 wrapping arithmetic and conversions" {
  let loaded = match load(i32_test_image(), @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "interpreter executes signed I32 division remainder and comparison" {
  let slots = Array::make(4, i32_test_slot(I32))
  let image = {
    ..i32_test_image(),
    layouts: [],
    functions: [
      BytecodeBody({
        slots,
        inputs: { environment: None, witnesses: [], user_parameters: [] },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstI32({ value: 0 }, -7),
              ConstI32({ value: 1 }, 2),
              I32Div({ value: 2 }, { value: 0 }, { value: 1 }),
              ConstI32({ value: 1 }, -3),
              I32Eq({ value: 3 }, { value: 2 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 3 },
              i32_test_edge(1),
              i32_test_edge(3),
            ),
          },
          {
            parameters: [],
            instructions: [
              ConstI32({ value: 1 }, 2),
              I32Rem({ value: 2 }, { value: 0 }, { value: 1 }),
              ConstI32({ value: 1 }, -1),
              I32Eq({ value: 3 }, { value: 2 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 3 },
              i32_test_edge(2),
              i32_test_edge(3),
            ),
          },
          {
            parameters: [],
            instructions: [
              ConstI32({ value: 1 }, 2),
              I32Lt({ value: 3 }, { value: 0 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 3 },
              i32_test_edge(4),
              i32_test_edge(3),
            ),
          },
          { parameters: [], instructions: [], terminator: Unreachable },
          { parameters: [], instructions: [], terminator: Return(None) },
        ],
      }),
    ],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}
