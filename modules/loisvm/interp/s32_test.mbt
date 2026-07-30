///|
fn s32_test_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, erased_companion: None }
}

///|
fn s32_test_edge(target : Int) -> @bytecode.Edge {
  { target: { value: target }, arguments: [] }
}

///|
fn s32_test_image() -> @bytecode.BytecodeImage {
  let slots = [
    s32_test_slot(I32),
    s32_test_slot(I32),
    s32_test_slot(I32),
    s32_test_slot(I64),
    s32_test_slot(I64),
    s32_test_slot(I32),
    s32_test_slot(I64),
    s32_test_slot(I32),
    s32_test_slot(I32),
    s32_test_slot(I32),
  ]
  {
    entry: { value: 1 },
    initializer: None,
    functions: [
      BytecodeBody({
        slots,
        inputs: { environment: None, witnesses: [], user_parameters: [] },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstS32({ value: 0 }, 2147483647),
              ConstS32({ value: 1 }, 1),
              S32Add({ value: 2 }, { value: 0 }, { value: 1 }),
              S32ToInt({ value: 3 }, { value: 2 }),
              ConstInt({ value: 4 }, -2147483647L - 1L),
              IntEq({ value: 5 }, { value: 3 }, { value: 4 }),
            ],
            terminator: BranchBool(
              { value: 5 },
              s32_test_edge(1),
              s32_test_edge(3),
            ),
          },
          {
            parameters: [],
            instructions: [
              ConstInt({ value: 6 }, 4294967295L),
              IntToS32({ value: 7 }, { value: 6 }),
              ConstS32({ value: 8 }, -1),
              S32Eq({ value: 9 }, { value: 7 }, { value: 8 }),
            ],
            terminator: BranchBool(
              { value: 9 },
              s32_test_edge(2),
              s32_test_edge(3),
            ),
          },
          { parameters: [], instructions: [], terminator: Return(None) },
          { parameters: [], instructions: [], terminator: Unreachable },
        ],
      }),
    ],
    globals: [],
    layouts: [S32],
    object_shapes: [],
    constants: [],
  }
}

///|
test "interpreter executes S32 wrapping arithmetic and conversions" {
  let loaded = match load(s32_test_image(), @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "interpreter executes signed S32 division remainder and comparison" {
  let slots = Array::make(4, s32_test_slot(I32))
  let image = {
    ..s32_test_image(),
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
              ConstS32({ value: 0 }, -7),
              ConstS32({ value: 1 }, 2),
              S32Div({ value: 2 }, { value: 0 }, { value: 1 }),
              ConstS32({ value: 1 }, -3),
              S32Eq({ value: 3 }, { value: 2 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 3 },
              s32_test_edge(1),
              s32_test_edge(3),
            ),
          },
          {
            parameters: [],
            instructions: [
              ConstS32({ value: 1 }, 2),
              S32Rem({ value: 2 }, { value: 0 }, { value: 1 }),
              ConstS32({ value: 1 }, -1),
              S32Eq({ value: 3 }, { value: 2 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 3 },
              s32_test_edge(2),
              s32_test_edge(3),
            ),
          },
          {
            parameters: [],
            instructions: [
              ConstS32({ value: 1 }, 2),
              S32Lt({ value: 3 }, { value: 0 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 3 },
              s32_test_edge(4),
              s32_test_edge(3),
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
