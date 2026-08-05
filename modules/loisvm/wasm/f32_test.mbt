///|
test "F32 arithmetic and conversions agree across interpreter and Wasm backends" {
  let f32 = wasm_bytes_trivial_slot(F32)
  let i32 = wasm_bytes_trivial_slot(I32)
  let i64 = wasm_bytes_trivial_slot(I64)
  let f64 = wasm_bytes_trivial_slot(F64)
  let edge = fn(target : Int) -> @bytecode.Edge {
    { target: { value: target }, arguments: [] }
  }
  let body = wasm_bytes_body([f32, f32, f32, i32, i64, i64, f64, f64], [
    {
      parameters: [],
      instructions: [
        ConstF32({ value: 0 }, Float::from_double(1.5).reinterpret_as_int()),
        ConstF32({ value: 1 }, Float::from_double(2.25).reinterpret_as_int()),
        F32Add({ value: 2 }, { value: 0 }, { value: 1 }),
        ConstF32({ value: 0 }, Float::from_double(3.75).reinterpret_as_int()),
        F32Eq({ value: 3 }, { value: 2 }, { value: 0 }),
      ],
      terminator: BranchBool({ value: 3 }, edge(1), edge(3)),
    },
    {
      parameters: [],
      instructions: [
        ConstI64({ value: 4 }, 42L),
        I64ToF32({ value: 0 }, { value: 4 }),
        F32ToI64({ value: 4 }, { value: 0 }),
        ConstI64({ value: 5 }, 42L),
        I64Eq({ value: 3 }, { value: 4 }, { value: 5 }),
      ],
      terminator: BranchBool({ value: 3 }, edge(2), edge(3)),
    },
    {
      parameters: [],
      instructions: [
        F32ToF64({ value: 6 }, { value: 0 }),
        ConstF64({ value: 7 }, 42.0.reinterpret_as_int64()),
        F64Eq({ value: 3 }, { value: 6 }, { value: 7 }),
      ],
      terminator: BranchBool({ value: 3 }, edge(4), edge(3)),
    },
    { parameters: [], instructions: [], terminator: Unreachable },
    { parameters: [], instructions: [], terminator: Return(None) },
  ])
  assert_bytes_backends(body, Completed)
}

///|
fn f32_echo_registry() -> @loisvm_runtime.RuntimeRegistry {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.echo_f32",
      abi_major=1,
      parameters=[F32],
      result=F32,
      invoke=fn(_context, arguments) {
        guard arguments is [F32(value)] else {
          abort("expected one F32 host argument")
        }
        F32(value)
      },
    ),
  )
  registry
}

///|
test "F32 host ABI agrees across interpreter and Wasm backends" {
  let f32 = wasm_bytes_trivial_slot(F32)
  let i32 = wasm_bytes_trivial_slot(I32)
  let expected = Float::from_double(1.5)
  let body = wasm_bytes_body([f32, f32, i32], [
    {
      parameters: [],
      instructions: [
        ConstF32({ value: 0 }, expected.reinterpret_as_int()),
        CallDirect({ value: 2 }, None, [], [{ value: 0 }], Some({ value: 1 })),
        ConstF32({ value: 0 }, expected.reinterpret_as_int()),
        F32Eq({ value: 2 }, { value: 0 }, { value: 1 }),
      ],
      terminator: BranchBool(
        { value: 2 },
        { target: { value: 1 }, arguments: [] },
        { target: { value: 2 }, arguments: [] },
      ),
    },
    { parameters: [], instructions: [], terminator: Return(None) },
    { parameters: [], instructions: [], terminator: Unreachable },
  ])
  let image = {
    ..wasm_bytes_image(body),
    callable_abis: [
      { witness_count: 0, parameters: [], result: Unit },
      {
        witness_count: 0,
        parameters: [{ representation: F32, cleanup: Trivial }],
        result: Value(F32, Trivial),
      },
    ],
    functions: [
      BytecodeBody(body),
      RuntimeImport({
        abi_major: 1,
        parameters: [F32],
        result: F32,
        symbol: "lane.test.echo_f32",
      }),
    ],
  }
  let direct = match @loisvm_interp.load(image, f32_echo_registry()) {
    Ok(loaded) => loaded.new_instance().execute()
    Err(error) => fail("direct interpreter load failed: \{Repr(error)}")
  }
  let execute_wasm = fn(mode : ExecutionMode) {
    let loaded = match load(image, f32_echo_registry(), mode~) {
      Ok(value) => value
      Err(error) => abort("Wasm load failed: \{Repr(error)}")
    }
    match loaded.new_instance() {
      Ok(instance) => instance.execute()
      Err(error) => Err(error)
    }
  }
  assert_eq(
    (direct, execute_wasm(Interpreter), execute_wasm(Jit)),
    (Ok(()), Ok(()), Ok(())),
  )
}
