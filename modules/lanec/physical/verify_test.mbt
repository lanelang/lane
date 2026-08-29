///|
fn verification_slot(
  representation : Representation,
  cleanup? : Cleanup = Trivial,
  kind? : SemanticValueKind? = None,
) -> SlotMetadata {
  let kind = match kind {
    Some(kind) => kind
    None =>
      match cleanup {
        Trivial => ScalarValue
        OwnedRef => ByteSequenceValue
        OwnedCallable => CallableValue
        OwnedErased => ErasedValue
      }
  }
  { representation, cleanup, kind, erased_companion: None, }
}

///|
fn verification_body(
  slots? : Array[SlotMetadata] = [],
  instructions? : Array[Instruction] = [],
  terminator? : Terminator = Return(None),
) -> FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator, }],
  }
}

///|
fn verification_image(
  body : FunctionBody,
  functions? : Array[FunctionEntry] = [],
  constants? : Array[Bytes] = [],
  data_family_count? : Int = 0,
) -> PhysicalProgram {
  let entries : Array[FunctionEntry] = [PhysicalBody(body)]
  entries.append(functions)
  let callable_abis : Array[CallableAbi] = []
  for entry in entries {
    if entry.callable_abi() is Some(abi) && !callable_abis.contains(abi) {
      callable_abis.push(abi)
    }
  }
  {
    entry: { value: 1, },
    initializer: None,
    callable_abis,
    data_family_count,
    functions: entries,
    globals: [],
    layouts: [],
    object_shapes: [],
    constants,
  }
}

///|
test "physical verifier accepts a complete minimal image" {
  assert_eq(
    verify_physical_program(verification_image(verification_body())),
    Ok(()),
  )
}

///|
fn ordered_global_image(initialization_order : Array[Int]) -> PhysicalProgram {
  let slots = initialization_order.map(_ => verification_slot(I64))
  let instructions : Array[Instruction] = []
  for slot, global in initialization_order {
    instructions.push(ConstI64({ value: slot, }, global.to_int64()))
    instructions.push(InitGlobal({ value: global, }, { value: slot, }))
  }
  let initializer = verification_body(slots~, instructions~)
  {
    ..verification_image(verification_body(), functions=[
      PhysicalBody(initializer),
    ]),
    initializer: Some({ value: 2, }),
    globals: Array::make(2, {
      representation: I64,
      cleanup: Trivial,
      kind: ScalarValue,
      erased_companion: None,
    }),
  }
}

///|
test "physical verifier owns canonical instance-global initialization order" {
  let verified = verify_physical_program_for_execution(
    ordered_global_image([0, 1]),
  )
  guard verified is Ok(verified) else {
    fail("ordered global initialization should verify")
  }
  debug_inspect(
    verified.global_lifecycle(),
    content=(
      #|{
      #|  roots: [
      #|    {
      #|      global: { value: 0 },
      #|      companion: None,
      #|      cleanup: Trivial,
      #|      owned_ordinal: None,
      #|    },
      #|    {
      #|      global: { value: 1 },
      #|      companion: None,
      #|      cleanup: Trivial,
      #|      owned_ordinal: None,
      #|    },
      #|  ],
      #|  root_ordinals: [0, 1],
      #|  owned_roots: [],
      #|}
    ),
  )
  assert_true(verify_physical_program(ordered_global_image([1, 0])) is Err(_))
}

///|
test "physical verifier enforces Fatal message shape" {
  let message = verification_slot(
    I32,
    cleanup=OwnedRef,
    kind=Some(ByteSequenceValue),
  )
  let fatal = {
    ..verification_body(slots=[message], terminator=Fatal({ value: 0, })),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Unit,
  }
  assert_eq(
    verify_physical_program(
      verification_image(verification_body(), functions=[PhysicalBody(fatal)]),
    ),
    Ok(()),
  )
  let wrong_message = { ..fatal, slots: [verification_slot(I32)], }
  assert_true(
    verify_physical_program(
      verification_image(verification_body(), functions=[
        PhysicalBody(wrong_message),
      ]),
    )
    is Err(_),
  )
}

///|
test "physical verifier rejects scalar values used as object references" {
  let body = verification_body(
    slots=[verification_slot(I32), verification_slot(I32)],
    instructions=[
      ConstI32({ value: 0, }, 42),
      LoadTag({ value: 1, }, { value: 0, }),
    ],
  )
  assert_true(verify_physical_program(verification_image(body)) is Err(_))
}

