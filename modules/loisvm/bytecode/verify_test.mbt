///|
fn verification_slot(
  representation : Representation,
  cleanup? : Cleanup = Trivial,
) -> SlotMetadata {
  { representation, cleanup, erased_companion: None }
}

///|
fn verification_body(
  slots? : Array[SlotMetadata] = [],
  instructions? : Array[Instruction] = [],
  terminator? : Terminator = Return(None),
) -> FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator }],
  }
}

///|
fn verification_image(
  body : FunctionBody,
  functions? : Array[FunctionEntry] = [],
  constants? : Array[Bytes] = [],
) -> BytecodeImage {
  let entries : Array[FunctionEntry] = [BytecodeBody(body)]
  entries.append(functions)
  {
    entry: { value: 1 },
    initializer: None,
    functions: entries,
    globals: [],
    layouts: [],
    object_shapes: [],
    constants,
  }
}

///|
test "bytecode verifier accepts a complete minimal image" {
  assert_eq(
    verify_bytecode_image(verification_image(verification_body())),
    Ok(()),
  )
}

///|
test "bytecode verifier checks instruction representation contracts" {
  let image = verification_image(
    verification_body(
      slots=[verification_slot(I32, cleanup=OwnedRef), verification_slot(F64)],
      instructions=[F32ToString({ value: 0 }, { value: 1 })],
    ),
  )
  assert_eq(
    verify_bytecode_image(image),
    Err(
      InvalidBytecode(
        site=Instruction({ value: 1 }, { value: 0 }, 0),
        detail="SlotId 1 must be F32 + Trivial, got F64 + Trivial",
      ),
    ),
  )
}

