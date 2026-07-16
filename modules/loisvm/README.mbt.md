# LoisVM

A small, language-independent virtual-machine platform.

- Portable register-style bytecode
- Either the LoisVM interpreter or WebAssembly as backend

## Installation

### Source workspace

The source checkout works today without any Lane compiler package:

```bash
moon add Milky2018/loisvm
```

The application module declares the local LoisVM module by its normal identity:

```toml
import {
  "Milky2018/loisvm",
}
```

Its `moon.pkg` imports only the platform packages it uses:

```moonbit nocheck
import {
  "Milky2018/loisvm/bytecode",
  "Milky2018/loisvm/interp",
  "Milky2018/loisvm/runtime",
  "Milky2018/loisvm/wasm",
}
```

The Wasm tier currently targets MoonBit native builds because it embeds Wasmoon. The bytecode, runtime, and interpreter packages remain usable without the Wasm package.

## Runnable end-to-end example

The following tested example constructs a bytecode image without Lane, round-trips it through the binary codec, binds a host function, and runs the exact decoded image through both backends. The bytecode computes `40 + 2` and sends the result to `example.observe_int`.

```moonbit check
///|
fn example_trivial_slot(
  representation : @bytecode.Representation,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, erased_companion: None }
}

///|
fn example_image() -> @bytecode.BytecodeImage {
  let left : @bytecode.SlotId = { value: 0 }
  let right : @bytecode.SlotId = { value: 1 }
  let sum : @bytecode.SlotId = { value: 2 }
  let entry : @bytecode.FunctionBody = {
    slots: [
      example_trivial_slot(I64),
      example_trivial_slot(I64),
      example_trivial_slot(I64),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstInt(left, 40L),
          ConstInt(right, 2L),
          IntAdd(sum, left, right),
          CallDirect({ value: 2 }, None, [], [sum], None),
        ],
        terminator: Return(None),
      },
    ],
  }
  {
    entry: { value: 1 },
    initializer: None,
    globals: [],
    functions: [
      BytecodeBody(entry),
      RuntimeImport({
        abi_major: 1,
        parameters: [Int],
        result: Unit,
        symbol: "example.observe_int",
      }),
    ],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
fn example_registry(observed : Array[Int64]) -> @runtime.RuntimeRegistry {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::new(
      symbol="example.observe_int",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=(_context, arguments) => {
        guard arguments is [Int(value)] else {
          raise Failure(message="example.observe_int expects one Int")
        }
        observed.push(value)
        Unit
      },
    ),
  )
  registry
}

///|
fn run_with_interpreter(image : @bytecode.BytecodeImage) -> Array[Int64] raise {
  let observed : Array[Int64] = []
  let loaded = match @interp.load(image, example_registry(observed)) {
    Ok(value) => value
    Err(error) => fail("interpreter load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  observed
}

///|
fn run_with_wasm(image : @bytecode.BytecodeImage) -> Array[Int64] raise {
  let observed : Array[Int64] = []
  let loaded = match @wasm.load(image, example_registry(observed)) {
    Ok(value) => value
    Err(error) => fail("Wasm load failed: \{to_repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("Wasm instantiation failed: \{to_repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
  observed
}

///|
test "one LoisVM image runs through both execution tiers" {
  let original = example_image()
  let bytes = @bytecode.bytecode_image_to_binary(original)
  let decoded = match @bytecode.parse_bytecode_image_binary(bytes) {
    Ok(value) => value
    Err(error) => fail("bytecode decode failed: \{to_repr(error)}")
  }
  assert_eq(decoded, original)
  assert_eq(run_with_interpreter(decoded), [42L])
  assert_eq(run_with_wasm(decoded), [42L])
}
```

`@wasm.load` prepares Wasmoon JIT code by default. Pass
`mode=@wasm.ExecutionMode::Interpreter` to execute the generated WebAssembly
with Wasmoon's instruction interpreter instead.

Run this README from the LoisVM module directory:

```bash
cd modules/loisvm
moon test --target native
```

## Ownership and ARC contract

LoisVM does not infer ownership from bytecode. The producer must finish ownership analysis before emitting an image.

- `SlotMetadata.cleanup` declares whether a slot is trivial, an owned reference, an owned callable, or an owned erased value.
- `Move` transfers an owner; `RetainCopy` creates another owner; `Release` destroys one owner.
- Returning calls, returns, tail calls, consuming projections, closure construction, object construction, and selected CFG edges transfer their owned operands.
- Borrowing projections and ordinary non-consuming reads do not transfer ownership.
- An `OwnedErased` slot names a trivial companion slot containing the runtime `LayoutId` needed for descriptor-directed release.
- Heap objects use nonzero linear-memory references and compiler-directed reference counts in both backends.

