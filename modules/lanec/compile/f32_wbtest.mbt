///|
test "compiler lowers F32 literals and intrinsics to LoisVM" {
  let bytecode = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|let f32_add : (F32, F32) -> F32 = builtin("%f32_add")
      #|let f32_inf : F32 = builtin("%f32_inf")
      #|let f32_ninf : F32 = builtin("%f32_ninf")
      #|let f32_nan : F32 = builtin("%f32_nan")
      #|let observe : (F32) -> Unit ! Io = extern("lane.test.observe_f32")
      #|
      #|fn[T] identity(value : T) -> T {
      #|  value
      #|}
      #|
      #|fn nonzero(value : F32) -> F32 {
      #|  match value {
      #|    0.0f32 => 1.0f32
      #|    _ => value
      #|  }
      #|}
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  observe(f32_inf)
      #|  observe(f32_ninf)
      #|  observe(f32_nan)
      #|  observe(f32_add(nonzero(identity[F32](1.5f32)), 2.25f32))
      #|}
    ),
  )
  debug_inspect(
    bytecode,
    content=(
      #|{
      #|  entry: { value: 1 },
      #|  initializer: Some({ value: 5 }),
      #|  callable_abis: [
      #|    { witnesses: [], parameters: [], result: Unit },
      #|    {
      #|      witnesses: [],
      #|      parameters: [],
      #|      result: Value(F32, Trivial, ScalarValue),
      #|    },
      #|    {
      #|      witnesses: [],
      #|      parameters: [{ representation: F32, cleanup: Trivial, kind: ScalarValue }],
      #|      result: Unit,
      #|    },
      #|  ],
      #|  data_family_count: 0,
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: F32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: F32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|          {
      #|            representation: F32,
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
      #|              BorrowGlobal({ value: 0 }, { value: 0 }),
      #|              CallDirect({ value: 6 }, None, [], [{ value: 0 }], None),
      #|              BorrowGlobal({ value: 0 }, { value: 1 }),
      #|              CallDirect({ value: 6 }, None, [], [{ value: 0 }], None),
      #|              BorrowGlobal({ value: 0 }, { value: 2 }),
      #|              CallDirect({ value: 6 }, None, [], [{ value: 0 }], None),
      #|              ConstF32({ value: 0 }, 1069547520),
      #|              ConstF32({ value: 1 }, 1074790400),
      #|              F32Add({ value: 2 }, { value: 0 }, { value: 1 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 6 }, None, [], [{ value: 2 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: F32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Value(F32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [ConstF32({ value: 0 }, 2139095040)],
      #|            terminator: Return(Some({ value: 0 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: F32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Value(F32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [ConstF32({ value: 0 }, -8388608)],
      #|            terminator: Return(Some({ value: 0 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: F32,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Value(F32, Trivial, ScalarValue),
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [ConstF32({ value: 0 }, 2143289344)],
      #|            terminator: Return(Some({ value: 0 })),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: F32,
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
      #|              CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
      #|              InitGlobal({ value: 0 }, { value: 0 }),
      #|              CallDirect({ value: 3 }, None, [], [], Some({ value: 0 })),
      #|              InitGlobal({ value: 1 }, { value: 0 }),
      #|              CallDirect({ value: 4 }, None, [], [], Some({ value: 0 })),
      #|              InitGlobal({ value: 2 }, { value: 0 }),
      #|            ],
      #|            terminator: Return(None),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        abi_major: 1,
      #|        parameters: [F32],
      #|        result: Unit,
      #|        symbol: "lane.test.observe_f32",
      #|      },
      #|    ),
      #|  ],
      #|  globals: [
      #|    {
      #|      representation: F32,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: F32,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|    {
      #|      representation: F32,
      #|      cleanup: Trivial,
      #|      kind: ScalarValue,
      #|      erased_companion: None,
      #|    },
      #|  ],
      #|  layouts: [],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}

///|
test "F32 module interface and object artifacts roundtrip" {
  let compiled = compile_modules_for_test(
    (
      #|module Test
      #|
      #|pub fn identity(value : F32) -> F32 {
      #|  value
      #|}
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) else {
    fail("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Test")
    is Some(module_) else {
    fail("expected Test module")
  }
  let artifact = module_.to_artifact()
  let interface = match
    @artifact.parse_module_interface_artifact_binary(
      @artifact.module_interface_artifact_to_binary(artifact.interface),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let object = match
    @artifact.parse_module_object_artifact_binary(
      @artifact.module_object_artifact_to_binary(artifact.object),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(interface, artifact.interface)
  assert_eq(object, artifact.object)
}