///|
test "physical verifier does not interchange reference semantic categories" {
  let byte_sequence_body = verification_body(
    slots=[verification_slot(I32, cleanup=OwnedRef), verification_slot(I32)],
    instructions=[
      ConstString({ value: 0, }, { value: 0, }),
      LoadTag({ value: 1, }, { value: 0, }),
      Release({ value: 0, }),
    ],
  )
  let environment_body = verification_body(
    slots=[
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(EnvironmentValue({ value: 0, })),
      ),
      verification_slot(I32),
    ],
    instructions=[
      MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      LoadTag({ value: 1, }, { value: 0, }),
      Release({ value: 0, }),
    ],
  )
  let data_body = verification_body(
    slots=[
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I64),
    ],
    instructions=[
      MakeData({ value: 0, }, { value: 1, }, Immediate({ value: 2, }), [], []),
      BorrowCapture({ value: 0, }, { value: 0, }, 0, {
        value_destination: { value: 1, },
        witness_destination: None,
      }),
      Release({ value: 0, }),
    ],
  )
  let environment_shape : ObjectShape = Environment({
    stored_witness_count: 0,
    members: [],
  })
  let data_shape : ObjectShape = Data({
    family: { value: 0, },
    constructor_tag: 0,
    stored_witness_count: 0,
    members: [],
  })
  assert_eq(
    verify_physical_program(
      verification_image(byte_sequence_body, constants=[b"bytes"]),
    ),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="SlotId 0 must hold a Data value",
      ),
    ),
  )
  assert_eq(
    verify_physical_program({
      ..verification_image(environment_body),
      layouts: [Environment({ value: 0, })],
      object_shapes: [environment_shape],
    }),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="SlotId 0 must hold a Data value",
      ),
    ),
  )
  assert_eq(
    verify_physical_program({
      ..verification_image(data_body),
      data_family_count: 1,
      layouts: [Environment({ value: 0, }), Data({ value: 1, })],
      object_shapes: [environment_shape, data_shape],
    }),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="SlotId 0 must have EnvironmentValue({ value: 0 }) semantic kind, got DataValue({ value: 0 })",
      ),
    ),
  )
}

///|
test "physical verifier owns Char and runtime import name semantics" {
  let invalid_char = verification_image(
    verification_body(slots=[verification_slot(I32)], instructions=[
      ConstChar({ value: 0, }, 0xD800),
    ]),
  )
  let invalid_symbol = verification_image(verification_body(), functions=[
    RuntimeImport({
      module_name: "lane.test",
      field_name: "",
      parameters: [],
      result: Unit,
    }),
  ])
  assert_true(verify_physical_program(invalid_char) is Err(_))
  assert_true(verify_physical_program(invalid_symbol) is Err(_))
}

///|
test "physical verifier owns every encoding-independent image invariant" {
  let invalid_utf8 = verification_image(verification_body(), constants=[
    Bytes::from_array([b'\xFF']),
  ])
  let non_ascii_symbol = verification_image(verification_body(), functions=[
    RuntimeImport({
      module_name: "lane.test",
      field_name: "中",
      parameters: [],
      result: Unit,
    }),
  ])
  let nul_symbol = verification_image(verification_body(), functions=[
    RuntimeImport({
      module_name: "lane.test",
      field_name: "lane\u{0}symbol",
      parameters: [],
      result: Unit,
    }),
  ])
  assert_true(
    verify_physical_program(invalid_utf8)
    is Err(
      InvalidPhysicalProgram(
        site=Image,
        detail="String constant must contain valid UTF-8"
      )
    ),
  )
  assert_true(
    verify_physical_program(non_ascii_symbol)
    is Err(
      InvalidPhysicalProgram(
        site=Function({ value: 2, }),
        detail="runtime import field name must contain ASCII bytes only"
      )
    ),
  )
  assert_true(
    verify_physical_program(nul_symbol)
    is Err(
      InvalidPhysicalProgram(
        site=Function({ value: 2, }),
        detail="runtime import field name must not contain NUL"
      )
    ),
  )
}

///|
fn two_constructor_data_shapes() -> Array[ObjectShape] {
  [
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
          cleanup: Trivial,
          kind: ScalarValue,
          witness_ordinal: None,
        },
      ],
    }),
  ]
}