///|
test "bytecode verifier rejects uninitialized reads and owner overwrites" {
  let uninitialized = verification_image(
    verification_body(
      slots=[verification_slot(I32, cleanup=OwnedRef), verification_slot(F32)],
      instructions=[F32ToString({ value: 0 }, { value: 1 })],
    ),
  )
  let overwritten = verification_image(
    verification_body(slots=[verification_slot(I32, cleanup=OwnedRef)], instructions=[
      ConstString({ value: 0 }, { value: 0 }),
      ConstString({ value: 0 }, { value: 1 }),
    ]),
    constants=[b"a", b"b"],
  )
  debug_inspect(
    (verify_bytecode_image(uninitialized), verify_bytecode_image(overwritten)),
    content=(
      #|(
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|      detail="read from uninitialized SlotId 1",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 1),
      #|      detail="write would overwrite live owner SlotId 0",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "bytecode verifier checks direct-call ABI and edge arity" {
  let target = {
    ..verification_body(slots=[verification_slot(I64)]),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
  }
  let wrong_call = verification_image(
    verification_body(instructions=[
      CallDirect({ value: 2 }, None, [], [], None),
    ]),
    functions=[BytecodeBody(target)],
  )
  let wrong_edge_body = {
    ..verification_body(
      slots=[verification_slot(I64)],
      terminator=Jump({ target: { value: 1 }, arguments: [] }),
    ),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Jump({ target: { value: 1 }, arguments: [] }),
      },
      { parameters: [{ value: 0 }], instructions: [], terminator: Return(None) },
    ],
  }
  debug_inspect(
    (
      verify_bytecode_image(wrong_call),
      verify_bytecode_image(verification_image(wrong_edge_body)),
    ),
    content=(
      #|(
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|      detail="direct call has the wrong user argument count",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Terminator({ value: 1 }, { value: 0 }),
      #|      detail="edge to BlockId 1 has 0 arguments for 1 parameters",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "bytecode verifier rejects call result ownership mismatch" {
  let target = {
    ..verification_body(
      slots=[verification_slot(I32)],
      instructions=[ConstI32({ value: 0 }, 42)],
      terminator=Return(Some({ value: 0 })),
    ),
    result: Value(I32, Trivial),
  }
  let caller = verification_body(
    slots=[verification_slot(I32, cleanup=OwnedRef)],
    instructions=[
      CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      Release({ value: 0 }),
    ],
  )
  assert_eq(
    verify_bytecode_image(
      verification_image(caller, functions=[BytecodeBody(target)]),
    ),
    Err(
      InvalidBytecode(
        site=Instruction({ value: 1 }, { value: 0 }, 0),
        detail="call result ABI does not match destination slot",
      ),
    ),
  )
}

///|
test "bytecode verifier enforces result ABI at every static call boundary" {
  let bad_return = {
    ..verification_body(
      slots=[verification_slot(I32)],
      instructions=[ConstI32({ value: 0 }, 42)],
      terminator=Return(Some({ value: 0 })),
    ),
    result: Value(I32, OwnedRef),
  }
  let tail_caller = {
    ..verification_body(terminator=TailCallDirect({ value: 3 }, None, [], [])),
    result: Value(I32, OwnedRef),
  }
  let scalar_target = {
    ..verification_body(
      slots=[verification_slot(I32)],
      instructions=[ConstI32({ value: 0 }, 42)],
      terminator=Return(Some({ value: 0 })),
    ),
    result: Value(I32, Trivial),
  }
  let import_caller = verification_body(slots=[verification_slot(I32)], instructions=[
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
  ])
  let string_import : RuntimeImport = {
    abi_major: 1,
    parameters: [],
    result: String,
    symbol: "lane.test.string",
  }
  debug_inspect(
    (
      verify_bytecode_image(
        verification_image(verification_body(), functions=[
          BytecodeBody(bad_return),
        ]),
      ),
      verify_bytecode_image(
        verification_image(verification_body(), functions=[
          BytecodeBody(tail_caller),
          BytecodeBody(scalar_target),
        ]),
      ),
      verify_bytecode_image(
        verification_image(import_caller, functions=[
          RuntimeImport(string_import),
        ]),
      ),
    ),
    content=(
      #|(
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Terminator({ value: 2 }, { value: 0 }),
      #|      detail="SlotId 0 must be I32 + OwnedRef, got I32 + Trivial",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Terminator({ value: 2 }, { value: 0 }),
      #|      detail="tail-call result ABI does not match caller",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|      detail="call result ABI does not match destination slot",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "bytecode verifier rejects using a field borrow after owner release" {
  let body = verification_body(
    slots=[
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32),
      verification_slot(I32, cleanup=OwnedRef),
    ],
    instructions=[
      ConstString({ value: 1 }, { value: 0 }),
      MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], [
        { value: 1 },
      ]),
      BorrowField({ value: 0 }, { value: 0 }, 0, {
        value_destination: { value: 2 },
        witness_destination: None,
      }),
      Release({ value: 0 }),
      RetainCopy({ value: 3 }, { value: 2 }),
      Release({ value: 3 }),
    ],
  )
  let image = {
    ..verification_image(body, constants=[b"borrowed"]),
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          { representation: I32, cleanup: OwnedRef, witness_ordinal: None },
        ],
      }),
    ],
  }
  assert_eq(
    verify_bytecode_image(image),
    Err(
      InvalidBytecode(
        site=Instruction({ value: 1 }, { value: 0 }, 4),
        detail="borrowed SlotId 2 from ObjectShapeId 0 member 0 outlives its local owner",
      ),
    ),
  )
}

///|
test "bytecode verifier keeps a borrow live across retained and moved owners" {
  let body = verification_body(
    slots=[
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
    ],
    instructions=[
      ConstString({ value: 1 }, { value: 0 }),
      MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], [
        { value: 1 },
      ]),
      BorrowField({ value: 0 }, { value: 0 }, 0, {
        value_destination: { value: 2 },
        witness_destination: None,
      }),
      RetainCopy({ value: 3 }, { value: 0 }),
      Release({ value: 0 }),
      Move({ value: 4 }, { value: 3 }),
      RetainCopy({ value: 5 }, { value: 2 }),
      Release({ value: 5 }),
      Release({ value: 4 }),
    ],
  )
  let image = {
    ..verification_image(body, constants=[b"borrowed"]),
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          { representation: I32, cleanup: OwnedRef, witness_ordinal: None },
        ],
      }),
    ],
  }
  assert_eq(verify_bytecode_image(image), Ok(()))
}

