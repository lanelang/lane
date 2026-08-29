///|
test "single-use direct inlining moves a body without cloning it" {
  let scalar = scalar_metadata()
  let caller : FunctionBody = {
    values: [scalar, scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 0, }],
            Some({ value: 1, }),
          ),
        ],
        terminator: Return(Some({ value: 1, })),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let inlined = inline_single_use_direct_functions(
    {
      entry: { value: 1, },
      initializer: None,
      data_family_count: 0,
      functions: [Body(caller), Body(callee)],
      globals: [],
      layouts: [],
      object_shapes: [],
      constants: [],
    },
    [{ value: 2, }],
  )
  guard inlined.functions[0] is Body(body) else {
    fail("expected an inlined caller body")
  }
  debug_inspect(
    body.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [Move({ value: 1 }, { value: 0 })],
      #|    terminator: Return(Some({ value: 1 })),
      #|  },
      #|]
    ),
  )
}

///|
test "direct inlining does not clone a multiply used function" {
  let scalar = scalar_metadata()
  let caller : FunctionBody = {
    values: [scalar, scalar, scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 0, }],
            Some({ value: 1, }),
          ),
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 1, }],
            Some({ value: 2, }),
          ),
        ],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  let callee : FunctionBody = {
    values: [scalar],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let image : Image = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    functions: [Body(caller), Body(callee)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  assert_eq(inline_single_use_direct_functions(image, [{ value: 2, }]), image)
}
