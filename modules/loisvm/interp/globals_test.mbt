///|
fn global_test_body(
  slots : Array[@bytecode.SlotMetadata],
  instructions : Array[@bytecode.Instruction],
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
fn global_test_image(
  initializer : @bytecode.FunctionBody,
  entry : @bytecode.FunctionBody,
) -> @bytecode.BytecodeImage {
  {
    entry: { value: 2 },
    initializer: Some({ value: 1 }),
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    functions: [BytecodeBody(initializer), BytecodeBody(entry)],
    globals: [
      {
        representation: I64,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "loader rejects invalid instance-global initialization" {
  let trivial_i64 : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let duplicate = global_test_image(
    global_test_body([trivial_i64], [
      ConstI64({ value: 0 }, 1L),
      InitGlobal({ value: 0 }, { value: 0 }),
      InitGlobal({ value: 0 }, { value: 0 }),
    ]),
    global_test_body([], []),
  )
  let incomplete = global_test_image(
    global_test_body([], []),
    global_test_body([], []),
  )
  let premature_read = global_test_image(
    global_test_body([trivial_i64], [BorrowGlobal({ value: 0 }, { value: 0 })]),
    global_test_body([], []),
  )
  let outside_initialization = global_test_image(
    global_test_body([trivial_i64], [
      ConstI64({ value: 0 }, 1L),
      InitGlobal({ value: 0 }, { value: 0 }),
    ]),
    global_test_body([trivial_i64], [
      ConstI64({ value: 0 }, 2L),
      InitGlobal({ value: 0 }, { value: 0 }),
    ]),
  )
  let cases : Array[(@bytecode.BytecodeImage, LoadError)] = [
    (
      duplicate,
      InvalidBytecode(
        InvalidBytecode(
          site=Instruction({ value: 1 }, { value: 0 }, 2),
          detail="GlobalId 0 is initialized twice",
        ),
      ),
    ),
    (
      incomplete,
      InvalidBytecode(
        InvalidBytecode(
          site=Terminator({ value: 1 }, { value: 0 }),
          detail="initializer leaves GlobalId 0 uninitialized",
        ),
      ),
    ),
    (
      premature_read,
      InvalidBytecode(
        InvalidBytecode(
          site=Instruction({ value: 1 }, { value: 0 }, 0),
          detail="read from uninitialized GlobalId 0",
        ),
      ),
    ),
    (
      outside_initialization,
      InvalidBytecode(
        InvalidBytecode(
          site=Instruction({ value: 2 }, { value: 0 }, 1),
          detail="InitGlobal appears outside the instance initializer",
        ),
      ),
    ),
  ]
  for case in cases {
    let (image, expected) = case
    let actual = match load(image, @runtime.RuntimeRegistry::new()) {
      Err(error) => error
      Ok(_) => fail("invalid image loaded successfully")
    }
    assert_eq(actual, expected)
  }
}
