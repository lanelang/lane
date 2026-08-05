///|
fn scalar_metadata() -> ValueMetadata {
  {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
test "simplify preserves layout values named by erased companions" {
  let body : FunctionBody = {
    values: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        ownership: Trivial,
        erased_companion: None,
      },
      scalar_metadata(),
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        ownership: Owned,
        erased_companion: Some({ value: 0 }),
      },
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0 }, { value: 1 }),
          ConstI64({ value: 1 }, 42L),
          EraseI64({ value: 2 }, { value: 1 }),
          Release({ value: 2 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let simplified = simplify_body(body)
  assert_eq(simplified.values, body.values)
  assert_eq(simplified.blocks, body.blocks)
}

///|
test "simplify VM CFG folds branches and threads empty blocks" {
  let body : FunctionBody = {
    values: [scalar_metadata(), scalar_metadata(), scalar_metadata()],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Value(I64, Trivial, ScalarValue),
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
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 1 }, 40L),
          I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
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
      #|      ConstI64({ value: 1 }, 40),
      #|      I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
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
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0 }, 1L),
          ConstI64({ value: 1 }, 2L),
          I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
          ConstI64({ value: 3 }, 1L),
          I64Add({ value: 4 }, { value: 2 }, { value: 3 }),
          ConstI64({ value: 5 }, 3L),
          I64Add({ value: 6 }, { value: 4 }, { value: 5 }),
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
      #|      ConstI64({ value: 0 }, 1),
      #|      ConstI64({ value: 1 }, 2),
      #|      I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
      #|      I64Add({ value: 1 }, { value: 2 }, { value: 0 }),
      #|      ConstI64({ value: 0 }, 3),
      #|      I64Add({ value: 2 }, { value: 1 }, { value: 0 }),
      #|    ],
      #|    terminator: Return(Some({ value: 2 })),
      #|  },
      #|]
    ),
  )
}
