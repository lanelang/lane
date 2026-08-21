///|
fn function_table_test_body(instructions : Array[Instruction]) -> FunctionEntry {
  Body({
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  })
}

///|
fn function_table_test_image(functions : Array[FunctionEntry]) -> Image {
  {
    entry: { value: 1 },
    initializer: None,
    functions,
    data_family_count: 0,
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "pre-ARC function closure consumes locally cleaned VM CFG" {
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let entry : FunctionEntry = Body({
    values: [callable],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstFunction({ value: 0 }, { value: 2 })],
        terminator: Return(None),
      },
    ],
  })
  guard finalize_observed(
      function_table_test_image([entry, function_table_test_body([])]),
    )
    is Ok(finalized) else {
    fail("expected a finalized VM CFG image")
  }
  debug_inspect(
    (finalized.pre_arc_image(), finalized.source_functions()),
    content=(
      #|(
      #|  {
      #|    entry: { value: 1 },
      #|    initializer: None,
      #|    functions: [
      #|      Body(
      #|        {
      #|          values: [
      #|            {
      #|              representation: I64,
      #|              cleanup: OwnedCallable,
      #|              kind: CallableValue,
      #|              ownership: Owned,
      #|              erased_companion: None,
      #|            },
      #|          ],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
      #|        },
      #|      ),
      #|    ],
      #|    data_family_count: 0,
      #|    globals: [],
      #|    layouts: [],
      #|    object_shapes: [],
      #|    constants: [],
      #|  },
      #|  [[{ value: 1 }]],
      #|)
    ),
  )
}

