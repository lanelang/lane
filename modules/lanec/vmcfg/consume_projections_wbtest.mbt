///|
fn owned_string_value() -> ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn borrowed_string_value() -> ValueMetadata {
  { ..owned_string_value(), ownership: Borrowed }
}

///|
test "select consuming field projection for returned owned member" {
  let body : FunctionBody = {
    values: [owned_string_value(), borrowed_string_value()],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
    result: I32,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowField({ value: 0 }, { value: 0 }, 1, {
            value_destination: { value: 1 },
            witness_destination: None,
          }),
        ],
        terminator: Return(Some({ value: 1 })),
      },
    ],
  }
  let selected = select_consuming_projections_in_body(body)
  debug_inspect(
    (selected.values, selected.blocks),
    content=(
      #|(
      #|  [
      #|    {
      #|      representation: I32,
      #|      cleanup: OwnedRef,
      #|      ownership: Owned,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: I32,
      #|      cleanup: OwnedRef,
      #|      ownership: Owned,
      #|      erased_companion: None,
      #|    },
      #|  ],
      #|  [
      #|    {
      #|      parameters: [],
      #|      instructions: [
      #|        ConsumeFields(
      #|          { value: 0 },
      #|          { value: 0 },
      #|          [
      #|            {
      #|              member_index: 1,
      #|              result: { value_destination: { value: 1 }, witness_destination: None },
      #|            },
      #|          ],
      #|        ),
      #|      ],
      #|      terminator: Return(Some({ value: 1 })),
      #|    },
      #|  ],
      #|)
    ),
  )
  let image = match finalize(test_image(body)) {
    Ok(image) => image
    Err(error) => fail("finalize failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(lowered) else {
    fail("expected bytecode body")
  }
  debug_inspect(
    lowered.blocks[0].instructions,
    content=(
      #|[
      #|  ConsumeFields(
      #|    { value: 0 },
      #|    { value: 0 },
      #|    [
      #|      {
      #|        member_index: 1,
      #|        result: { value_destination: { value: 1 }, witness_destination: None },
      #|      },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "group consuming captures and preserve block-local borrows" {
  let body : FunctionBody = {
    values: [
      owned_string_value(),
      borrowed_string_value(),
      borrowed_string_value(),
      scalar_metadata(),
    ],
    inputs: {
      environment: Some({ value: 0 }),
      witnesses: [],
      user_parameters: [],
    },
    result: I32,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowCapture({ value: 0 }, { value: 0 }, 0, {
            value_destination: { value: 1 },
            witness_destination: None,
          }),
          BorrowCapture({ value: 0 }, { value: 0 }, 1, {
            value_destination: { value: 2 },
            witness_destination: None,
          }),
          StringLength({ value: 3 }, { value: 1 }),
        ],
        terminator: Return(Some({ value: 2 })),
      },
    ],
  }
  let selected = select_consuming_projections_in_body(body)
  assert_true(
    selected.blocks[0].instructions[0] is ConsumeCaptures(_, _, [_, _]),
  )
  assert_true(selected.values[1].ownership is Owned)
  assert_true(selected.values[2].ownership is Owned)
  let borrowed_only = {
    ..body,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowCapture({ value: 0 }, { value: 0 }, 0, {
            value_destination: { value: 1 },
            witness_destination: None,
          }),
          StringLength({ value: 3 }, { value: 1 }),
        ],
        terminator: Return(Some({ value: 3 })),
      },
    ],
  }
  assert_eq(select_consuming_projections_in_body(borrowed_only), borrowed_only)
}
