///|
fn compile_test_physical_program(
  source : String,
  library_sources? : Array[String] = [],
) -> @physical.PhysicalProgram raise {
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
  match @physical_lowering.lower_executable_program_to_physical(executable) {
    Ok(image) => image.image()
    Err(error) => fail("physical lowering failed: \{Repr(error)}")
  }
}

///|
test "compiler removes discarded empty-effect Byte and Bytes operations" {
  let physical_program = compile_test_physical_program(
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
    physical_program,
    content=(
      #|{
      #|  entry: { value: 1 },
      #|  initializer: None,
      #|  callable_abis: [{ witnesses: [], parameters: [], result: Unit }],
      #|  data_family_count: 0,
      #|  functions: [
      #|    PhysicalBody(
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
  let physical_program = compile_test_physical_program(
    (
      #|module Test
      #|
      #|let byte_to_i64 : (Byte) -> I64 = builtin("%byte_to_i64")
      #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
      #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_length : (Bytes) -> I64 = builtin("%bytes_length")
      #|let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|let bytes_set : (Bytes, I64, Byte) -> Bytes = builtin("%bytes_set")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe")
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
    physical_program,
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
      #|    PhysicalBody(
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
      #|        module_name: "lane.test",
      #|        field_name: "lane.test.observe",
      #|        parameters: [Direct(I64)],
      #|        result: Unit,
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
test "compiler scalar-replaces Byte and Bytes fields while preserving closures and globals" {
  let physical_program = compile_test_physical_program(
    (
      #|module Test
      #|
      #|let byte_to_i64 : (Byte) -> I64 = builtin("%byte_to_i64")
      #|let i64_to_byte : (I64) -> Byte = builtin("%i64_to_byte")
      #|let bytes_make : (I64, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_get : (Bytes, I64) -> Byte = builtin("%bytes_get")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe")
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
    physical_program,
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
      #|      parameters: [{ representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue }],
      #|      result: Value(I32, Trivial, ScalarValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [{ representation: I64, cleanup: Trivial, kind: ScalarValue }],
      #|      result: Unit,
      #|    },
      #|  ],
      #|  data_family_count: 0,
      #|  functions: [
      #|    PhysicalBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I32,
      #|            cleanup: Trivial,
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
      #|              BorrowGlobal({ value: 0 }, { value: 1 }),
      #|              BorrowGlobal({ value: 0 }, { value: 1 }),
      #|              RetainCopy({ value: 3 }, { value: 0 }),
      #|              CallDirect({ value: 5 }, None, [], [{ value: 3 }], Some({ value: 1 })),
      #|              ByteToI64({ value: 2 }, { value: 1 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 6 }, None, [], [{ value: 2 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    PhysicalBody(
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
      #|    PhysicalBody(
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
      #|    PhysicalBody(
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
      #|    PhysicalBody(
      #|      {
      #|        slots: [
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
      #|            representation: I32,
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
      #|              ConstI64({ value: 1 }, 0),
      #|              I64ToByte({ value: 2 }, { value: 1 }),
      #|              ByteToI64({ value: 1 }, { value: 2 }),
      #|              ByteSequenceGet({ value: 2 }, { value: 0 }, { value: 1 }),
      #|              Release({ value: 0 }),
      #|            ],
      #|            terminator: Return(Some({ value: 2 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        module_name: "lane.test",
      #|        field_name: "lane.test.observe",
      #|        parameters: [Direct(I64)],
      #|        result: Unit,
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
      #|  layouts: [ByteSequence],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}
