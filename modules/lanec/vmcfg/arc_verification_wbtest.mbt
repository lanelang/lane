///|
fn arc_test_value(
  ownership : Ownership,
  cleanup : @physical.Cleanup,
) -> ValueMetadata {
  {
    representation: I32,
    cleanup,
    kind: ByteSequenceValue,
    ownership,
    erased_companion: None,
  }
}

///|
test "ARC-final boundary rejects duplicate trivial definitions" {
  let scalar : ValueMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  try
    verify_arc_final_body({
      values: [scalar],
      inputs: { environment: None, witnesses: [], user_parameters: [], },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [
            ConstI64({ value: 0, }, 1L),
            ConstI64({ value: 0, }, 2L),
          ],
          terminator: Return(None),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|UseDefAnalysisCompilerDefect(
          #|  DuplicateDefinition(
          #|    { value: 0 },
          #|    InstructionResult(0, 0),
          #|    InstructionResult(0, 1),
          #|  ),
          #|)
        ),
      )
  } noraise {
    _ =>
      fail("expected the ARC-final boundary to reject a duplicate definition")
  }
}

///|
test "ARC-final boundary ignores metadata for undefined unused values" {
  let layout : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: LayoutValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let erased : ValueMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    ownership: Owned,
    erased_companion: Some({ value: 0, }),
  }
  let arc_final = verify_arc_final_body({
    values: [layout, erased],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  })
  assert_eq(arc_final.body.blocks, [
    { parameters: [], instructions: [], terminator: Return(None), },
  ])
}

///|
test "ARC-final boundary rejects a borrowed input redefinition" {
  let borrowed = arc_test_value(Borrowed, OwnedRef)
  let owned = arc_test_value(Owned, OwnedRef)
  try
    verify_arc_final_body({
      values: [borrowed, owned],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0, }, { value: 1, }],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [
            BorrowField({ value: 0, }, { value: 1, }, 0, {
              value_destination: { value: 0, },
              witness_destination: None,
            }),
            Release({ value: 1, }),
          ],
          terminator: Return(None),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|UseDefAnalysisCompilerDefect(
          #|  DuplicateDefinition(
          #|    { value: 0 },
          #|    FunctionInput(0),
          #|    InstructionResult(0, 0),
          #|  ),
          #|)
        ),
      )
  } noraise {
    _ =>
      fail("expected the ARC-final boundary to reject a borrowed redefinition")
  }
}

///|
test "ARC-final boundary rejects duplicate block-parameter definitions" {
  let scalar : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  try
    verify_arc_final_body({
      values: [scalar, scalar],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0, }],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [],
          terminator: BranchBool(
            { value: 0, },
            { target: { value: 1, }, arguments: [{ value: 0, }], },
            { target: { value: 2, }, arguments: [{ value: 0, }], },
          ),
        },
        {
          parameters: [{ value: 1, }],
          instructions: [],
          terminator: Return(None),
        },
        {
          parameters: [{ value: 1, }],
          instructions: [],
          terminator: Return(None),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|UseDefAnalysisCompilerDefect(
          #|  DuplicateDefinition(
          #|    { value: 1 },
          #|    BlockParameter(1, 0),
          #|    BlockParameter(2, 0),
          #|  ),
          #|)
        ),
      )
  } noraise {
    _ => fail("expected duplicate block parameters to be rejected")
  }
}

///|
test "ARC-final boundary rejects an owner that reaches return" {
  let owned = arc_test_value(Owned, OwnedRef)
  try
    verify_arc_final_body({
      values: [owned],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0, }],
      },
      result: Unit,
      blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ArcFinalVerificationCompilerDefect(OwnedValueEscapes({ value: 0 }, { value: 0 }))
        ),
      )
  } noraise {
    _ => fail("expected the ARC-final boundary to reject a leaked owner")
  }
}

