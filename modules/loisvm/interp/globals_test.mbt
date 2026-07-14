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
    functions: [BytecodeBody(initializer), BytecodeBody(entry)],
    globals: [{ representation: I64, cleanup: Trivial, erased_companion: None }],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "interpreter reports invalid instance-global initialization" {
  let trivial_i64 : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    erased_companion: None,
  }
  let duplicate = global_test_image(
    global_test_body([trivial_i64], [
      ConstInt({ value: 0 }, 1L),
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
      ConstInt({ value: 0 }, 1L),
      InitGlobal({ value: 0 }, { value: 0 }),
    ]),
    global_test_body([trivial_i64], [
      ConstInt({ value: 0 }, 2L),
      InitGlobal({ value: 0 }, { value: 0 }),
    ]),
  )
  let cases : Array[(@bytecode.BytecodeImage, @runtime.ExecutionError)] = [
    (
      duplicate,
      InternalRuntimeFailure(detail="GlobalId 0 was initialized twice"),
    ),
    (
      incomplete,
      InternalRuntimeFailure(detail="initializer left GlobalId 0 uninitialized"),
    ),
    (
      premature_read,
      InternalRuntimeFailure(detail="read from uninitialized GlobalId 0"),
    ),
    (
      outside_initialization,
      InternalRuntimeFailure(
        detail="init_global executed outside initialization",
      ),
    ),
  ]
  for case in cases {
    let (image, expected) = case
    let loaded = match load(image, @runtime.RuntimeRegistry::new()) {
      Ok(loaded) => loaded
      Err(error) => fail("load failed: \{to_repr(error)}")
    }
    assert_eq(loaded.new_instance().execute(), Err(expected))
  }
}
