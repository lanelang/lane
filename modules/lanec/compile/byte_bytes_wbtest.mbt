///|
test "compiler preserves Byte and Bytes through executable lowering" {
  let compiled = compile_modules(
    (
      #|module Test
      #|
      #|let byte_to_int : (Byte) -> Int = builtin("%byte_to_int")
      #|let int_to_byte : (Int) -> Byte = builtin("%int_to_byte")
      #|let bytes_make : (Int, Byte) -> Bytes = builtin("%bytes_make")
      #|let bytes_length : (Bytes) -> Int = builtin("%bytes_length")
      #|let bytes_get : (Bytes, Int) -> Byte = builtin("%bytes_get")
      #|let bytes_set : (Bytes, Int, Byte) -> Bytes = builtin("%bytes_set")
      #|let observe : (Int) -> Unit ! Io = extern("lane.test.observe")
      #|
      #|fn[T] identity(value : T) -> T {
      #|  value
      #|}
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  let fill = identity(int_to_byte(255))
      #|  let original = identity(bytes_make(2, fill))
      #|  let updated = bytes_set(original, 1, int_to_byte(0))
      #|  observe(bytes_length(updated))
      #|  observe(byte_to_int(bytes_get(updated, 1)))
      #|}
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) else {
    fail("expected compiled modules")
  }
  let linked = link_modules(modules)
  assert_eq(linked.diagnostics, [])
  guard linked.program is Some(program) else {
    fail("expected linked Buslane program")
  }
  guard program.entries is [entry] else { fail("expected one public entry") }
  let executable = match @executable.elaborate(program, entry) {
    Ok(executable) => executable
    Err(error) => fail("executable elaboration failed: \{Repr(error)}")
  }
  let artifact = match
    @artifact_binary.executable_to_loisvm_artifact(executable) {
    Ok(artifact) => artifact
    Err(error) => fail("LoisVM lowering failed: \{Repr(error)}")
  }
  debug_inspect(
    artifact.bytecode,
    content=(
      #|{
      #|  entry: { value: 2 },
      #|  initializer: None,
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            erased_companion: Some({ value: 0 }),
      #|          },
      #|        ],
      #|        inputs: {
      #|          environment: None,
      #|          witnesses: [{ value: 0 }],
      #|          user_parameters: [{ value: 1 }],
      #|        },
      #|        result: I64,
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
      #|          { representation: I64, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            erased_companion: Some({ value: 3 }),
      #|          },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            erased_companion: Some({ value: 5 }),
      #|          },
      #|          { representation: I32, cleanup: OwnedRef, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            erased_companion: Some({ value: 8 }),
      #|          },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          {
      #|            representation: I64,
      #|            cleanup: OwnedErased,
      #|            erased_companion: Some({ value: 10 }),
      #|          },
      #|          { representation: I32, cleanup: OwnedRef, erased_companion: None },
      #|          { representation: I32, cleanup: OwnedRef, erased_companion: None },
      #|          { representation: I64, cleanup: Trivial, erased_companion: None },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstInt({ value: 0 }, 255),
      #|              IntToByte({ value: 1 }, { value: 0 }),
      #|              ConstLayout({ value: 2 }, { value: 1 }),
      #|              EraseI32({ value: 4 }, { value: 1 }),
      #|              CallDirect(
      #|                { value: 1 },
      #|                None,
      #|                [{ value: 2 }],
      #|                [{ value: 4 }],
      #|                Some({ value: 6 }),
      #|              ),
      #|              UneraseI32({ value: 1 }, { value: 6 }),
      #|              ConstInt({ value: 0 }, 2),
      #|              BytesMake({ value: 7 }, { value: 0 }, { value: 1 }),
      #|              ConstLayout({ value: 1 }, { value: 2 }),
      #|              EraseI32({ value: 9 }, { value: 7 }),
      #|              CallDirect(
      #|                { value: 1 },
      #|                None,
      #|                [{ value: 1 }],
      #|                [{ value: 9 }],
      #|                Some({ value: 11 }),
      #|              ),
      #|              UneraseI32({ value: 12 }, { value: 11 }),
      #|              ConstInt({ value: 0 }, 0),
      #|              IntToByte({ value: 1 }, { value: 0 }),
      #|              ConstInt({ value: 0 }, 1),
      #|              BytesSet({ value: 13 }, { value: 12 }, { value: 0 }, { value: 1 }),
      #|              BytesLength({ value: 14 }, { value: 13 }),
      #|              CallDirect({ value: 3 }, None, [], [{ value: 14 }], None),
      #|              BytesGet({ value: 1 }, { value: 13 }, { value: 0 }),
      #|              ByteToInt({ value: 0 }, { value: 1 }),
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
      #|        parameters: [Int],
      #|        result: Unit,
      #|        symbol: "lane.test.observe",
      #|      },
      #|    ),
      #|  ],
      #|  globals: [],
      #|  layouts: [Byte, Bytes],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}