///|
test "ARC-final boundary rejects a borrow after its local owner is released" {
  let owned = arc_test_value(Owned, OwnedRef)
  let borrowed = arc_test_value(Borrowed, OwnedRef)
  try
    verify_arc_final_body({
      values: [owned, borrowed, owned],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0, }],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [
            BorrowField({ value: 0, }, { value: 0, }, 0, {
              value_destination: { value: 1, },
              witness_destination: None,
            }),
            Release({ value: 0, }),
            RetainCopy({ value: 2, }, { value: 1, }),
            Release({ value: 2, }),
          ],
          terminator: Return(None),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ArcFinalVerificationCompilerDefect(BorrowOwnerNotLive({ value: 1 }, { value: 0 }, { value: 0 }))
        ),
      )
  } noraise {
    _ => fail("expected the ARC-final boundary to reject an invalid borrow")
  }
}

///|
test "ARC-final boundary follows an owner transferred into an environment" {
  let owned = arc_test_value(Owned, OwnedRef)
  let borrowed = arc_test_value(Borrowed, OwnedRef)
  let environment : ValueMetadata = {
    ..owned,
    kind: EnvironmentValue({ value: 0, }),
  }
  let arc_final = verify_arc_final_body({
    values: [owned, borrowed, environment, owned],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowField({ value: 0, }, { value: 0, }, 0, {
            value_destination: { value: 1, },
            witness_destination: None,
          }),
          MakeEnv({ value: 2, }, { value: 0, }, Immediate({ value: 1, }), [], [
            { value: 0, },
          ]),
          RetainCopy({ value: 3, }, { value: 1, }),
          Release({ value: 3, }),
          Release({ value: 2, }),
        ],
        terminator: Return(None),
      },
    ],
  })
  ignore(allocate_physical_slots(arc_final))
}

///|
test "ARC-final boundary does not let an unrelated projection cover a borrow" {
  let owned = arc_test_value(Owned, OwnedRef)
  let borrowed = arc_test_value(Borrowed, OwnedRef)
  try
    verify_arc_final_body({
      values: [owned, borrowed, owned, owned],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0, }],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [
            BorrowField({ value: 0, }, { value: 0, }, 0, {
              value_destination: { value: 1, },
              witness_destination: None,
            }),
            ConsumeFields({ value: 0, }, { value: 0, }, [
              {
                member_index: 1,
                result: {
                  value_destination: { value: 2, },
                  witness_destination: None,
                },
              },
            ]),
            RetainCopy({ value: 3, }, { value: 1, }),
          ],
          terminator: Return(Some({ value: 2, })),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ArcFinalVerificationCompilerDefect(BorrowOwnerNotLive({ value: 1 }, { value: 0 }, { value: 0 }))
        ),
      )
  } noraise {
    _ => fail("expected an unrelated projection owner not to cover the borrow")
  }
}

///|
test "ARC-final boundary rejects a borrowed value in a consuming operand" {
  let borrowed = arc_test_value(Borrowed, OwnedRef)
  try
    verify_arc_final_body({
      values: [borrowed],
      inputs: {
        environment: None,
        witnesses: [],
        user_parameters: [{ value: 0, }],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [
            CallDirect({ value: 1, }, None, [], [{ value: 0, }], None),
          ],
          terminator: Return(None),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ArcFinalVerificationCompilerDefect(BorrowedValueConsumed({ value: 0 }, { value: 0 }))
        ),
      )
  } noraise {
    _ => fail("expected the ARC-final boundary to reject borrowed consumption")
  }
}

///|
test "ARC-final boundary validates CFG edge shape before slot planning" {
  let scalar : ValueMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  try
    verify_arc_final_body({
      values: [scalar],
      inputs: { environment: None, witnesses: [], user_parameters: [], },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [ConstI64({ value: 0, }, 0L)],
          terminator: Jump({ target: { value: 1, }, arguments: [], }),
        },
        {
          parameters: [{ value: 0, }],
          instructions: [],
          terminator: Return(None),
        },
      ],
    })
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ArcFinalVerificationCompilerDefect(EdgeArityMismatch({ value: 0 }, { value: 1 }, 1, 0))
        ),
      )
  } noraise {
    _ => fail("expected the ARC-final boundary to reject an invalid edge")
  }
}
