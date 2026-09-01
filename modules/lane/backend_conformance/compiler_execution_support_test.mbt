///|
priv enum CompilerExecutionBackend {
  WasmInterpreter
  WasmJit
} derive(Debug, Eq)

///|
priv struct CompilerExecutionObservations {
  i64_values : Array[Int64]
  f64_bits : Array[UInt64]
  mut callback_calls : Int
}

///|
priv struct CompilerExecutionOutcome {
  backend : CompilerExecutionBackend
  result : Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError]
  i64_values : Array[Int64]
  f64_bits : Array[UInt64]
  callback_calls : Int
} derive(Debug, Eq)

///|
fn compiler_test_host(
  observations : CompilerExecutionObservations,
) -> TestHostBindings {
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_i64", value => {
    observations.i64_values.push(value)
  })
  host.observe_f64("lane.test.observe_f64", value => {
    observations.f64_bits.push(value.reinterpret_as_uint64())
  })
  host.signal("lane.test.callback", () => observations.callback_calls += 1)
  host
}

///|
fn execute_compiler_test_image(
  image : @physical.PhysicalProgram,
  backend : CompilerExecutionBackend,
) -> CompilerExecutionOutcome raise {
  let observations : CompilerExecutionObservations = {
    i64_values: [],
    f64_bits: [],
    callback_calls: 0,
  }
  let host = compiler_test_host(observations)
  let result = match backend {
    WasmInterpreter | WasmJit => {
      let mode = match backend {
        WasmInterpreter => @lane_wasm_runtime.ExecutionMode::Interpreter
        WasmJit => Jit
      }
      let loaded = match load_physical(image, mode~, host~) {
        Ok(loaded) => loaded
        Err(error) => fail("Wasm load failed: \{Repr(error)}")
      }
      let instance = match loaded.new_instance() {
        Ok(instance) => instance
        Err(error) => fail("Wasm instantiation failed: \{Repr(error)}")
      }
      instance.execute()
    }
  }
  {
    backend,
    result,
    i64_values: observations.i64_values,
    f64_bits: observations.f64_bits,
    callback_calls: observations.callback_calls,
  }
}

///|
fn execute_compiler_test_matrix(
  source : String,
) -> Array[CompilerExecutionOutcome] raise {
  let image = compile_effect_conformance_image(source)
  [WasmInterpreter, WasmJit].map(backend => {
    execute_compiler_test_image(image, backend)
  })
}

///|
fn expected_i64_execution_matrix(
  value : Int64,
  callback_calls : Int,
) -> Array[CompilerExecutionOutcome] {
  [WasmInterpreter, WasmJit].map(backend => {
    backend,
    result: Ok(Returned),
    i64_values: [value],
    f64_bits: [],
    callback_calls,
  })
}