///|
test "physical verifier rejects wrong exact object shapes" {
  let body = verification_body(
    slots=[
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I64),
    ],
    instructions=[
      MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      BorrowField({ value: 1, }, { value: 0, }, 0, {
        value_destination: { value: 1, },
        witness_destination: None,
      }),
    ],
  )
  let image = {
    ..verification_image(body),
    data_family_count: 1,
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: two_constructor_data_shapes(),
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="SlotId 0 has ObjectShapeId 0, expected ObjectShapeId 1",
      ),
    ),
  )
}

///|
test "physical verifier rejects projections without exact shape proof" {
  let body = {
    ..verification_body(
      slots=[
        verification_slot(
          I32,
          cleanup=OwnedRef,
          kind=Some(DataValue({ value: 0, })),
        ),
        verification_slot(I64),
      ],
      instructions=[
        BorrowField({ value: 1, }, { value: 0, }, 0, {
          value_destination: { value: 1, },
          witness_destination: None,
        }),
      ],
    ),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
  }
  let image = {
    ..verification_image(verification_body(), functions=[PhysicalBody(body)]),
    data_family_count: 1,
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: two_constructor_data_shapes(),
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 2, }, { value: 0, }, 0),
        detail="SlotId 0 has no proven ObjectShapeId 1",
      ),
    ),
  )
}

///|
test "physical verifier refines exact shape in tag switch cases" {
  let body : FunctionBody = {
    slots: [
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I32),
      verification_slot(I64),
    ],
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
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
      {
        parameters: [],
        instructions: [
          ConsumeFields({ value: 1, }, { value: 0, }, [
            {
              member_index: 0,
              result: {
                value_destination: { value: 2, },
                witness_destination: None,
              },
            },
          ]),
        ],
        terminator: Return(None),
      },
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
    ],
  }
  let image = {
    ..verification_image(verification_body(), functions=[PhysicalBody(body)]),
    data_family_count: 1,
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: two_constructor_data_shapes(),
  }
  assert_eq(verify_physical_program(image), Ok(()))
}

///|
test "physical verifier forgets different exact shapes at joins" {
  let body : FunctionBody = {
    slots: [
      verification_slot(I32),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I64),
    ],
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
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [
          MakeData({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], []),
        ],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 4, }, 0L),
          MakeData({ value: 2, }, { value: 1, }, Immediate({ value: 2, }), [], [
            { value: 4, },
          ]),
        ],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 2, }], }),
      },
      {
        parameters: [{ value: 3, }],
        instructions: [
          ConsumeFields({ value: 1, }, { value: 3, }, [
            {
              member_index: 0,
              result: {
                value_destination: { value: 4, },
                witness_destination: None,
              },
            },
          ]),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image = {
    ..verification_image(verification_body(), functions=[PhysicalBody(body)]),
    data_family_count: 1,
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: two_constructor_data_shapes(),
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 2, }, { value: 3, }, 0),
        detail="SlotId 3 has no proven ObjectShapeId 1",
      ),
    ),
  )
}

///|
test "closed reference ABI cannot turn ByteSequence into Data" {
  let data_kind = @physical.DataValue({ value: 0, })
  let target : FunctionBody = {
    slots: [verification_slot(I32, cleanup=OwnedRef, kind=Some(data_kind))],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I32, OwnedRef, data_kind),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Return(Some({ value: 0, })),
      },
    ],
  }
  let data_slot = verification_slot(
    I32,
    cleanup=OwnedRef,
    kind=Some(DataValue({ value: 0, })),
  )
  let data_shape : ObjectShape = Data({
    family: { value: 0, },
    constructor_tag: 0,
    stored_witness_count: 0,
    members: [],
  })
  let rejected = {
    ..verification_image(
      verification_body(
        slots=[verification_slot(I32, cleanup=OwnedRef), data_slot],
        instructions=[
          ConstString({ value: 0, }, { value: 0, }),
          CallDirect(
            { value: 2, },
            None,
            [],
            [{ value: 0, }],
            Some({ value: 1, }),
          ),
        ],
      ),
      functions=[PhysicalBody(target)],
      constants=[b"not data"],
    ),
    data_family_count: 1,
    object_shapes: [data_shape],
  }
  assert_true(
    verify_physical_program(rejected)
    is Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="call argument 0 has the wrong value shape"
      )
    ),
  )
  let accepted = {
    ..verification_image(
      verification_body(slots=[data_slot, data_slot], instructions=[
        MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
        CallDirect(
          { value: 2, },
          None,
          [],
          [{ value: 0, }],
          Some({ value: 1, }),
        ),
        Release({ value: 1, }),
      ]),
      functions=[PhysicalBody(target)],
    ),
    data_family_count: 1,
    layouts: [Data({ value: 0, })],
    object_shapes: [data_shape],
  }
  assert_eq(verify_physical_program(accepted), Ok(()))
}

