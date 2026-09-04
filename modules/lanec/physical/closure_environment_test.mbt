///|
test "closure environment projection preserves the callable borrow root" {
  let environment = verification_slot(
    I32,
    cleanup=OwnedRef,
    kind=Some(EnvironmentValue({ value: 0, })),
  )
  let callable = verification_slot(I64, cleanup=OwnedCallable)
  let target = {
    ..verification_body(slots=[environment], instructions=[
      Release({ value: 0, }),
    ]),
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
  }
  let prefix : Array[Instruction] = [
    MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
    MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
    BorrowClosureEnvironment({ value: 2, }, { value: 2, }, { value: 1, }),
  ]
  let make_image = fn(instructions : Array[Instruction]) {
    {
      ..verification_image(
        verification_body(
          slots=[
            environment,
            callable,
            { ..environment, cleanup: Trivial, },
            environment,
          ],
          instructions~,
        ),
        functions=[PhysicalBody(target)],
      ),
      object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
      layouts: [Environment({ value: 0, })],
    }
  }
  assert_eq(
    verify_physical_program(
      make_image(
        prefix +
        [
          RetainCopy({ value: 3, }, { value: 2, }),
          Release({ value: 1, }),
          Release({ value: 3, }),
        ],
      ),
    ),
    Ok(()),
  )
  debug_inspect(
    verify_physical_program(
      make_image(
        prefix +
        [
          Release({ value: 1, }),
          RetainCopy({ value: 3, }, { value: 2, }),
          Release({ value: 3, }),
        ],
      ),
    ),
    content=(
      #|Err(
      #|  InvalidPhysicalProgram(
      #|    site=Instruction({ value: 1 }, { value: 0 }, 4),
      #|    detail="borrowed SlotId 2 from its root value outlives its local owner",
      #|  ),
      #|)
    ),
  )
  let wrong_shape = {
    ..environment,
    cleanup: Trivial,
    kind: EnvironmentValue({ value: 1, }),
  }
  let invalid = make_image(prefix)
  let wrong_destination = {
    ..invalid,
    functions: [
      PhysicalBody(
        verification_body(
          slots=[environment, callable, wrong_shape, environment],
          instructions=prefix,
        ),
      ),
      PhysicalBody(target),
    ],
    object_shapes: invalid.object_shapes +
    [Environment({ stored_witness_count: 0, members: [], })],
    layouts: invalid.layouts + [Environment({ value: 1, })],
  }
  debug_inspect(
    verify_physical_program(wrong_destination),
    content=(
      #|Err(
      #|  InvalidPhysicalProgram(
      #|    site=Instruction({ value: 1 }, { value: 0 }, 2),
      #|    detail="SlotId 2 must have EnvironmentValue({ value: 0 }) semantic kind, got EnvironmentValue({ value: 1 })",
      #|  ),
      #|)
    ),
  )
}

///|
test "closure environment projection rejects a target without an environment" {
  debug_inspect(
    verify_physical_program(
      verification_image(
        verification_body(
          slots=[
            verification_slot(I64, cleanup=OwnedCallable),
            verification_slot(I32, cleanup=OwnedRef),
          ],
          instructions=[
            ConstFunction({ value: 0, }, { value: 2, }),
            BorrowClosureEnvironment({ value: 1, }, { value: 2, }, { value: 0, }),
          ],
        ),
        functions=[PhysicalBody(verification_body())],
      ),
    ),
    content=(
      #|Err(
      #|  InvalidPhysicalProgram(
      #|    site=Instruction({ value: 1 }, { value: 0 }, 1),
      #|    detail="closure environment projection requires a target with an environment",
      #|  ),
      #|)
    ),
  )
}