Incorrect ownership bytecode is outside the trusted producer contract and may leak, double-release, or trap. A frontend should keep ownership tests at CFG joins, repeated calls, closure captures, object projections, runtime-import failure paths, and tail calls.

## Runtime imports

Runtime imports are ordinary entries in the unified function table. Loading resolves every import by exact symbol, ABI major version, parameter kinds, and result kind before publishing a loaded image.

Bindings declare their full direct-value signature through `RuntimeBinding`:

- `Unit`
- `Bool`
- `Int`, represented to the host as `Int64`
- `Double`
- `String`
- `Opaque`, represented to bindings as borrowed or owned Host Objects

String parameters arrive as `BorrowedString(HostStringView)` and are valid only for the duration of the call. Copy them with `to_string()` or `to_bytes()` if the host needs an owned value. String results use `HostValue::String`. V1 Strings and bytecode constants are ASCII.

Use `RuntimeBinding::typed`, `HostParameters`, `HostParameter`, and `HostResult`
to register typed host functions without manually indexing erased argument
arrays. `HostParameter::host_object()` performs the trusted unbranded projection
for an `Opaque` parameter. `HostResult::host_object(finalizer~)` creates an
independently owned result whose finalizer runs when Lane releases its final
wrapper.

For a Lane library, an opaque host API can be declared without teaching the
compiler any symbol-specific behavior:

```lane
extern type Counter : Type
extern type CounterIo : Effect

let counter_new : () -> Counter ! CounterIo = extern("counter.new")
let counter_add : (Counter, Int) -> Int ! CounterIo = extern("counter.add")
let counter_close : (Counter) -> Unit ! CounterIo = extern("counter.close")
```

The embedding registers the corresponding direct ABI. Primitive descriptors
decode to ordinary MoonBit values. `HostParameter::host_object()` borrows the
payload for one synchronous call, while `HostResult::host_object` transfers a
new independently finalized payload into Lane:

```moonbit check
///|
priv struct ReadmeCounter {
  mut value : Int64
  mut closed : Bool
}

///|
fn readme_counter_registry(
  observed : Array[Int64],
  closed : Ref[Int],
  finalized : Ref[Int],
) -> @runtime.RuntimeRegistry {
  let registry = @runtime.RuntimeRegistry::new()
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="counter.new",
      abi_major=1,
      parameters=@runtime.HostParameters::none(),
      result=@runtime.HostResult::host_object(finalizer=(
        counter : ReadmeCounter,
      ) => {
        if !counter.closed {
          counter.closed = true
        }
        finalized.val += 1
      }),
      invoke=(_context, _arguments) => ReadmeCounter::{
        value: 0L,
        closed: false,
      },
    ),
  )
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="counter.add",
      abi_major=1,
      parameters=@runtime.HostParameters::pair(
        @runtime.HostParameters::one(@runtime.HostParameter::host_object()),
        @runtime.HostParameters::one(@runtime.HostParameter::int()),
      ),
      result=@runtime.HostResult::int(),
      invoke=(_context, arguments : (ReadmeCounter, Int64)) => {
        if arguments.0.closed {
          raise @runtime.RuntimeImportFailure::Failure(
            message="counter is closed",
          )
        }
        arguments.0.value += arguments.1
        arguments.0.value
      },
    ),
  )
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="counter.observe",
      abi_major=1,
      parameters=@runtime.HostParameters::one(@runtime.HostParameter::int()),
      result=@runtime.HostResult::unit(),
      invoke=(_context, value : Int64) => observed.push(value),
    ),
  )
  registry.register(
    @runtime.RuntimeBinding::typed(
      symbol="counter.close",
      abi_major=1,
      parameters=@runtime.HostParameters::one(
        @runtime.HostParameter::host_object(),
      ),
      result=@runtime.HostResult::unit(),
      invoke=(_context, counter : ReadmeCounter) => {
        if counter.closed {
          raise @runtime.RuntimeImportFailure::Failure(
            message="counter is already closed",
          )
        }
        counter.closed = true
        closed.val += 1
      },
    ),
  )
  registry
}

///|
test "typed host registration declares primitive and Opaque ABI kinds" {
  let registry = readme_counter_registry([], Ref(0), Ref(0))
  debug_inspect(
    ["counter.new", "counter.add", "counter.observe", "counter.close"].map(symbol => {
      registry
      .find(symbol)
      .map(binding => (binding.symbol(), binding.parameters(), binding.result()))
    }),
    content=(
      #|[
      #|  Some(("counter.new", [], Opaque)),
      #|  Some(("counter.add", [Opaque, Int], Int)),
      #|  Some(("counter.observe", [Int], Unit)),
      #|  Some(("counter.close", [Opaque], Unit)),
      #|]
    ),
  )
}
```