///|
test "physical verifier checks instruction representation contracts" {
  let image = verification_image(
    verification_body(
      slots=[verification_slot(I32, cleanup=OwnedRef), verification_slot(F64)],
      instructions=[F32ToString({ value: 0, }, { value: 1, })],
    ),
  )
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 0),
        detail="SlotId 1 must be F32 + Trivial, got F64 + Trivial",
      ),
    ),
  )
}

///|
test "physical verifier rejects uninitialized reads and owner overwrites" {
  let uninitialized = verification_image(
    verification_body(
      slots=[verification_slot(I32, cleanup=OwnedRef), verification_slot(F32)],
      instructions=[F32ToString({ value: 0, }, { value: 1, })],
    ),
  )
  let overwritten = verification_image(
    verification_body(slots=[verification_slot(I32, cleanup=OwnedRef)], instructions=[
      ConstString({ value: 0, }, { value: 0, }),
      ConstString({ value: 0, }, { value: 1, }),
    ]),
    constants=[b"a", b"b"],
  )
  debug_inspect(
    (
      verify_physical_program(uninitialized),
      verify_physical_program(overwritten),
    ),
    content=(
      #|(
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|      detail="read from uninitialized SlotId 1",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 1),
      #|      detail="write would overwrite live owner SlotId 0",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "physical verifier checks direct-call ABI and edge arity" {
  let target = {
    ..verification_body(slots=[verification_slot(I64)]),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
  }
  let wrong_call = verification_image(
    verification_body(instructions=[
      CallDirect({ value: 2, }, None, [], [], None),
    ]),
    functions=[PhysicalBody(target)],
  )
  let wrong_edge_body = {
    ..verification_body(
      slots=[verification_slot(I64)],
      terminator=Jump({ target: { value: 1, }, arguments: [], }),
    ),
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Jump({ target: { value: 1, }, arguments: [], }),
      },
      {
        parameters: [{ value: 0, }],
        instructions: [],
        terminator: Return(None),
      },
    ],
  }
  debug_inspect(
    (
      verify_physical_program(wrong_call),
      verify_physical_program(verification_image(wrong_edge_body)),
    ),
    content=(
      #|(
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|      detail="call has the wrong user argument count",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Terminator({ value: 1 }, { value: 0 }),
      #|      detail="edge to BlockId 1 has 0 arguments for 1 parameters",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "physical verifier checks CallValue ABI identity and physical shape" {
  let callable = verification_slot(I64, cleanup=OwnedCallable)
  let argument = verification_slot(I32)
  let body = verification_body(slots=[callable, argument], instructions=[
    ConstFunction({ value: 0, }, { value: 1, }),
    ConstBool({ value: 1, }, true),
    CallValue({ value: 0, }, { value: 1, }, [], [{ value: 1, }], None),
  ])
  let image = {
    ..verification_image(body),
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [
          { representation: I64, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Unit,
      },
    ],
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 2),
        detail="call argument 0 has the wrong value shape",
      ),
    ),
  )
  let invalid_abi = {
    ..image,
    functions: [
      PhysicalBody({
        ..body,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstFunction({ value: 0, }, { value: 1, }),
              CallValue({ value: 0, }, { value: 2, }, [], [], None),
            ],
            terminator: Return(None),
          },
        ],
      }),
    ],
  }
  assert_eq(
    verify_physical_program(invalid_abi),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="CallableAbiId 2 is out of range",
      ),
    ),
  )
}

///|
test "physical verifier rejects a forged layout constructor arity" {
  let constructor_slot = verification_slot(
    I64,
    cleanup=OwnedCallable,
    kind=Some(LayoutConstructorValue(2)),
  )
  let caller = verification_body(slots=[constructor_slot], instructions=[
    ConstFunction({ value: 0, }, { value: 2, }),
    Release({ value: 0, }),
  ])
  let layout = verification_slot(I32, kind=Some(LayoutValue))
  let implementation = {
    ..verification_body(slots=[layout], terminator=Return(Some({ value: 0, }))),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
    result: Value(I32, Trivial, LayoutValue),
  }
  assert_eq(
    verify_physical_program(
      verification_image(caller, functions=[PhysicalBody(implementation)]),
    ),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 0),
        detail="layout constructor ABI has the wrong arity",
      ),
    ),
  )
}

