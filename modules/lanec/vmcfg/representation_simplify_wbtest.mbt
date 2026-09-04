///|
test "actual erase-unerase pairs preserve each numeric runtime value" {
  let representations : Array[@physical.Representation] = [I32, I64, F32, F64]
  for representation in representations {
    let witness : ValueMetadata = {
      representation: I32,
      cleanup: Trivial,
      kind: LayoutValue,
      ownership: Trivial,
      erased_companion: None,
    }
    let value = trivial_value(representation)
    let erased : ValueMetadata = {
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
      ownership: Owned,
      erased_companion: Some({ value: 0, }),
    }
    let instructions = match representation {
      I32 =>
        [
          EraseI32({ value: 2, }, { value: 1, }),
          UneraseI32({ value: 3, }, { value: 2, }),
        ]
      I64 =>
        [
          EraseI64({ value: 2, }, { value: 1, }),
          UneraseI64({ value: 3, }, { value: 2, }),
        ]
      F32 =>
        [
          EraseF32({ value: 2, }, { value: 1, }),
          UneraseF32({ value: 3, }, { value: 2, }),
        ]
      F64 =>
        [
          EraseF64({ value: 2, }, { value: 1, }),
          UneraseF64({ value: 3, }, { value: 2, }),
        ]
    }
    let body : FunctionBody = {
      values: [witness, value, erased, value],
      inputs: {
        environment: None,
        witnesses: [{ value: 0, }],
        user_parameters: [{ value: 1, }],
      },
      result: Value(representation, Trivial, ScalarValue),
      blocks: [
        {
          parameters: [],
          instructions,
          terminator: Return(Some({ value: 3, })),
        },
      ],
    }
    assert_eq(simplify_body(body).blocks, [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 1, })),
      },
    ])
  }
}

///|
test "a closure projection cannot substitute a different target's environment" {
  let environment : ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: EnvironmentValue({ value: 0, }),
    ownership: Owned,
    erased_companion: None,
  }
  let callable : ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let body : FunctionBody = {
    values: [environment, callable, { ..environment, ownership: Borrowed, }],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Value(I32, OwnedRef, EnvironmentValue({ value: 0, })),
    blocks: [
      {
        parameters: [],
        instructions: [
          MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
          MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
          BorrowClosureEnvironment({ value: 2, }, { value: 3, }, { value: 1, }),
        ],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  assert_eq(simplify_body(body), body)
}

///|
test "representation folding does not turn a forward definition into a cyclic alias" {
  let witness : ValueMetadata = {
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
  let body : FunctionBody = {
    values: [witness, erased, trivial_value(I64)],
    inputs: {
      environment: None,
      witnesses: [{ value: 0, }],
      user_parameters: [],
    },
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          EraseI64({ value: 1, }, { value: 2, }),
          UneraseI64({ value: 2, }, { value: 1, }),
        ],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  assert_eq(simplify_representation_values(body), body)
}

///|
test "adapter composition retains a self-recursive implementation" {
  let body : FunctionBody = {
    values: [trivial_value(I64), trivial_value(I64)],
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
            { value: 1, },
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
  let image = test_image(body)
  assert_eq(compose_callable_adapters(image, [{ value: 1, }]), image)
}

///|
test "mutually recursive adapters compose original calls without recursive unfolding" {
  let first : FunctionBody = {
    values: [trivial_value(I64), trivial_value(I64)],
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
  let second : FunctionBody = {
    ..first,
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect(
            { value: 1, },
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
  let image = { ..test_image(first), functions: [Body(first), Body(second)], }
  let composed = compose_callable_adapters(image, [{ value: 1, }, { value: 2, }])
  assert_eq(composed.functions, [Body(second), Body(first)])
}

///|
test "actual adapter body composition removes a numeric ABI round trip" {
  let witness : ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: LayoutValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let scalar = trivial_value(I64)
  let erased : ValueMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    ownership: Owned,
    erased_companion: Some({ value: 0, }),
  }
  let inputs : FunctionInputs = {
    environment: None,
    witnesses: [{ value: 0, }],
    user_parameters: [{ value: 1, }],
  }
  let entry : FunctionBody = {
    inputs,
    values: [witness, scalar, scalar],
    result: Value(I64, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect(
            { value: 2, },
            None,
            [{ value: 0, }],
            [{ value: 1, }],
            Some({ value: 2, }),
          ),
        ],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  let boxing : FunctionBody = {
    ..entry,
    values: [witness, scalar, erased, scalar],
    blocks: [
      {
        parameters: [],
        instructions: [
          EraseI64({ value: 2, }, { value: 1, }),
          CallDirect(
            { value: 3, },
            None,
            [{ value: 0, }],
            [{ value: 2, }],
            Some({ value: 3, }),
          ),
        ],
        terminator: Return(Some({ value: 3, })),
      },
    ],
  }
  let unboxing : FunctionBody = {
    ..entry,
    values: [witness, erased, scalar],
    blocks: [
      {
        parameters: [],
        instructions: [UneraseI64({ value: 2, }, { value: 1, })],
        terminator: Return(Some({ value: 2, })),
      },
    ],
  }
  let image = {
    ..test_image(entry),
    functions: [Body(entry), Body(boxing), Body(unboxing)],
  }
  let expanded = compose_callable_adapters(image, [{ value: 2, }, { value: 3, }])
  assert_eq(expanded.functions[0], Body(entry))
  guard expanded.functions[1] is Body(body) else {
    fail("missing composed adapter")
  }
  assert_eq(simplify_body(body).blocks, [
    {
      parameters: [],
      instructions: [],
      terminator: Return(Some({ value: 1, })),
    },
  ])
}
