///|
fn malformed_slot(value : Int) -> SlotId {
  { value, }
}

///|
fn malformed_function(value : Int) -> FunctionId {
  { value, }
}

///|
fn malformed_global(value : Int) -> GlobalId {
  { value, }
}

///|
fn malformed_layout(value : Int) -> LayoutId {
  { value, }
}

///|
fn malformed_body(instructions? : Array[Instruction] = []) -> FunctionBody {
  {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions, terminator: Return(None) }],
  }
}

///|
fn malformed_minimal_image() -> BytecodeImage {
  {
    entry: malformed_function(1),
    initializer: None,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [BytecodeBody(malformed_body())],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
fn malformed_global_image() -> BytecodeImage {
  let initializer = {
    ..malformed_body(instructions=[
      ConstLayout(malformed_slot(0), malformed_layout(1)),
      EraseUnit(malformed_slot(1)),
      InitGlobal(malformed_global(1), malformed_slot(1)),
      BorrowGlobal(malformed_slot(2), malformed_global(1)),
    ]),
    slots: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        erased_companion: None,
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(malformed_slot(0)),
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(malformed_slot(0)),
      },
    ],
  }
  {
    entry: malformed_function(1),
    initializer: Some(malformed_function(2)),
    callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
    data_family_count: 0,
    functions: [BytecodeBody(malformed_body()), BytecodeBody(initializer)],
    globals: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: LayoutValue,
        erased_companion: None,
      },
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(malformed_global(0)),
      },
    ],
    layouts: [Unit],
    object_shapes: [],
    constants: [],
  }
}

///|
test "decoder validates malformed initializer and global metadata" {
  let missing_initializer = { ..malformed_global_image(), initializer: None }
  let invalid_initializer = {
    ..malformed_global_image(),
    initializer: Some(malformed_function(3)),
  }
  let invalid_companion = {
    ..malformed_global_image(),
    globals: [
      {
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        erased_companion: Some(malformed_global(0)),
      },
    ],
  }
  debug_inspect(
    [missing_initializer, invalid_initializer, invalid_companion].map(image => {
      parse_bytecode_image_binary(unchecked_bytecode_image_to_binary(image))
    }),
    content=(
      #|[
      #|  Err(
      #|    InvalidBytecode(
      #|      error=InvalidBytecode(
      #|        site=Image,
      #|        detail="nonempty instance global table requires an initializer",
      #|      ),
      #|    ),
      #|  ),
      #|  Err(InvalidBytecode(error=InvalidBytecode(site=Image, detail="FunctionId 3 is out of range"))),
      #|  Err(
      #|    InvalidBytecode(
      #|      error=InvalidBytecode(
      #|        site=Image,
      #|        detail="OwnedErased global companion must immediately precede its owner",
      #|      ),
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "decoder rejects malformed global count before host conversion" {
  let image = {
    ..malformed_minimal_image(),
    initializer: Some(malformed_function(1)),
    globals: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
    ],
  }
  let bytes = unchecked_bytecode_image_to_binary(image).to_array()
  bytes[68] = b'\xFF'
  bytes[69] = b'\xFF'
  bytes[70] = b'\xFF'
  bytes[71] = b'\xFF'
  assert_eq(
    parse_bytecode_image_binary(Bytes::from_array(bytes)),
    Err(
      ResourceLimit(
        offset=68,
        detail="instance global count exceeds implementation limit",
      ),
    ),
  )
}

///|
test "binary loader rejects malformed UTF-8 constants" {
  let malformed_utf8 = {
    ..malformed_minimal_image(),
    constants: [Bytes::from_array([b'\xFF'])],
  }
  assert_eq(
    parse_bytecode_image_binary(
      unchecked_bytecode_image_to_binary(malformed_utf8),
    ),
    Err(
      InvalidBytecode(
        error=InvalidBytecode(
          site=Image,
          detail="String constant must contain valid UTF-8",
        ),
      ),
    ),
  )
}

///|
test "binary loader rejects malformed Char constants" {
  let results = []
  for value in [-1, 0xD800, 0xDFFF, 0x110000] {
    let image = {
      ..malformed_minimal_image(),
      functions: [
        BytecodeBody({
          ..malformed_body(instructions=[ConstChar(malformed_slot(0), value)]),
          slots: [
            {
              representation: I32,
              cleanup: Trivial,
              kind: ScalarValue,
              erased_companion: None,
            },
          ],
        }),
      ],
    }
    results.push(
      parse_bytecode_image_binary(unchecked_bytecode_image_to_binary(image)),
    )
  }
  debug_inspect(
    results,
    content=(
      #|[
      #|  Err(
      #|    InvalidBytecode(
      #|      error=InvalidBytecode(
      #|        site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|        detail="Char constant -1 is not a Unicode scalar value",
      #|      ),
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      error=InvalidBytecode(
      #|        site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|        detail="Char constant 55296 is not a Unicode scalar value",
      #|      ),
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      error=InvalidBytecode(
      #|        site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|        detail="Char constant 57343 is not a Unicode scalar value",
      #|      ),
      #|    ),
      #|  ),
      #|  Err(
      #|    InvalidBytecode(
      #|      error=InvalidBytecode(
      #|        site=Instruction({ value: 1 }, { value: 0 }, 0),
      #|        detail="Char constant 1114112 is not a Unicode scalar value",
      #|      ),
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "decoder rejects malformed slot metadata" {
  let illegal_body = {
    ..malformed_body(),
    slots: [
      {
        representation: I32,
        cleanup: OwnedCallable,
        kind: CallableValue,
        erased_companion: None,
      },
    ],
  }
  let illegal_image = {
    ..malformed_minimal_image(),
    functions: [BytecodeBody(illegal_body)],
  }
  debug_inspect(
    parse_bytecode_image_binary(
      unchecked_bytecode_image_to_binary(illegal_image),
    ),
    content=(
      #|Err(
      #|  InvalidBytecode(
      #|    error=InvalidBytecode(
      #|      site=Function({ value: 1 }),
      #|      detail="illegal slot representation and cleanup combination",
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "decoder rejects malformed result ownership" {
  let caller = {
    ..malformed_body(),
    slots: [
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
    ],
    blocks: [
      {
        parameters: [],
        instructions: [
          CallDirect(
            malformed_function(2),
            None,
            [],
            [],
            Some(malformed_slot(0)),
          ),
          Release(malformed_slot(0)),
        ],
        terminator: Return(None),
      },
    ],
  }
  let scalar_result = {
    ..malformed_body(),
    slots: [
      {
        representation: I32,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
    ],
    result: Value(I32, Trivial, ScalarValue),
    blocks: [
      {
        parameters: [],
        instructions: [ConstI32(malformed_slot(0), 42)],
        terminator: Return(Some(malformed_slot(0))),
      },
    ],
  }
  let invalid = {
    ..malformed_minimal_image(),
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit },
      {
        witnesses: [],
        parameters: [],
        result: Value(I32, Trivial, ScalarValue),
      },
    ],
    functions: [BytecodeBody(caller), BytecodeBody(scalar_result)],
  }
  assert_eq(
    parse_bytecode_image_binary(unchecked_bytecode_image_to_binary(invalid)),
    Err(
      InvalidBytecode(
        error=InvalidBytecode(
          site=Instruction(malformed_function(1), { value: 0 }, 0),
          detail="call result ABI does not match destination slot",
        ),
      ),
    ),
  )
}