///|
test "physical verifier rejects call result ownership mismatch" {
  let target = {
    ..verification_body(
      slots=[verification_slot(I32)],
      instructions=[ConstI32({ value: 0, }, 42)],
      terminator=Return(Some({ value: 0, })),
    ),
    result: Value(I32, Trivial, ScalarValue),
  }
  let caller = verification_body(
    slots=[verification_slot(I32, cleanup=OwnedRef)],
    instructions=[
      CallDirect({ value: 2, }, None, [], [], Some({ value: 0, })),
      Release({ value: 0, }),
    ],
  )
  assert_eq(
    verify_physical_program(
      verification_image(caller, functions=[PhysicalBody(target)]),
    ),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 0),
        detail="call result ABI does not match destination slot",
      ),
    ),
  )
}

///|
test "physical verifier enforces result ABI at every static call boundary" {
  let bad_return = {
    ..verification_body(
      slots=[verification_slot(I32)],
      instructions=[ConstI32({ value: 0, }, 42)],
      terminator=Return(Some({ value: 0, })),
    ),
    result: Value(I32, OwnedRef, ByteSequenceValue),
  }
  let tail_caller = {
    ..verification_body(terminator=TailCallDirect({ value: 3, }, None, [], [])),
    result: Value(I32, OwnedRef, ByteSequenceValue),
  }
  let scalar_target = {
    ..verification_body(
      slots=[verification_slot(I32)],
      instructions=[ConstI32({ value: 0, }, 42)],
      terminator=Return(Some({ value: 0, })),
    ),
    result: Value(I32, Trivial, ScalarValue),
  }
  let import_caller = verification_body(
    slots=[
      verification_slot(I32, cleanup=OwnedRef, kind=Some(ByteSequenceValue)),
    ],
    instructions=[CallDirect({ value: 2, }, None, [], [], Some({ value: 0, }))],
  )
  let scalar_import : @wasm_abi.ImportContract = {
    module_name: "lane.test",
    field_name: "lane.test.string",
    parameters: [],
    result: Direct(I32),
  }
  debug_inspect(
    (
      verify_physical_program(
        verification_image(verification_body(), functions=[
          PhysicalBody(bad_return),
        ]),
      ),
      verify_physical_program(
        verification_image(verification_body(), functions=[
          PhysicalBody(tail_caller),
          PhysicalBody(scalar_target),
        ]),
      ),
      verify_physical_program(
        verification_image(import_caller, functions=[
          RuntimeImport(scalar_import),
        ]),
      ),
    ),
    content=(
      #|(
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Terminator({ value: 2 }, { value: 0 }),
      #|      detail="SlotId 0 must be I32 + OwnedRef, got I32 + Trivial",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Terminator({ value: 2 }, { value: 0 }),
      #|      detail="tail-call result ABI does not match caller",
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidPhysicalProgram(
      #|      site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|      detail="call result ABI does not match destination slot",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "physical verifier rejects an erased member with the wrong stored evidence" {
  let body = verification_body(
    slots=[
      verification_slot(I32, kind=Some(LayoutValue)),
      verification_slot(I32, kind=Some(LayoutValue)),
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some({ value: 0, }),
      },
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
    ],
    instructions=[
      ConstLayout({ value: 0, }, { value: 1, }),
      ConstLayout({ value: 1, }, { value: 2, }),
      EraseUnit({ value: 2, }),
      MakeData(
        { value: 3, },
        { value: 0, },
        Immediate({ value: 3, }),
        [{ value: 1, }],
        [{ value: 2, }],
      ),
      Release({ value: 3, }),
    ],
  )
  let image = {
    ..verification_image(body),
    data_family_count: 1,
    layouts: [Unit, I64, Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 1,
        members: [
          {
            representation: I64,
            cleanup: OwnedErased,
            kind: ErasedValue,
            witness_ordinal: Some(0),
          },
        ],
      }),
    ],
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 3),
        detail="erased object member does not use its stored layout witness",
      ),
    ),
  )
}

