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

///|
test "trivial functions omit frame liveness locals" {
  let trivial_slot : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let body : @bytecode.FunctionBody = {
    slots: [trivial_slot, trivial_slot, trivial_slot],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0 }, 40L),
          ConstI64({ value: 1 }, 2L),
          I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    functions: [BytecodeBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let wasm_module = match compile(image) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  debug_inspect(wasm_module.codes[0].locals, content="[I64, I64, I64]")
}