Every `Opaque` result creates one execution-local Host Object Table entry and
one Lane ARC wrapper. Lane copies retain the wrapper and share the same mutable
payload. An `Opaque` parameter is borrowed and must not be retained by the
binding. The per-result finalizer runs exactly once after the last wrapper is
released during normal execution; explicit effectful cleanup such as
`counter.close` should mark the payload closed so the finalizer can act as a
non-observable fallback without releasing the resource twice.

Host Object handles never enter the public binding API, bytecode, or Wasm
linear memory. Payload projection is intentionally unbranded and trusted:
runtime linking verifies `Opaque` versus primitive kinds but cannot distinguish
two source External Types. Host Objects are execution-local and thread-affine,
and `ExecutionConfig.max_host_objects` bounds the number of live entries.

Host calls are synchronous. A binding must not retain a borrowed VM value or re-enter the active execution instance. Report host failures by raising `RuntimeImportFailure::Failure`; both backends convert it into `ExecutionError::RuntimeImportFailure`.

## Loading and execution lifecycle

Use this lifecycle for either backend:

1. Construct or decode a `BytecodeImage`.
2. Build a `RuntimeRegistry` containing every required import.
3. Call `load`; import resolution and backend preparation complete atomically.
4. Reuse the loaded image to create independent execution instances.
5. Call `execute` once on each instance.

`LoadedImage` is reusable. `ExecutionInstance` is single-shot and thread-confined. Calling `execute` a second time returns `InstanceNotReady`.

Resource limits are selected per instance with `ExecutionConfig`:

```moonbit nocheck
///|
let config : @runtime.ExecutionConfig = {
  max_call_depth: Some(1024),
  max_live_heap_bytes: Some(64 * 1024 * 1024),
  max_host_objects: Some(4096),
}
```

`None` leaves a resource unlimited. A positive `Some` value supplies that exact budget, while zero or a negative value supplies zero budget and causes the corresponding resource limit to be reported before the resource is consumed.

The interpreter returns an instance directly from `loaded.new_instance(config~)`. The Wasm tier returns `Result[ExecutionInstance, ExecutionError]` because Wasmoon instantiation can fail.

Both tiers accept an optional cancellation poll callback through `execute(cancel=Some(check))`. Returning `true` stops execution with `Interrupted`, makes the single-shot instance terminal, and does not guarantee ARC unwinding. The interpreter polls in its dispatch loop; the Wasm tier delegates polling to Wasmoon function and loop safepoints. A blocking runtime import is not interrupted while the host function is running.

## Persistence and diagnostics

Use `bytecode_image_to_binary` and `parse_bytecode_image_binary` as the persistence boundary. The binary stores the current canonical bytecode layout directly, without an independent bytecode version or compatibility decoder. Producers and consumers must use the matching LoisVM implementation; persisted `.lbp` compatibility is owned by the enclosing linked-program artifact schema.

Every image encodes the optional instance initializer and Instance Global table, including their empty forms. `GlobalId` is a dense zero-based table index, while `FunctionId` remains nonzero and one-based.

Use `bytecode_image_to_disassembly` for human-readable diagnostics, snapshots, and producer debugging. Disassembly is not a stable persistence or parsing format.

Binary decoding validates framing, tags, lengths, and basic image structure. LoisVM deliberately does not include a full bytecode verifier. Images are trusted compiler output, so a producer remains responsible for slot data flow, control-flow compatibility, call signatures, ownership balance, object-shape compatibility, and all other semantic invariants.

## Backend choice

Use `loisvm/interp` when bytecode-level startup latency, portability, or debugging simplicity matters most. Use `loisvm/wasm` when the embedding application runs natively and wants Wasmoon to compile the same bytecode into WebAssembly. The Wasm package JIT-compiles by default and accepts `ExecutionMode::Interpreter` as an explicit fallback.

The backend decision remains an embedding policy because bytecode and runtime bindings are shared. `lane run` and `lane runobj` select JIT execution by default; `--no-jit` selects the Wasmoon interpreter without changing the LoisVM image or runtime registry.
