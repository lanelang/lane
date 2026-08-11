///|
test "callable table includes only address-taken functions in ID order" {
  let trivial_slot : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let body = fn(
    instructions : Array[@bytecode.Instruction],
  ) -> @bytecode.FunctionEntry {
    BytecodeBody({
      slots: [trivial_slot],
      inputs: { environment: None, witnesses: [], user_parameters: [] },
      result: Unit,
      blocks: [{ parameters: [], instructions, terminator: Return(None) }],
    })
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [
      body([
        ConstFunction({ value: 0 }, { value: 3 }),
        ConstFunction({ value: 0 }, { value: 2 }),
      ]),
      body([]),
      body([]),
      body([]),
    ],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let plan = plan_callable_table(image)
  debug_inspect(
    (plan.functions, plan.table_indices),
    content=(
      #|([{ value: 2 }, { value: 3 }], [0, 1, 2, 0])
    ),
  )
}
