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
fn bool_metadata() -> ValueMetadata {
  { ..scalar_metadata(), representation: I32, }
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
        erased_companion: Some({ value: 0, }),
      },
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0, }, { value: 1, }),
          ConstI64({ value: 1, }, 42L),
          EraseI64({ value: 2, }, { value: 1, }),
          Release({ value: 2, }),
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
test "unused parameter removal preserves erased companion pairs" {
  let layout : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: LayoutValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let body : FunctionBody = {
    values: [
      layout,
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        ownership: Owned,
        erased_companion: Some({ value: 0, }),
      },
      layout,
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        ownership: Owned,
        erased_companion: Some({ value: 2, }),
      },
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }, { value: 1, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Jump({
          target: { value: 1, },
          arguments: [{ value: 0, }, { value: 1, }],
        }),
      },
      {
        parameters: [{ value: 2, }, { value: 3, }],
        instructions: [Release({ value: 3, })],
        terminator: Return(None),
      },
    ],
  }
  debug_inspect(
    remove_unused_block_parameters(body),
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [],
      #|    terminator: Jump({ target: { value: 1 }, arguments: [{ value: 0 }, { value: 1 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 2 }, { value: 3 }],
      #|    instructions: [Release({ value: 3 })],
      #|    terminator: Return(None),
      #|  },
      #|]
    ),
  )
}

///|
test "simplify VM CFG folds branches and threads empty blocks" {
  let body : FunctionBody = {
    values: [
      bool_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: BranchBool(
          { value: 0, },
          { target: { value: 1, }, arguments: [{ value: 1, }], },
          { target: { value: 2, }, arguments: [{ value: 2, }], },
        ),
      },
      {
        parameters: [{ value: 3, }],
        instructions: [],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 3, }], }),
      },
      {
        parameters: [{ value: 4, }],
        instructions: [],
        terminator: Return(Some({ value: 4, })),
      },
      {
        parameters: [{ value: 5, }],
        instructions: [],
        terminator: Return(Some({ value: 5, })),
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
      #|    parameters: [{ value: 5 }],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 5 })),
      #|  },
      #|]
    ),
  )
}

///|
test "simplify VM CFG removes unused parameters and dead scalar work" {
  let body : FunctionBody = {
    values: [
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
    ],
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
          ConstI64({ value: 1, }, 40L),
          I64Add({ value: 2, }, { value: 0, }, { value: 1, }),
        ],
        terminator: Jump({
          target: { value: 1, },
          arguments: [{ value: 2, }, { value: 0, }],
        }),
      },
      {
        parameters: [{ value: 3, }, { value: 4, }],
        instructions: [],
        terminator: Return(Some({ value: 3, })),
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
      #|    parameters: [{ value: 3 }],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 3 })),
      #|  },
      #|]
    ),
  )
}

///|
test "simplify VM CFG folds a local constant expression chain" {
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
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, 1L),
          ConstI64({ value: 1, }, 2L),
          I64Add({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstI64({ value: 3, }, 1L),
          I64Add({ value: 4, }, { value: 2, }, { value: 3, }),
          ConstI64({ value: 5, }, 3L),
          I64Add({ value: 6, }, { value: 4, }, { value: 5, }),
        ],
        terminator: Return(Some({ value: 6, })),
      },
    ],
  }
  let simplified = simplify_body(body)
  inspect(simplified.values.length(), content="7")
  debug_inspect(
    simplified.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [ConstI64({ value: 6 }, 7)],
      #|    terminator: Return(Some({ value: 6 })),
      #|  },
      #|]
    ),
  )
}

///|
test "sparse constants ignore unreachable predecessors and fold the join" {
  let body : FunctionBody = {
    values: [
      bool_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      bool_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: BranchBool(
          { value: 0, },
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [ConstI64({ value: 1, }, 7L)],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [],
        instructions: [ConstI64({ value: 2, }, 8L)],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 2, }], }),
      },
      {
        parameters: [{ value: 3, }],
        instructions: [
          ConstI64({ value: 4, }, 7L),
          I64Eq({ value: 5, }, { value: 3, }, { value: 4, }),
        ],
        terminator: BranchBool(
          { value: 5, },
          { target: { value: 4, }, arguments: [], },
          { target: { value: 5, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 3, })),
      },
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 4, })),
      },
    ],
  }
  let analysis = analyze_sparse_constants(body)
  assert_true(analysis.states[3] is Constant(I64(7L)))
  debug_inspect(
    simplify_body(body).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [ConstI64({ value: 1 }, 7)],
      #|    terminator: Jump({ target: { value: 1 }, arguments: [{ value: 1 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 3 }],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 3 })),
      #|  },
      #|]
    ),
  )
}

///|
test "sparse constants meet conflicting reachable values at a join" {
  let body : FunctionBody = {
    values: [
      bool_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
    ],
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
        terminator: BranchBool(
          { value: 0, },
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [ConstI64({ value: 1, }, 7L)],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [],
        instructions: [ConstI64({ value: 2, }, 8L)],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 2, }], }),
      },
      {
        parameters: [{ value: 3, }],
        instructions: [],
        terminator: Return(Some({ value: 3, })),
      },
    ],
  }
  assert_true(analyze_sparse_constants(body).states[3] is Overdefined)
}

