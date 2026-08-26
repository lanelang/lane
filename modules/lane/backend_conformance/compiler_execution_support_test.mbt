///|
priv enum CompilerExecutionBackend {
  DirectInterpreter
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
  result : Result[Unit, @lane_runtime.ExecutionError]
  i64_values : Array[Int64]
  f64_bits : Array[UInt64]
  callback_calls : Int
} derive(Debug, Eq)

///|
fn compiler_test_runtime_registry(
  observations : CompilerExecutionObservations,
) -> @lane_runtime.RuntimeRegistry {
  let registry = @lane_runtime.RuntimeRegistry::new()
  registry.register(
    @lane_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_i64",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        guard arguments is [I64(value)] else {
          abort("expected one I64 observation")
        }
        observations.i64_values.push(value)
        Unit
      },
    ),
  )
  registry.register(
    @lane_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_f64",
      abi_major=1,
      parameters=[F64],
      result=Unit,
      invoke=fn(_context, arguments) {
        guard arguments is [F64(value)] else {
          abort("expected one F64 observation")
        }
        observations.f64_bits.push(value.reinterpret_as_uint64())
        Unit
      },
    ),
  )
  registry.register(
    @lane_runtime.RuntimeBinding::new(
      symbol="lane.test.callback",
      abi_major=1,
      parameters=[],
      result=Unit,
      invoke=fn(_context, arguments) {
        guard arguments.is_empty() else {
          abort("expected no callback observation arguments")
        }
        observations.callback_calls += 1
        Unit
      },
    ),
  )
  registry
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
  let registry = compiler_test_runtime_registry(observations)
  let result = match backend {
    DirectInterpreter => {
      let loaded = match load_physical_interpreted(image, registry) {
        Ok(loaded) => loaded
        Err(error) => fail("direct interpreter load failed: \{Repr(error)}")
      }
      loaded.execute()
    }
    WasmInterpreter | WasmJit => {
      let mode = match backend {
        WasmInterpreter => @lane_wasm_runtime.ExecutionMode::Interpreter
        WasmJit => Jit
        DirectInterpreter => abort("unreachable compiler execution backend")
      }
      let loaded = match load_physical(image, registry, mode~) {
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
  [DirectInterpreter, WasmInterpreter, WasmJit].map(backend => {
    execute_compiler_test_image(image, backend)
  })
}

///|
fn expected_i64_execution_matrix(
  value : Int64,
  callback_calls : Int,
) -> Array[CompilerExecutionOutcome] {
  [DirectInterpreter, WasmInterpreter, WasmJit].map(backend => {
    backend,
    result: Ok(()),
    i64_values: [value],
    f64_bits: [],
    callback_calls,
  })
}