///|
test "pre-ARC function table merges exact bodies and their source identities" {
  let entry = function_table_test_body([
    CallDirect({ value: 2 }, None, [], [], None),
    CallDirect({ value: 3 }, None, [], [], None),
  ])
  let duplicate = function_table_test_body([])
  guard finalize_observed(
      function_table_test_image([entry, duplicate, duplicate]),
    )
    is Ok(finalized) else {
    fail("expected a finalized VM CFG image")
  }
  debug_inspect(
    (finalized.pre_arc_image(), finalized.source_functions()),
    content=(
      #|(
      #|  {
      #|    entry: { value: 1 },
      #|    initializer: None,
      #|    functions: [
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [
      #|                CallDirect({ value: 2 }, None, [], [], None),
      #|                CallDirect({ value: 2 }, None, [], [], None),
      #|              ],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
      #|        },
      #|      ),
      #|    ],
      #|    data_family_count: 0,
      #|    globals: [],
      #|    layouts: [],
      #|    object_shapes: [],
      #|    constants: [],
      #|  },
      #|  [[{ value: 1 }], [{ value: 2 }, { value: 3 }]],
      #|)
    ),
  )
}

///|
test "pre-ARC function equivalence follows canonical callee classes" {
  let entry = function_table_test_body([
    CallDirect({ value: 2 }, None, [], [], None),
    CallDirect({ value: 4 }, None, [], [], None),
  ])
  let left = function_table_test_body([
    CallDirect({ value: 3 }, None, [], [], None),
  ])
  let leaf = function_table_test_body([])
  let right = function_table_test_body([
    CallDirect({ value: 5 }, None, [], [], None),
  ])
  guard finalize_observed(
      function_table_test_image([entry, left, leaf, right, leaf]),
    )
    is Ok(finalized) else {
    fail("expected a finalized VM CFG image")
  }
  debug_inspect(
    (finalized.pre_arc_image(), finalized.source_functions()),
    content=(
      #|(
      #|  {
      #|    entry: { value: 1 },
      #|    initializer: None,
      #|    functions: [
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [
      #|                CallDirect({ value: 2 }, None, [], [], None),
      #|                CallDirect({ value: 2 }, None, [], [], None),
      #|              ],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [CallDirect({ value: 3 }, None, [], [], None)],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|      Body(
      #|        {
      #|          values: [],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
      #|        },
      #|      ),
      #|    ],
      #|    data_family_count: 0,
      #|    globals: [],
      #|    layouts: [],
      #|    object_shapes: [],
      #|    constants: [],
      #|  },
      #|  [
      #|    [{ value: 1 }],
      #|    [{ value: 2 }, { value: 4 }],
      #|    [{ value: 3 }, { value: 5 }],
      #|  ],
      #|)
    ),
  )
}

///|
test "pre-ARC function equivalence preserves semantic data-family ABI" {
  let family_two : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 2 }),
    ownership: Owned,
    erased_companion: None,
  }
  let family_three : ValueMetadata = {
    ..family_two,
    kind: DataValue({ value: 3 }),
  }
  let entry : FunctionEntry = Body({
    values: [family_two, family_three],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
          MakeData({ value: 1 }, { value: 1 }, Immediate({ value: 2 }), [], []),
          CallDirect({ value: 2 }, None, [], [{ value: 0 }], None),
          CallDirect({ value: 3 }, None, [], [{ value: 1 }], None),
        ],
        terminator: Return(None),
      },
    ],
  })
  let family_function = fn(metadata : ValueMetadata) -> FunctionEntry {
    Body({
      values: [metadata],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0 }],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [Release({ value: 0 })],
          terminator: Return(None),
        },
      ],
    })
  }
  let image = {
    ..function_table_test_image([
      entry,
      family_function(family_two),
      family_function(family_three),
    ]),
    data_family_count: 4,
    layouts: [Data({ value: 0 }), Data({ value: 1 })],
    object_shapes: [
      Data({
        family: { value: 2 },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
      Data({
        family: { value: 3 },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
    ],
  }
  let finalized = match finalize_observed(image) {
    Ok(finalized) => finalized
    Err(error) => fail("expected a finalized VM CFG image: \{Repr(error)}")
  }
  debug_inspect(
    (finalized.pre_arc_image(), finalized.source_functions()),
    content=(
      #|(
      #|  {
      #|    entry: { value: 1 },
      #|    initializer: None,
      #|    functions: [
      #|      Body(
      #|        {
      #|          values: [
      #|            {
      #|              representation: I32,
      #|              cleanup: OwnedRef,
      #|              kind: DataValue({ value: 2 }),
      #|              ownership: Owned,
      #|              erased_companion: None,
      #|            },
      #|            {
      #|              representation: I32,
      #|              cleanup: OwnedRef,
      #|              kind: DataValue({ value: 3 }),
      #|              ownership: Owned,
      #|              erased_companion: None,
      #|            },
      #|          ],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [
      #|                MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
      #|                MakeData({ value: 1 }, { value: 1 }, Immediate({ value: 2 }), [], []),
      #|                CallDirect({ value: 2 }, None, [], [{ value: 0 }], None),
      #|                CallDirect({ value: 3 }, None, [], [{ value: 1 }], None),
      #|              ],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|      Body(
      #|        {
      #|          values: [
      #|            {
      #|              representation: I32,
      #|              cleanup: OwnedRef,
      #|              kind: DataValue({ value: 2 }),
      #|              ownership: Owned,
      #|              erased_companion: None,
      #|            },
      #|          ],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [{ value: 0 }] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [Release({ value: 0 })],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|      Body(
      #|        {
      #|          values: [
      #|            {
      #|              representation: I32,
      #|              cleanup: OwnedRef,
      #|              kind: DataValue({ value: 3 }),
      #|              ownership: Owned,
      #|              erased_companion: None,
      #|            },
      #|          ],
      #|          inputs: { environment: None, witnesses: [], user_parameters: [{ value: 0 }] },
      #|          result: Unit,
      #|          blocks: [
      #|            {
      #|              parameters: [],
      #|              instructions: [Release({ value: 0 })],
      #|              terminator: Return(None),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ],
      #|    data_family_count: 4,
      #|    globals: [],
      #|    layouts: [Data({ value: 0 }), Data({ value: 1 })],
      #|    object_shapes: [
      #|      Data(
      #|        {
      #|          family: { value: 2 },
      #|          constructor_tag: 0,
      #|          stored_witness_count: 0,
      #|          members: [],
      #|        },
      #|      ),
      #|      Data(
      #|        {
      #|          family: { value: 3 },
      #|          constructor_tag: 0,
      #|          stored_witness_count: 0,
      #|          members: [],
      #|        },
      #|      ),
      #|    ],
      #|    constants: [],
      #|  },
      #|  [[{ value: 1 }], [{ value: 2 }], [{ value: 3 }]],
      #|)
    ),
  )
}