///|
test "physical verifier requires a dynamic object layout to prove its shape" {
  let body = verification_body(
    slots=[
      verification_slot(I32, kind=Some(LayoutValue)),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
    ],
    instructions=[
      ConstLayout({ value: 0, }, { value: 1, }),
      MakeData({ value: 1, }, { value: 0, }, Witness({ value: 0, }), [], []),
    ],
  )
  let image = {
    ..verification_image(body),
    data_family_count: 1,
    layouts: [Environment({ value: 1, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
      Environment({ stored_witness_count: 0, members: [], }),
    ],
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="object layout witness references a different shape",
      ),
    ),
  )
}

///|
test "physical verifier transfers object shape through erasure" {
  let slots = [
    verification_slot(I32, kind=Some(LayoutValue)),
    verification_slot(
      I32,
      cleanup=OwnedRef,
      kind=Some(DataValue({ value: 0, })),
    ),
    {
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
      erased_companion: Some({ value: 0, }),
    },
    verification_slot(
      I32,
      cleanup=OwnedRef,
      kind=Some(DataValue({ value: 0, })),
    ),
  ]
  let instructions : Array[Instruction] = [
    ConstLayout({ value: 0, }, { value: 2, }),
    MakeData({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], []),
    EraseI32({ value: 2, }, { value: 1, }),
    UneraseI32({ value: 3, }, { value: 2, }),
    ConsumeFields({ value: 0, }, { value: 3, }, []),
  ]
  let image = {
    ..verification_image(verification_body(slots~, instructions~)),
    data_family_count: 1,
    layouts: [Data({ value: 0, }), Reference],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
    ],
  }
  assert_eq(verify_physical_program(image), Ok(()))
}

///|
test "physical verifier rejects unerasure into an incompatible object kind" {
  let slots = [
    verification_slot(I32, kind=Some(LayoutValue)),
    verification_slot(
      I32,
      cleanup=OwnedRef,
      kind=Some(DataValue({ value: 0, })),
    ),
    {
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
      erased_companion: Some({ value: 0, }),
    },
    verification_slot(
      I32,
      cleanup=OwnedRef,
      kind=Some(EnvironmentValue({ value: 1, })),
    ),
  ]
  let instructions : Array[Instruction] = [
    ConstLayout({ value: 0, }, { value: 2, }),
    MakeData({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], []),
    EraseI32({ value: 2, }, { value: 1, }),
    UneraseI32({ value: 3, }, { value: 2, }),
  ]
  let image = {
    ..verification_image(verification_body(slots~, instructions~)),
    data_family_count: 1,
    layouts: [Data({ value: 0, }), Reference],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [],
      }),
      Environment({ stored_witness_count: 0, members: [], }),
    ],
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 3),
        detail="unerasure destination does not accept proven ObjectShapeId 0",
      ),
    ),
  )
}

///|
test "physical verifier rejects using a field borrow after owner release" {
  let body = verification_body(
    slots=[
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I32, cleanup=OwnedRef, kind=Some(ByteSequenceValue)),
      verification_slot(I32, kind=Some(ByteSequenceValue)),
      verification_slot(I32, cleanup=OwnedRef, kind=Some(ByteSequenceValue)),
    ],
    instructions=[
      ConstString({ value: 1, }, { value: 0, }),
      MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], [
        { value: 1, },
      ]),
      BorrowField({ value: 0, }, { value: 0, }, 0, {
        value_destination: { value: 2, },
        witness_destination: None,
      }),
      Release({ value: 0, }),
      RetainCopy({ value: 3, }, { value: 2, }),
      Release({ value: 3, }),
    ],
  )
  let image = {
    ..verification_image(body, constants=[b"borrowed"]),
    data_family_count: 1,
    layouts: [Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
  }
  assert_eq(
    verify_physical_program(image),
    Err(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 4),
        detail="borrowed SlotId 2 from ObjectShapeId 0 member 0 outlives its local owner",
      ),
    ),
  )
}

///|
test "physical verifier keeps a borrow live across retained and moved owners" {
  let body = verification_body(
    slots=[
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I32, cleanup=OwnedRef, kind=Some(ByteSequenceValue)),
      verification_slot(I32, kind=Some(ByteSequenceValue)),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(I32, cleanup=OwnedRef, kind=Some(ByteSequenceValue)),
    ],
    instructions=[
      ConstString({ value: 1, }, { value: 0, }),
      MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], [
        { value: 1, },
      ]),
      BorrowField({ value: 0, }, { value: 0, }, 0, {
        value_destination: { value: 2, },
        witness_destination: None,
      }),
      RetainCopy({ value: 3, }, { value: 0, }),
      Release({ value: 0, }),
      Move({ value: 4, }, { value: 3, }),
      RetainCopy({ value: 5, }, { value: 2, }),
      Release({ value: 5, }),
      Release({ value: 4, }),
    ],
  )
  let image = {
    ..verification_image(body, constants=[b"borrowed"]),
    data_family_count: 1,
    layouts: [Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
  }
  assert_eq(verify_physical_program(image), Ok(()))
}

