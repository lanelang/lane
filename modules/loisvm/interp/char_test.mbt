///|
test "interpreter executes character constants" {
  let slots = Array::make(3, i32_test_slot(I32))
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
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
              I32Eq({ value: 2 }, { value: 0 }, { value: 1 }),
            ],
            terminator: BranchBool(
              { value: 2 },
              i32_test_edge(1),
              i32_test_edge(2),
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