///|
test "bytecode verifier transfers a borrowed member root through projection" {
  let body = verification_body(
    slots=[
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
    ],
    instructions=[
      ConstString({ value: 0 }, { value: 0 }),
      MakeData({ value: 1 }, { value: 0 }, Immediate({ value: 1 }), [], [
        { value: 0 },
      ]),
      MakeData({ value: 2 }, { value: 1 }, Immediate({ value: 2 }), [], [
        { value: 1 },
      ]),
      BorrowField({ value: 1 }, { value: 2 }, 0, {
        value_destination: { value: 3 },
        witness_destination: None,
      }),
      ConsumeFields({ value: 1 }, { value: 2 }, [
        {
          member_index: 0,
          result: { value_destination: { value: 4 }, witness_destination: None },
        },
      ]),
      RetainCopy({ value: 5 }, { value: 3 }),
      Release({ value: 5 }),
      Release({ value: 4 }),
    ],
  )
  let owned_member : MemberSchema = {
    representation: I32,
    cleanup: OwnedRef,
    witness_ordinal: None,
  }
  let image = {
    ..verification_image(body, constants=[b"borrowed"]),
    layouts: [Data({ value: 0 }), Data({ value: 1 })],
    object_shapes: [
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [owned_member],
      }),
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [owned_member],
      }),
    ],
  }
  assert_eq(verify_bytecode_image(image), Ok(()))
}

///|
test "bytecode verifier merges alternative owner tokens at control flow" {
  let body = {
    ..verification_body(slots=[
      verification_slot(I32),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
      verification_slot(I32, cleanup=OwnedRef),
    ]),
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, true)],
        terminator: BranchBool(
          { value: 0 },
          { target: { value: 1 }, arguments: [] },
          { target: { value: 2 }, arguments: [] },
        ),
      },
      {
        parameters: [],
        instructions: [ConstString({ value: 1 }, { value: 0 })],
        terminator: Jump({ target: { value: 3 }, arguments: [{ value: 1 }] }),
      },
      {
        parameters: [],
        instructions: [ConstString({ value: 2 }, { value: 1 })],
        terminator: Jump({ target: { value: 3 }, arguments: [{ value: 2 }] }),
      },
      {
        parameters: [{ value: 3 }],
        instructions: [Release({ value: 3 })],
        terminator: Return(None),
      },
    ],
  }
  assert_eq(
    verify_bytecode_image(
      verification_image(body, constants=[b"left", b"right"]),
    ),
    Ok(()),
  )
}

///|
test "bytecode verifier transfers a borrowed root from an input projection" {
  let body = {
    ..verification_body(
      slots=[
        verification_slot(I32, cleanup=OwnedRef),
        verification_slot(I32),
        verification_slot(I32, cleanup=OwnedRef),
        verification_slot(I32, cleanup=OwnedRef),
      ],
      instructions=[
        BorrowField({ value: 0 }, { value: 0 }, 0, {
          value_destination: { value: 1 },
          witness_destination: None,
        }),
        ConsumeFields({ value: 0 }, { value: 0 }, [
          {
            member_index: 0,
            result: {
              value_destination: { value: 2 },
              witness_destination: None,
            },
          },
        ]),
        RetainCopy({ value: 3 }, { value: 1 }),
        Release({ value: 3 }),
        Release({ value: 2 }),
      ],
    ),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }],
    },
  }
  let image = {
    ..verification_image(verification_body(), functions=[BytecodeBody(body)]),
    object_shapes: [
      Data({
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          { representation: I32, cleanup: OwnedRef, witness_ordinal: None },
        ],
      }),
    ],
  }
  assert_eq(verify_bytecode_image(image), Ok(()))
}
