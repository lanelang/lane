///|
priv struct ExternalCounter {
  mut value : Int64
  mut closed : Bool
}

///|
priv struct ExternalHostRun {
  result : Result[Unit, @loisvm_runtime.ExecutionError]
  observed : Array[Int64]
  closed : Int
  finalized : Int
} derive(Debug)

///|
fn external_counter_registry(
  observed : Array[Int64],
  closed : Ref[Int],
  finalized : Ref[Int],
) -> @loisvm_runtime.RuntimeRegistry {
  let counters : @loisvm_runtime.HostObjectStore[ExternalCounter] = @loisvm_runtime.HostObjectStore::new()
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="counter.new",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::none(),
      result=@loisvm_runtime.HostResult::host_object(counters, finalizer=(
        counter : ExternalCounter,
      ) => {
        if !counter.closed {
          counter.closed = true
        }
        finalized.val += 1
      }),
      invoke=fn(_context, _arguments) { { value: 0L, closed: false } },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="counter.add",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::pair(
        @loisvm_runtime.HostParameters::one(
          @loisvm_runtime.HostParameter::host_object(counters),
        ),
        @loisvm_runtime.HostParameters::one(
          @loisvm_runtime.HostParameter::int(),
        ),
      ),
      result=@loisvm_runtime.HostResult::int(),
      invoke=(_context, arguments : (ExternalCounter, Int64)) => {
        if arguments.0.closed {
          raise Failure(message="counter is closed")
        }
        arguments.0.value += arguments.1
        arguments.0.value
      },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="counter.observe",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::one(
        @loisvm_runtime.HostParameter::int(),
      ),
      result=@loisvm_runtime.HostResult::unit(),
      invoke=fn(_context, value : Int64) { observed.push(value) },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::typed(
      symbol="counter.close",
      abi_major=1,
      parameters=@loisvm_runtime.HostParameters::one(
        @loisvm_runtime.HostParameter::host_object(counters),
      ),
      result=@loisvm_runtime.HostResult::unit(),
      invoke=(_context, counter : ExternalCounter) => {
        if counter.closed {
          raise Failure(message="counter is already closed")
        }
        counter.closed = true
        closed.val += 1
      },
    ),
  )
  registry
}

///|
fn run_external_counter_interpreter(
  image : @loisvm_bytecode.BytecodeImage,
) -> ExternalHostRun raise {
  let observed : Array[Int64] = []
  let closed = Ref(0)
  let finalized = Ref(0)
  let loaded = match
    @loisvm_interp.load(
      image,
      external_counter_registry(observed, closed, finalized),
    ) {
    Ok(value) => value
    Err(error) => fail("LoisVM interpreter load failed: \{to_repr(error)}")
  }
  let result = loaded.new_instance().execute()
  { result, observed, closed: closed.val, finalized: finalized.val }
}

///|
fn run_external_counter_wasm(
  image : @loisvm_bytecode.BytecodeImage,
) -> ExternalHostRun raise {
  let observed : Array[Int64] = []
  let closed = Ref(0)
  let finalized = Ref(0)
  let loaded = match
    @loisvm_wasm.load(
      image,
      external_counter_registry(observed, closed, finalized),
    ) {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm load failed: \{to_repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm instantiation failed: \{to_repr(error)}")
  }
  let result = instance.execute()
  { result, observed, closed: closed.val, finalized: finalized.val }
}

///|
test "external type source executes identically across production backends" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|extern type Counter : Type
      #|pub extern type CounterIo : Effect
      #|let counter_new : () -> Counter ! CounterIo = extern("counter.new")
      #|let counter_add : (Counter, Int) -> Int ! CounterIo = extern("counter.add")
      #|let counter_observe : (Int) -> Unit ! CounterIo = extern("counter.observe")
      #|let counter_close : (Counter) -> Unit ! CounterIo = extern("counter.close")
      #|pub fn main() -> Unit ! CounterIo {
      #|  let counter : Counter = counter_new()
      #|  let alias : Counter = counter
      #|  let first : Int = counter_add(counter, 1)
      #|  let second : Int = counter_add(alias, 2)
      #|  let _first_observed : Unit = counter_observe(first)
      #|  let _second_observed : Unit = counter_observe(second)
      #|  counter_close(counter)
      #|}
    ),
  )
  let imports = image.functions.filter_map(fn(entry) {
    match entry {
      RuntimeImport(import_) =>
        Some((import_.symbol, import_.parameters, import_.result))
      _ => None
    }
  })
  let interpreter = run_external_counter_interpreter(image)
  let wasm = run_external_counter_wasm(image)
  debug_inspect(
    (imports, interpreter, wasm),
    content=(
      #|(
      #|  [
      #|    ("counter.add", [Opaque, Int], Int),
      #|    ("counter.new", [], Opaque),
      #|    ("counter.close", [Opaque], Unit),
      #|    ("counter.observe", [Int], Unit),
      #|  ],
      #|  { result: Ok(()), observed: [1, 3], closed: 1, finalized: 1 },
      #|  { result: Ok(()), observed: [1, 3], closed: 1, finalized: 1 },
      #|)
    ),
  )
}
