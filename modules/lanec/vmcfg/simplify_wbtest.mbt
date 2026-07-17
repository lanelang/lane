///|
fn scalar_metadata() -> ValueMetadata {
  {
    representation: I64,
    cleanup: Trivial,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
test "simplify VM CFG folds branches and threads empty blocks" {
  let body : FunctionBody = {
    values: [scalar_metadata(), scalar_metadata(), scalar_metadata()],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, true)],
        terminator: BranchBool(
          { value: 0 },
          { target: { value: 1 }, arguments: [{ value: 1 }] },
          { target: { value: 2 }, arguments: [{ value: 2 }] },
        ),
      },
      {
        parameters: [{ value: 2 }],
        instructions: [],
        terminator: Jump({ target: { value: 3 }, arguments: [{ value: 2 }] }),
      },
      {
        parameters: [{ value: 2 }],
        instructions: [],
        terminator: Return(Some({ value: 2 })),
      },
      {
        parameters: [{ value: 2 }],
        instructions: [],
        terminator: Return(Some({ value: 2 })),
      },
    ],
  }
  debug_inspect(
    simplify_body(body).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [],
      #|    terminator: Jump({ target: { value: 1 }, arguments: [{ value: 1 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 2 }],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 2 })),
      #|  },
      #|]
    ),
  )
}

///|
test "simplify VM CFG removes unused parameters and dead scalar work" {
  let body : FunctionBody = {
    values: [scalar_metadata(), scalar_metadata(), scalar_metadata()],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstInt({ value: 1 }, 40L),
          IntAdd({ value: 2 }, { value: 0 }, { value: 1 }),
        ],
        terminator: Jump({
          target: { value: 1 },
          arguments: [{ value: 2 }, { value: 0 }],
        }),
      },
      {
        parameters: [{ value: 2 }, { value: 1 }],
        instructions: [],
        terminator: Return(Some({ value: 2 })),
      },
    ],
  }
  debug_inspect(
    simplify_body(body).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [
      #|      ConstInt({ value: 1 }, 40),
      #|      IntAdd({ value: 2 }, { value: 0 }, { value: 1 }),
      #|    ],
      #|    terminator: Jump({ target: { value: 1 }, arguments: [{ value: 2 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 2 }],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 2 })),
      #|  },
      #|]
    ),
  )
}

///|
test "simplify VM CFG reuses local constants and scalar slots" {
  let body : FunctionBody = {
    values: [
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstInt({ value: 0 }, 1L),
          ConstInt({ value: 1 }, 2L),
          IntAdd({ value: 2 }, { value: 0 }, { value: 1 }),
          ConstInt({ value: 3 }, 1L),
          IntAdd({ value: 4 }, { value: 2 }, { value: 3 }),
          ConstInt({ value: 5 }, 3L),
          IntAdd({ value: 6 }, { value: 4 }, { value: 5 }),
        ],
        terminator: Return(Some({ value: 6 })),
      },
    ],
  }
  let simplified = simplify_body(body)
  inspect(simplified.values.length(), content="3")
  debug_inspect(
    simplified.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [
      #|      ConstInt({ value: 0 }, 1),
      #|      ConstInt({ value: 1 }, 2),
      #|      IntAdd({ value: 2 }, { value: 0 }, { value: 1 }),
      #|      IntAdd({ value: 1 }, { value: 2 }, { value: 0 }),
      #|      ConstInt({ value: 0 }, 3),
      #|      IntAdd({ value: 2 }, { value: 1 }, { value: 0 }),
      #|    ],
      #|    terminator: Return(Some({ value: 2 })),
      #|  },
      #|]
    ),
  )
}
