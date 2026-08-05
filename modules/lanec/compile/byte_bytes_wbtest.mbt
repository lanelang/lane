///|
fn compile_test_loisvm_image(source : String) -> @bytecode.BytecodeImage raise {
  let compiled = compile_modules_for_test(source, [])
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) else {
    fail("expected compiled modules")
  }
  let linked = link_modules_for_test(modules)
  assert_eq(linked.diagnostics, [])
  guard linked.program is Some(program) else {
    fail("expected linked Buslane program")
  }
  guard program.entries is [entry] else { fail("expected one public entry") }
  let executable = match @executable.elaborate(program, entry) {
    Ok(executable) => executable
    Err(error) => fail("executable elaboration failed: \{Repr(error)}")
  }
  let artifact = match @artifact.executable_to_loisvm_artifact(executable) {
    Ok(artifact) => artifact
    Err(error) => fail("LoisVM lowering failed: \{Repr(error)}")
  }
  artifact.bytecode
}

///|
test "compiler removes discarded empty-effect Byte and Bytes operations" {
  let bytecode = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
      #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|
      #|pub fn answer() -> Unit {
      #|  let _ = bytes_get(bytes_make(0, i64_to_byte(0)), 0)
      #|  ()
      #|}
    ),
  )
  debug_inspect(
    bytecode,
    content=(
      #|{
      #|  entry: { value: 1 },
      #|  initializer: None,
      #|  callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
      #|  data_family_count: 0,
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
      #|      },
      #|    ),
      #|  ],
      #|  globals: [],
      #|  layouts: [],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}

///|
test "compiler preserves Byte and Bytes through executable lowering" {
  let bytecode = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|let byte_to_i64 : (Byte) -> I64 = builtin("%byte_to_i64")
      #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
      #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_length : (Bytes) -> I64 = builtin("%bytes_length")
      #|let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|let bytes_set : (Bytes, I64, Byte) -> Bytes = builtin("%bytes_set")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe")
      #|
      #|fn[T] identity(value : T) -> T {
      #|  value
      #|}
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  let fill = identity(i64_to_byte(255))
      #|  let original = identity(bytes_make(2, fill))
      #|  let updated = bytes_set(original, 1, i64_to_byte(0))
      #|  observe(bytes_length(updated))
      #|  observe(byte_to_i64(bytes_get(updated, 1)))
      #|}
    ),
  )
  debug_inspect(
    bytecode,
    content=(
      #|{
      #|  entry: { value: 2 },
      #|  initializer: None,
      #|  callable_abis: [
      #|    {
      #|      witnesses: [{ representation: I32, cleanup: Trivial, kind: LayoutValue }],
      #|      parameters: [{ representation: I64, cleanup: OwnedErased, kind: ErasedValue }],
      #|      result: Value(I64, OwnedErased, ErasedValue),
      #|    },
      #|    { witnesses: [], parameters: [], result: Unit },
      #|    {
      #|      witnesses: [],
      #|      parameters: [{ representation: I64, cleanup: Trivial, kind: ScalarValue }],
      #|      result: Unit,
      #|    },
      #|  ],
      #|  data_family_count: 0,
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: LayoutValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            kind: ErasedValue,
      #|            erased_companion: Some({ value: 0 }),
      #|          },
      #|        ],
      #|        inputs: {
      #|          environment: None,
      #|          witnesses: [{ value: 0 }],
      #|          user_parameters: [{ value: 1 }],
      #|        },
      #|        result: Value(I64, OwnedErased, ErasedValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [],
      #|            terminator: Return(Some({ value: 1 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I64,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: LayoutValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: LayoutValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            kind: ErasedValue,
      #|            erased_companion: Some({ value: 3 }),
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: LayoutValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            kind: ErasedValue,
      #|            erased_companion: Some({ value: 5 }),
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: LayoutValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            kind: ErasedValue,
      #|            erased_companion: Some({ value: 8 }),
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: LayoutValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            kind: ErasedValue,
      #|            erased_companion: Some({ value: 10 }),
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstI64({ value: 0 }, 255),
      #|              I64ToByte({ value: 1 }, { value: 0 }),
      #|              ConstLayout({ value: 2 }, { value: 1 }),
      #|              ConstLayout({ value: 3 }, { value: 1 }),
      #|              EraseI32({ value: 4 }, { value: 1 }),
      #|              ConstLayout({ value: 5 }, { value: 1 }),
      #|              CallDirect(
      #|                { value: 1 },
      #|                None,
      #|                [{ value: 2 }],
      #|                [{ value: 4 }],
      #|                Some({ value: 6 }),
      #|              ),
      #|              UneraseI32({ value: 1 }, { value: 6 }),
      #|              ConstI64({ value: 0 }, 2),
      #|              ByteSequenceMake({ value: 7 }, { value: 0 }, { value: 1 }),
      #|              ConstLayout({ value: 2 }, { value: 2 }),
      #|              ConstLayout({ value: 8 }, { value: 2 }),
      #|              EraseI32({ value: 9 }, { value: 7 }),
      #|              ConstLayout({ value: 10 }, { value: 2 }),
      #|              CallDirect(
      #|                { value: 1 },
      #|                None,
      #|                [{ value: 2 }],
      #|                [{ value: 9 }],
      #|                Some({ value: 11 }),
      #|              ),
      #|              UneraseI32({ value: 12 }, { value: 11 }),
      #|              ConstI64({ value: 0 }, 0),
      #|              I64ToByte({ value: 1 }, { value: 0 }),
      #|              ConstI64({ value: 0 }, 1),
      #|              ByteSequenceSet(
      #|                { value: 13 },
      #|                { value: 12 },
      #|                { value: 0 },
      #|                { value: 1 },
      #|              ),
      #|              ByteSequenceLength({ value: 14 }, { value: 13 }),
      #|              CallDirect({ value: 3 }, None, [], [{ value: 14 }], None),
      #|              ByteSequenceGet({ value: 1 }, { value: 13 }, { value: 0 }),
      #|              ByteToI64({ value: 0 }, { value: 1 }),
      #|              Release({ value: 13 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 3 }, None, [], [{ value: 0 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        abi_major: 1,
      #|        parameters: [I64],
      #|        result: Unit,
      #|        symbol: "lane.test.observe",
      #|      },
      #|    ),
      #|  ],
      #|  globals: [],
      #|  layouts: [Byte, ByteSequence],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}

///|
test "compiler preserves Byte and Bytes in fields enum payloads closures and globals" {
  let bytecode = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|let byte_to_i64 : (Byte) -> I64 = builtin("%byte_to_i64")
      #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
      #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe")
      #|
      #|struct Stored {
      #|  byte : Byte
      #|  bytes : Bytes
      #|}
      #|
      #|enum Payload {
      #|  values(Byte, Bytes)
      #|}
      #|
      #|let global_byte : Byte = i64_to_byte(7)
      #|let global_bytes : Bytes = bytes_make(1, global_byte)
      #|
      #|fn capture(value : Bytes, index : Byte) -> () -> Byte {
      #|  fn() { bytes_get(value, byte_to_i64(index)) }
      #|}
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  let stored = Stored::{ byte: global_byte, bytes: global_bytes }
      #|  let payload = Payload::values(stored.byte, stored.bytes)
      #|  let reader = capture(
      #|    match payload {
      #|      values(_, bytes) => bytes
      #|    },
      #|    i64_to_byte(0),
      #|  )
      #|  observe(byte_to_i64(reader()))
      #|}
    ),
  )
  debug_inspect(
    bytecode,
    content=(
      #|{
      #|  entry: { value: 4 },
      #|  initializer: Some({ value: 5 }),
      #|  callable_abis: [
      #|    {
      #|      witnesses: [],
      #|      parameters: [
      #|        {
      #|          representation: I32,
      #|          cleanup: OwnedRef,
      #|          kind: DataValue({ value: 0 }),
      #|        },
      #|      ],
      #|      result: Value(I32, Trivial, ScalarValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [
      #|        {
      #|          representation: I32,
      #|          cleanup: OwnedRef,
      #|          kind: DataValue({ value: 0 }),
      #|        },
      #|      ],
      #|      result: Value(I32, OwnedRef, ByteSequenceValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [
      #|        { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
      #|        { representation: I32, cleanup: Trivial, kind: ScalarValue },
      #|      ],
      #|      result: Value(I64, OwnedCallable, CallableValue),
      #|    },
      #|    { witnesses: [], parameters: [], result: Unit },
      #|    {
      #|      witnesses: [],
      #|      parameters: [],
      #|      result: Value(I32, Trivial, ScalarValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [{ representation: I64, cleanup: Trivial, kind: ScalarValue }],
      #|      result: Unit,
      #|    },
      #|  ],
      #|  data_family_count: 2,
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 0 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [{ value: 0 }] },
      #|        result: Value(I32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              BorrowField(
      #|                { value: 0 },
      #|                { value: 0 },
      #|                0,
      #|                { value_destination: { value: 1 }, witness_destination: None },
      #|              ),
      #|              BorrowField(
      #|                { value: 0 },
      #|                { value: 0 },
      #|                1,
      #|                { value_destination: { value: 2 }, witness_destination: None },
      #|              ),
      #|              Release({ value: 0 }),
      #|            ],
      #|            terminator: Return(Some({ value: 1 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 0 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [{ value: 0 }] },
      #|        result: Value(I32, OwnedRef, ByteSequenceValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConsumeFields(
      #|                { value: 0 },
      #|                { value: 0 },
      #|                [
      #|                  {
      #|                    member_index: 0,
      #|                    result: { value_destination: { value: 1 }, witness_destination: None },
      #|                  },
      #|                  {
      #|                    member_index: 1,
      #|                    result: { value_destination: { value: 2 }, witness_destination: None },
      #|                  },
      #|                ],
      #|              ),
      #|            ],
      #|            terminator: Return(Some({ value: 2 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: EnvironmentValue({ value: 1 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedCallable,
      #|            kind: CallableValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: {
      #|          environment: None,
      #|          witnesses: [],
      #|          user_parameters: [{ value: 0 }, { value: 1 }],
      #|        },
      #|        result: Value(I64, OwnedCallable, CallableValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              MakeEnv(
      #|                { value: 2 },
      #|                { value: 1 },
      #|                Immediate({ value: 1 }),
      #|                [],
      #|                [{ value: 1 }, { value: 0 }],
      #|              ),
      #|              MakeClosure({ value: 3 }, { value: 6 }, { value: 2 }),
      #|            ],
      #|            terminator: Return(Some({ value: 3 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 0 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 1 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedCallable,
      #|            kind: CallableValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 0 }),
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              BorrowGlobal({ value: 0 }, { value: 0 }),
      #|              BorrowGlobal({ value: 1 }, { value: 1 }),
      #|              RetainCopy({ value: 8 }, { value: 1 }),
      #|              MakeData(
      #|                { value: 2 },
      #|                { value: 0 },
      #|                Immediate({ value: 2 }),
      #|                [],
      #|                [{ value: 0 }, { value: 8 }],
      #|              ),
      #|              RetainCopy({ value: 9 }, { value: 2 }),
      #|              CallDirect({ value: 1 }, None, [], [{ value: 9 }], Some({ value: 0 })),
      #|              CallDirect({ value: 2 }, None, [], [{ value: 2 }], Some({ value: 3 })),
      #|              MakeData(
      #|                { value: 4 },
      #|                { value: 2 },
      #|                Immediate({ value: 3 }),
      #|                [],
      #|                [{ value: 0 }, { value: 3 }],
      #|              ),
      #|              ConsumeFields(
      #|                { value: 2 },
      #|                { value: 4 },
      #|                [
      #|                  {
      #|                    member_index: 0,
      #|                    result: { value_destination: { value: 0 }, witness_destination: None },
      #|                  },
      #|                  {
      #|                    member_index: 1,
      #|                    result: { value_destination: { value: 5 }, witness_destination: None },
      #|                  },
      #|                ],
      #|              ),
      #|              ConstI64({ value: 6 }, 0),
      #|              I64ToByte({ value: 0 }, { value: 6 }),
      #|              CallDirect(
      #|                { value: 3 },
      #|                None,
      #|                [],
      #|                [{ value: 5 }, { value: 0 }],
      #|                Some({ value: 7 }),
      #|              ),
      #|              CallValue({ value: 7 }, { value: 4 }, [], [], Some({ value: 0 })),
      #|              ByteToI64({ value: 6 }, { value: 0 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 7 }, None, [], [{ value: 6 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I64,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstI64({ value: 0 }, 7),
      #|              I64ToByte({ value: 1 }, { value: 0 }),
      #|              InitGlobal({ value: 0 }, { value: 1 }),
      #|              ConstI64({ value: 0 }, 1),
      #|              BorrowGlobal({ value: 1 }, { value: 0 }),
      #|              ByteSequenceMake({ value: 2 }, { value: 0 }, { value: 1 }),
      #|              InitGlobal({ value: 1 }, { value: 2 }),
      #|            ],
      #|            terminator: Return(None),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: EnvironmentValue({ value: 1 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: {
      #|          environment: Some({ value: 0 }),
      #|          witnesses: [],
      #|          user_parameters: [],
      #|        },
      #|        result: Value(I32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              BorrowCapture(
      #|                { value: 1 },
      #|                { value: 0 },
      #|                0,
      #|                { value_destination: { value: 1 }, witness_destination: None },
      #|              ),
      #|              BorrowCapture(
      #|                { value: 1 },
      #|                { value: 0 },
      #|                1,
      #|                { value_destination: { value: 2 }, witness_destination: None },
      #|              ),
      #|              ByteToI64({ value: 3 }, { value: 1 }),
      #|              ByteSequenceGet({ value: 1 }, { value: 2 }, { value: 3 }),
      #|              Release({ value: 0 }),
      #|            ],
      #|            terminator: Return(Some({ value: 1 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        abi_major: 1,
      #|        parameters: [I64],
      #|        result: Unit,
      #|        symbol: "lane.test.observe",
      #|      },
      #|    ),
      #|  ],
      #|  globals: [
      #|    {
      #|      representation: I32,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: I32,
      #|      cleanup: OwnedRef,
      #|      kind: ByteSequenceValue,
      #|      erased_companion: None,
      #|    },
      #|  ],
      #|  layouts: [
      #|    Environment({ value: 1 }),
      #|    Data({ value: 0 }),
      #|    Data({ value: 2 }),
      #|    ByteSequence,
      #|  ],
      #|  object_shapes: [
      #|    Data(
      #|      {
      #|        family: { value: 0 },
      #|        constructor_tag: 0,
      #|        stored_witness_count: 0,
      #|        members: [
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            witness_ordinal: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            witness_ordinal: None,
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    Environment(
      #|      {
      #|        stored_witness_count: 0,
      #|        members: [
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            witness_ordinal: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            witness_ordinal: None,
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    Data(
      #|      {
      #|        family: { value: 1 },
      #|        constructor_tag: 0,
      #|        stored_witness_count: 0,
      #|        members: [
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            witness_ordinal: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            witness_ordinal: None,
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|  constants: [],
      #|}
    ),
  )
}
