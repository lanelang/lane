///|
test "interpreter executes character constants" {
  let slots = Array::make(3, s32_test_slot(I32))
  let image : @bytecode.BytecodeImage = {
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
              ConstChar({ value: 0 }, 0x1F600),
              ConstChar({ value: 1 }, 0x1F600),
              S32Eq({ value: 2 }, { value: 0 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 2 },
              s32_test_edge(1),
              s32_test_edge(2),
            ),
          },
          { parameters: [], instructions: [], terminator: Return(None) },
          { parameters: [], instructions: [], terminator: Unreachable },
        ],
      }),
    ],
    globals: [],
    layouts: [Char],
    object_shapes: [],
    constants: [],
  }
  let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}
