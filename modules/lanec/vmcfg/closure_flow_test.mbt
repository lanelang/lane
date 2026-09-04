///|
test "capture relationships survive callable parameters and packed calls" {
  let callable : @vmcfg.ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let environment : @vmcfg.ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: EnvironmentValue({ value: 0, }),
    ownership: Owned,
    erased_companion: None,
  }
  let entry : @vmcfg.FunctionBody = {
    values: [callable, environment, callable],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstFunction({ value: 0, }, { value: 4, }),
          MakeEnv({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], [
            { value: 0, },
          ]),
          MakeClosure({ value: 2, }, { value: 3, }, { value: 1, }),
          CallDirect({ value: 2, }, None, [], [{ value: 2, }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  let apply : @vmcfg.FunctionBody = {
    values: [callable],
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
        terminator: TailCallValue({ value: 0, }, [], []),
      },
    ],
  }
  let wrapper : @vmcfg.FunctionBody = {
    values: [environment, { ..callable, ownership: Borrowed, }],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          BorrowCapture({ value: 0, }, { value: 0, }, 0, {
            value_destination: { value: 1, },
            witness_destination: None,
          }),
        ],
        terminator: TailCallValue({ value: 1, }, [], []),
      },
    ],
  }
  let leaf : @vmcfg.FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let image : @vmcfg.Image = {
    exports: [@physical.physical_export(function={ value: 1, }, name="_start")],
    initializer: None,
    data_family_count: 0,
    functions: [Body(entry), Body(apply), Body(wrapper), Body(leaf)],
    globals: [],
    constants: [],
    layouts: [Environment({ value: 0, })],
    object_shapes: [
      Environment({
        stored_witness_count: 0,
        members: [
          {
            representation: I64,
            cleanup: OwnedCallable,
            kind: CallableValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
  }
  let finalized = match @vmcfg.finalize_observed(image) {
    Ok(finalized) => finalized
    Err(error) => fail("finalization failed: \{Repr(error)}")
  }
  // Every call is resolved, including the wrapper's captured callable. The
  // remaining packed direct call still uses the actual closure instance.
  debug_inspect(finalized.indirect_calls(), content="[]")
}

///|
test "constructor projection refines a joined callable container" {
  let scalar : @vmcfg.ValueMetadata = {
    representation: I32,
    cleanup: Trivial,
    kind: ScalarValue,
    ownership: Trivial,
    erased_companion: None,
  }
  let callable : @vmcfg.ValueMetadata = {
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    ownership: Owned,
    erased_companion: None,
  }
  let data : @vmcfg.ValueMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 0, }),
    ownership: Owned,
    erased_companion: None,
  }
  let entry : @vmcfg.FunctionBody = {
    values: [scalar, callable, data, data, data],
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
          ConstFunction({ value: 1, }, { value: 3, }),
          MakeData({ value: 2, }, { value: 0, }, Immediate({ value: 1, }), [], []),
          MakeData({ value: 3, }, { value: 1, }, Immediate({ value: 2, }), [], [
            { value: 1, },
          ]),
        ],
        terminator: BranchBool(
          { value: 0, },
          { target: { value: 1, }, arguments: [{ value: 2, }], },
          { target: { value: 1, }, arguments: [{ value: 3, }], },
        ),
      },
      {
        parameters: [{ value: 4, }],
        instructions: [],
        terminator: TailCallDirect({ value: 2, }, None, [], [{ value: 4, }]),
      },
    ],
  }
  let apply : @vmcfg.FunctionBody = {
    values: [data, scalar, { ..callable, ownership: Borrowed, }],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [LoadTag({ value: 1, }, { value: 0, })],
        terminator: SwitchTag(
          { value: 1, },
          [
            { target: { value: 1, }, arguments: [], },
            { target: { value: 2, }, arguments: [], },
          ],
          { target: { value: 3, }, arguments: [], },
        ),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      {
        parameters: [],
        instructions: [
          BorrowField({ value: 1, }, { value: 0, }, 0, {
            value_destination: { value: 2, },
            witness_destination: None,
          }),
        ],
        terminator: TailCallValue({ value: 2, }, [], []),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  let leaf : @vmcfg.FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None), }],
  }
  let image : @vmcfg.Image = {
    exports: [
      @physical.physical_export(function={ value: 1, }, name="apply_choice"),
    ],
    initializer: None,
    data_family_count: 1,
    functions: [Body(entry), Body(apply), Body(leaf)],
    globals: [],
    constants: [],
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
      Data({
        family: { value: 0, },
        constructor_tag: 1,
        stored_witness_count: 0,
        members: [
          {
            representation: I64,
            cleanup: OwnedCallable,
            kind: CallableValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
  }
  let finalized = match @vmcfg.finalize_observed(image) {
    Ok(finalized) => finalized
    Err(error) => fail("finalization failed: \{Repr(error)}")
  }
  debug_inspect(finalized.indirect_calls(), content="[]")
}
