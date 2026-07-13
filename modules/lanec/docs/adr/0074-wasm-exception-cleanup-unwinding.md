# Wasm fatal exception cleanup unwinding

Lane's Wasm backend uses Exception Handling with `exnref` to implement out-of-band fatal execution unwinding. Runtime-import failure, out-of-memory, ARC overflow, and similar fatal internal errors use a private Wasm exception. This is a backend cleanup mechanism only. Lane source effects have already been erased, LoisVM bytecode has no exceptional control-flow edge, and the private exception is never represented as a Lane value or exposed to Lane code.

Compiler-proven unreachable bytecode, undefined integer arithmetic, and invalid Double-to-Int conversion are outside this recoverable-cleanup channel. Unreachable lowering may emit `unreachable` directly. Signed division by zero or `MIN_INT / -1`, signed remainder by zero, and trapping `i64.trunc_f64_s` conversion may use Wasm traps directly. These traps do not run private-exception cleanup; the embedding discards the current instance rather than resuming or reusing it.

A runtime-import adapter consumes or releases every transferred argument before reporting failure. It then throws a private Wasm exception, optionally carrying only non-Lane diagnostic state required by the execution boundary. A generated Lane function that can hold owned values across a potentially failing call installs an internal cleanup handler. The handler releases exactly the owners still held by that frame at the throwing program point, then rethrows the same private exception.

Arguments transferred into the callee are no longer owned by the caller and are not released by the caller's handler. The callee or failing import is responsible for them. Tail calls first explicitly release or transfer every owner belonging to the replaced frame, so `return_call` and `return_call_indirect` leave no current-frame ownership requiring a handler after the tail transfer. If the tail target is a runtime import and its adapter throws, cleanup begins in that adapter rather than in the replaced frame.

The Wasm backend derives cleanup ownership state from trusted bytecode ownership operations and representation metadata. This derivation is not a general bytecode verifier and does not add serialized borrow regions or source types. Retain, release, and destructor operations used during cleanup must not throw.

The exported `"lane.entry":() -> ()` wrapper does not convert the private exception inside the generated module. It may escape that export to the Wasmoon execution boundary, which catches it and converts it to the same fatal execution failure reported by `loisvm/interp`. Recoverable host outcomes continue to use ordinary primitive results and do not throw.

A restricted runtime-service nested call, including `"lane.runtime.string.new"`, uses the same failure channel. If the service fails, it leaves allocator metadata consistent and throws the private fatal exception. This nested service path cannot invoke Lane entry or ordinary Lane callables and does not create a bytecode-visible exception edge.

Allocator free, layout destruction, ownership release, and cleanup handlers are non-throwing. Allocation is the only allocator operation that may fail; it reports OOM through the private fatal exception after leaving allocator metadata consistent.

Consequences:

- Exception Handling with `exnref` belongs to the Lane Wasm output profile.
- Runtime-import failure, OOM, and ARC overflow share private fatal unwinding.
- Wasm exceptions implement cleanup only and do not reintroduce Lane effects.
- Trusted unreachable paths may trap directly outside the private exception channel.
- Undefined integer division traps also bypass cleanup and invalidate the instance.
- Invalid Double-to-Int traps bypass cleanup under the same discard rule.
- Fatal import failure preserves frame-local ARC cleanup before the single-shot
  execution instance is discarded.
- Cleanup handlers release only ownership still held at the throwing point.
- Transferred call arguments are cleaned by the callee or failing import, not twice by the caller.
- Proper tail calls transfer or release the replaced frame's ownership before tail transfer.
- Cleanup retain, release, and destruction paths are non-throwing.
- Private fatal exceptions may escape `"lane.entry"` to Wasmoon.
- Restricted runtime-service failures use the same fatal unwind.
- Recoverable runtime outcomes remain normal values.