///|
test "sparse constants fold an out-of-range switch to its default edge" {
  let body : FunctionBody = {
    values: [scalar_metadata()],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstI64({ value: 0, }, -1L)],
        terminator: SwitchTag(
          { value: 0, },
          [{ target: { value: 1, }, arguments: [], }],
          { target: { value: 2, }, arguments: [], },
        ),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
      { parameters: [], instructions: [], terminator: Return(None), },
    ],
  }
  assert_eq(
    propagate_sparse_constants(body).blocks[0].terminator,
    Jump({ target: { value: 2, }, arguments: [], }),
  )
}

///|
test "sparse constants converge through a loop with an invariant argument" {
  let body : FunctionBody = {
    values: [bool_metadata(), scalar_metadata(), scalar_metadata()],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstI64({ value: 1, }, 42L)],
        terminator: Jump({ target: { value: 1, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [{ value: 2, }],
        instructions: [],
        terminator: BranchBool(
          { value: 0, },
          { target: { value: 1, }, arguments: [{ value: 2, }], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  assert_true(analyze_sparse_constants(body).states[2] is Constant(I64(42L)))
}

///|
test "constant folding preserves trapping integer divisions" {
  let body : FunctionBody = {
    values: [
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, -9223372036854775808L),
          ConstI64({ value: 1, }, -1L),
          I64Div({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstI64({ value: 3, }, 1L),
          ConstI64({ value: 4, }, 0L),
          I64Div({ value: 5, }, { value: 3, }, { value: 4, }),
          ConstI64({ value: 6, }, 10L),
          ConstI64({ value: 7, }, 2L),
          I64Div({ value: 8, }, { value: 6, }, { value: 7, }),
        ],
        terminator: Return(Some({ value: 8, })),
      },
    ],
  }
  let simplified = simplify_body(body)
  assert_true(
    simplified.blocks[0].instructions.any(instruction => {
      instruction is I64Div({ value: 2, }, _, _)
    }),
  )
  assert_true(
    simplified.blocks[0].instructions.any(instruction => {
      instruction is I64Div({ value: 5, }, _, _)
    }),
  )
  assert_true(
    simplified.blocks[0].instructions.any(instruction => {
      instruction is ConstI64({ value: 8, }, 5L)
    }),
  )
}

///|
test "scalar CSE follows dominance and does not cross sibling branches" {
  let body : FunctionBody = {
    values: [
      scalar_metadata(),
      scalar_metadata(),
      bool_metadata(),
      scalar_metadata(),
      scalar_metadata(),
      scalar_metadata(),
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }, { value: 1, }, { value: 2, }],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [I64Add({ value: 3, }, { value: 0, }, { value: 1, })],
        terminator: BranchBool(
          { value: 2, },
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [I64Add({ value: 4, }, { value: 0, }, { value: 1, })],
        terminator: Return(Some({ value: 4, })),
      },
      {
        parameters: [],
        instructions: [I64Add({ value: 5, }, { value: 0, }, { value: 1, })],
        terminator: Return(Some({ value: 5, })),
      },
    ],
  }
  debug_inspect(
    eliminate_common_scalar_expressions(body).blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [I64Add({ value: 3 }, { value: 0 }, { value: 1 })],
      #|    terminator: BranchBool(
      #|      { value: 2 },
      #|      { target: { value: 1 }, arguments: [] },
      #|      { target: { value: 2 }, arguments: [] },
      #|    ),
      #|  },
      #|  {
      #|    parameters: [],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 3 })),
      #|  },
      #|  {
      #|    parameters: [],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 3 })),
      #|  },
      #|]
    ),
  )
  let siblings = {
    ..body,
    blocks: [
      { ..body.blocks[0], instructions: [], },
      body.blocks[1],
      body.blocks[2],
    ],
  }
  assert_eq(
    eliminate_common_scalar_expressions(siblings).blocks.map(block => {
      block.instructions.length()
    }),
    [0, 1, 1],
  )
}

///|
test "simplify preserves block parameters used in dominated successors" {
  let body : FunctionBody = {
    values: [scalar_metadata(), scalar_metadata()],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstI64({ value: 1, }, 42L)],
        terminator: Jump({ target: { value: 1, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [{ value: 0, }],
        instructions: [],
        terminator: Jump({ target: { value: 2, }, arguments: [], }),
      },
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let simplified = simplify_body(body)
  let use_def = analyze_use_def(simplified)
  assert_true(use_def.definitions[0] is Some(_))
  debug_inspect(
    simplified.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [ConstI64({ value: 1 }, 42)],
      #|    terminator: Jump({ target: { value: 1 }, arguments: [{ value: 1 }] }),
      #|  },
      #|  {
      #|    parameters: [{ value: 0 }],
      #|    instructions: [],
      #|    terminator: Return(Some({ value: 0 })),
      #|  },
      #|]
    ),
  )
}
