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
