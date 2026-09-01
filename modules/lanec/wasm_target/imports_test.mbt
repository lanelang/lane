///|
fn direct_import_test_image() -> @physical.PhysicalProgram {
  let contract : @wasm_abi.ImportContract = {
    module_name: "lane.test",
    field_name: "observe_i64",
    parameters: [Direct(I64)],
    result: Unit,
  }
  let body : @physical.FunctionBody = {
    slots: [
      {
        representation: I64,
        cleanup: Trivial,
        kind: ScalarValue,
        erased_companion: None,
      },
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, 42L),
          CallDirect({ value: 2, }, None, [], [{ value: 0, }], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  {
    entry: { value: 1, },
    initializer: None,
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      @physical.runtime_import_callable_abi(contract),
    ],
    data_family_count: 0,
    functions: [PhysicalBody(body), RuntimeImport(contract)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
test "core Wasm host imports execute under both engines" {
  for mode in [@lane_wasm_runtime.ExecutionMode::Jit, Interpreter] {
    let mut observed = 0L
    let configure : (@wasmoon_runtime.Linker) -> Unit raise @wasmoon_runtime.RuntimeError = linker => {
      linker.add_host_func(
        "lane.test",
        "observe_i64",
        values => {
          guard values is [I64(value)] else { raise TypeMismatch }
          observed = value
          []
        },
        func_type={ params: [I64], results: [], },
      )
    }
    let loaded = match
      load(direct_import_test_image(), mode~, configure_host=configure) {
      Ok(value) => value
      Err(error) => fail("load failed: \{Repr(error)}")
    }
    assert_eq(runtime_service_exports(loaded.wasm_module()), [])
    let instance = match loaded.new_instance() {
      Ok(value) => value
      Err(error) => fail("instantiate failed: \{Repr(error)}")
    }
    assert_eq(instance.execute(), Ok(Returned))
    assert_eq(observed, 42L)
  }
}

///|
test "core Wasm host import linkage rejects missing and incompatible hosts" {
  let loaded = match load(direct_import_test_image(), mode=Interpreter) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let missing = loaded.new_instance()
  let incompatible = match
    load(direct_import_test_image(), mode=Interpreter, configure_host=(
      linker : @wasmoon_runtime.Linker,
    ) => {
      linker.add_host_func("lane.test", "observe_i64", _ => [], func_type={
        params: [I32],
        results: [],
      })
    }) {
    Ok(value) => value.new_instance()
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_true(missing is Err(EngineTrap(_)))
  assert_true(incompatible is Err(EngineTrap(_)))
}
