///|
fn compile_test_loisvm_image(
  source : String,
  library_sources? : Array[String] = [],
) -> @bytecode.BytecodeImage raise {
  let compiled = compile_modules_for_test(source, library_sources)
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
  let executable = match
    @executable.elaborate(
      program,
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[Io, Panic],
        supports_external_effects=true,
      ),
    ) {
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
      #|  entry: { value: 1 },
      #|  initializer: None,
      #|  callable_abis: [
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
      #|              ConstI64({ value: 0 }, 2),
      #|              ByteSequenceMake({ value: 2 }, { value: 0 }, { value: 1 }),
      #|              ConstI64({ value: 0 }, 0),
      #|              I64ToByte({ value: 1 }, { value: 0 }),
      #|              ConstI64({ value: 0 }, 1),
      #|              ByteSequenceSet(
      #|                { value: 3 },
      #|                { value: 2 },
      #|                { value: 0 },
      #|                { value: 1 },
      #|              ),
      #|              ByteSequenceLength({ value: 4 }, { value: 3 }),
      #|              CallDirect({ value: 2 }, None, [], [{ value: 4 }], None),
      #|              ByteSequenceGet({ value: 1 }, { value: 3 }, { value: 0 }),
      #|              ByteToI64({ value: 0 }, { value: 1 }),
      #|              Release({ value: 3 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
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
      #|  layouts: [ByteSequence],
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
      #|  entry: { value: 1 },
      #|  initializer: Some({ value: 4 }),
      #|  callable_abis: [
      #|    { witnesses: [], parameters: [], result: Unit },
      #|    {
      #|      witnesses: [],
      #|      parameters: [],
      #|      result: Value(I32, Trivial, ScalarValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [],
      #|      result: Value(I32, OwnedRef, ByteSequenceValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [
      #|        {
      #|          representation: I32,
      #|          cleanup: OwnedRef,
      #|          kind: DataValue({ value: 1 }),
      #|        },
      #|      ],
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
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 1 }),
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: I64,
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
      #|              BorrowGlobal({ value: 0 }, { value: 0 }),
      #|              BorrowGlobal({ value: 1 }, { value: 1 }),
      #|              RetainCopy({ value: 6 }, { value: 1 }),
      #|              MakeData(
      #|                { value: 2 },
      #|                { value: 0 },
      #|                Immediate({ value: 1 }),
      #|                [],
      #|                [{ value: 0 }, { value: 6 }],
      #|              ),
      #|              BorrowField(
      #|                { value: 0 },
      #|                { value: 2 },
      #|                0,
      #|                { value_destination: { value: 0 }, witness_destination: None },
      #|              ),
      #|              BorrowField(
      #|                { value: 0 },
      #|                { value: 2 },
      #|                1,
      #|                { value_destination: { value: 1 }, witness_destination: None },
      #|              ),
      #|              BorrowField(
      #|                { value: 0 },
      #|                { value: 2 },
      #|                0,
      #|                { value_destination: { value: 3 }, witness_destination: None },
      #|              ),
      #|              BorrowField(
      #|                { value: 0 },
      #|                { value: 2 },
      #|                1,
      #|                { value_destination: { value: 1 }, witness_destination: None },
      #|              ),
      #|              RetainCopy({ value: 6 }, { value: 1 }),
      #|              MakeData(
      #|                { value: 4 },
      #|                { value: 1 },
      #|                Immediate({ value: 2 }),
      #|                [],
      #|                [{ value: 0 }, { value: 6 }],
      #|              ),
      #|              CallDirect({ value: 5 }, None, [], [{ value: 4 }], Some({ value: 0 })),
      #|              ByteToI64({ value: 5 }, { value: 0 }),
      #|              Release({ value: 2 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 6 }, None, [], [{ value: 5 }]),
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
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Value(I32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [ConstI64({ value: 0 }, 7), I64ToByte({ value: 1 }, { value: 0 })],
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
      #|            cleanup: OwnedRef,
      #|            kind: ByteSequenceValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Value(I32, OwnedRef, ByteSequenceValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstI64({ value: 0 }, 1),
      #|              BorrowGlobal({ value: 1 }, { value: 0 }),
      #|              ByteSequenceMake({ value: 2 }, { value: 0 }, { value: 1 }),
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
      #|              CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      #|              InitGlobal({ value: 0 }, { value: 0 }),
      #|              CallDirect({ value: 3 }, None, [], [], Some({ value: 1 })),
      #|              InitGlobal({ value: 1 }, { value: 1 }),
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
      #|            kind: DataValue({ value: 1 }),
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
      #|        inputs: { environment: None, witnesses: [], user_parameters: [{ value: 0 }] },
      #|        result: Value(I32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              BorrowField(
      #|                { value: 1 },
      #|                { value: 0 },
      #|                0,
      #|                { value_destination: { value: 1 }, witness_destination: None },
      #|              ),
      #|              BorrowField(
      #|                { value: 1 },
      #|                { value: 0 },
      #|                1,
      #|                { value_destination: { value: 2 }, witness_destination: None },
      #|              ),
      #|              ConstI64({ value: 3 }, 0),
      #|              I64ToByte({ value: 1 }, { value: 3 }),
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
      #|    Data({ value: 0 }),
      #|    Data({ value: 1 }),
      #|    Environment({ value: 2 }),
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
      #|    Environment(
      #|      {
      #|        stored_witness_count: 0,
      #|        members: [
      #|          {
      #|            representation: I32,
      #|            cleanup: OwnedRef,
      #|            kind: DataValue({ value: 1 }),
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