///|
test "physical verifier transfers a borrowed member root through projection" {
  let body = verification_body(
    slots=[
      verification_slot(I32, cleanup=OwnedRef, kind=Some(ByteSequenceValue)),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 1, })),
      ),
      verification_slot(I32, kind=Some(DataValue({ value: 0, }))),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
      verification_slot(
        I32,
        cleanup=OwnedRef,
        kind=Some(DataValue({ value: 0, })),
      ),
    ],
    instructions=[
      ConstString({ value: 0, }, { value: 0, }),
      MakeData({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], [
        { value: 0, },
      ]),
      MakeData({ value: 2, }, { value: 1, }, Immediate({ value: 2, }), [], [
        { value: 1, },
      ]),
      BorrowField({ value: 1, }, { value: 2, }, 0, {
        value_destination: { value: 3, },
        witness_destination: None,
      }),
      ConsumeFields({ value: 1, }, { value: 2, }, [
        {
          member_index: 0,
          result: {
            value_destination: { value: 4, },
            witness_destination: None,
          },
        },
      ]),
      RetainCopy({ value: 5, }, { value: 3, }),
      Release({ value: 5, }),
      Release({ value: 4, }),
    ],
  )
  let string_member : MemberSchema = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    witness_ordinal: None,
  }
  let owned_member : MemberSchema = {
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue({ value: 0, }),
    witness_ordinal: None,
  }
  let image = {
    ..verification_image(body, constants=[b"borrowed"]),
    data_family_count: 2,
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [string_member],
      }),
      Data({
        family: { value: 1, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [owned_member],
      }),
    ],
  }
  assert_eq(verify_physical_program(image), Ok(()))
}

///|
test "physical verifier merges alternative owner tokens at control flow" {
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
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: BranchBool(
          { value: 0, },
          { target: { value: 1, }, arguments: [], },
          { target: { value: 2, }, arguments: [], },
        ),
      },
      {
        parameters: [],
        instructions: [ConstString({ value: 1, }, { value: 0, })],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 1, }], }),
      },
      {
        parameters: [],
        instructions: [ConstString({ value: 2, }, { value: 1, })],
        terminator: Jump({ target: { value: 3, }, arguments: [{ value: 2, }], }),
      },
      {
        parameters: [{ value: 3, }],
        instructions: [Release({ value: 3, })],
        terminator: Return(None),
      },
    ],
  }
  assert_eq(
    verify_physical_program(
      verification_image(body, constants=[b"left", b"right"]),
    ),
    Ok(()),
  )
}

///|
test "physical verifier transfers a borrowed root from an input projection" {
  let body = {
    ..verification_body(
      slots=[
        verification_slot(
          I32,
          cleanup=OwnedRef,
          kind=Some(DataValue({ value: 0, })),
        ),
        verification_slot(I32, kind=Some(ByteSequenceValue)),
        verification_slot(I32, cleanup=OwnedRef),
        verification_slot(I32, cleanup=OwnedRef),
      ],
      instructions=[
        BorrowField({ value: 0, }, { value: 0, }, 0, {
          value_destination: { value: 1, },
          witness_destination: None,
        }),
        ConsumeFields({ value: 0, }, { value: 0, }, [
          {
            member_index: 0,
            result: {
              value_destination: { value: 2, },
              witness_destination: None,
            },
          },
        ]),
        RetainCopy({ value: 3, }, { value: 1, }),
        Release({ value: 3, }),
        Release({ value: 2, }),
      ],
    ),
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0, }],
    },
  }
  let image = {
    ..verification_image(verification_body(), functions=[PhysicalBody(body)]),
    data_family_count: 1,
    layouts: [Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 0,
        members: [
          {
            representation: I32,
            cleanup: OwnedRef,
            kind: ByteSequenceValue,
            witness_ordinal: None,
          },
        ],
      }),
    ],
  }
  assert_eq(verify_physical_program(image), Ok(()))
}
