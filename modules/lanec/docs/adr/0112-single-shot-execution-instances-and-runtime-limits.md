# Single-shot execution instances and runtime limits

LoisVM separates a reusable Loaded Executable Image from a single-shot
Execution Instance. A loaded image contains the decoded bytecode image,
resolved runtime bindings, and any reusable backend product such as a compiled
Wasm module. Each entry invocation creates a fresh execution instance containing
the dynamic heap, call frames, mutable allocator state, runtime context, and
per-execution resource configuration.

An execution instance accepts exactly one selected-entry invocation. Completion,
runtime failure, resource exhaustion, interruption, or engine trap makes that
instance terminal. A caller runs the program again by creating another instance
from the loaded image. Separate instances may execute on different host threads,
but one instance remains thread-confined and cannot be entered concurrently or
re-entered from a runtime import.

The interpreter implements calls with an explicit LoisVM frame stack rather
than recursive MoonBit calls. A returning bytecode-body call pushes one frame;
a tail call replaces the current frame. Runtime-import invocation does not
create a Lane frame.

Execution configuration may supply `max_call_depth`. The selected entry begins
at logical depth one. A returning call to another bytecode body checks and then
increments logical depth; normal return decrements it. Tail calls preserve the
current depth, and runtime imports do not affect it. The Wasm tier enforces the
same logical rule in generated code rather than relying on the engine's native
stack limit. Exceeding the configured limit reports
`ExecutionResourceLimit(CallDepth)` through the private fatal cleanup path.

An engine-native stack overflow that occurs before the logical check is a
non-unwinding EngineTrap. It provides no ARC cleanup guarantee and indicates an
engine limitation or unsafe execution configuration rather than the ordinary
Lane call-depth limit.

Execution configuration may also supply `max_live_heap_bytes`. Dynamic
allocation charges the canonical Lane allocation size, including the common
header, payload, and canonical padding but excluding static image objects,
allocator-private metadata, and free blocks. Final deallocation removes the
same charge. Both the interpreter heap and the Wasm allocator enforce this
logical live-byte counter. Exceeding it reports
`ExecutionResourceLimit(LiveHeapBytes)` through private fatal cleanup.
Fragmentation, `memory.grow` failure, address-space exhaustion, or host OOM may
still fail before or independently of the logical live-byte limit.

V1 defines no bytecode fuel, instruction-count budget, deadline, or portable
timeout semantics and does not instrument every instruction. A host or Wasmoon
may interrupt execution out of band. Such interruption reports `Interrupted`,
does not guarantee ARC unwinding, and makes the execution instance terminal.
Future optional fuel support is an execution-engine facility unless Lane later
standardizes observable fuel semantics.

Private fatal failures, including runtime-import failure, logical call-depth
exhaustion, logical live-heap exhaustion, allocation failure, and ARC overflow,
perform the established ownership cleanup before reaching the execution
boundary. The instance is discarded even when that cleanup leaves its internal
state consistent. Non-unwinding arithmetic, conversion, unreachable, native
stack, and external interruption paths may skip cleanup and also require
discarding the instance.

Successful selected-entry return performs no defensive frame scan, heap scan,
or implicit release sweep. Compiler-inserted ARC must already establish an
ownership-empty normal exit. The single-shot instance is then destroyed as a
whole; this teardown is not observable Lane destruction semantics and does not
repair leaked owners or reference cycles.

The shared execution API distinguishes at least:

- `RuntimeImportFailure`, including the offending symbol when available;
- `ExecutionResourceLimit`, with a limit kind such as CallDepth or
  LiveHeapBytes;
- `Interrupted`;
- `EngineTrap`, with backend-specific detail when available;
- `InternalRuntimeFailure` for trusted-image or runtime implementation defects.

Interpreter and Wasm execution expose the same top-level categories, but raw
engine trap text is diagnostic detail rather than a portable semantic subtype.
A catchable unexpected host-binding exception is converted to
RuntimeImportFailure after transferred arguments are consumed or released.
Process-level aborts and unrecoverable host OOM are outside the guaranteed VM
failure contract.

Resource configuration belongs to the host invocation and is not serialized in
`.lbp`. Implementations choose defaults when the caller omits a limit. Callers
that require reproducible resource behavior must provide explicit configuration.

## Consequences

- Loaded executable images are reusable; execution instances are single-shot.
- Every entry attempt ends the current instance, whether it succeeds or fails.
- The interpreter uses an explicit frame stack.
- Returning Lane calls increase logical call depth; tail calls and imports do
  not.
- Interpreter and Wasm paths enforce the same configured logical depth rule.
- Dynamic allocation may be limited by canonical live Lane heap bytes.
- Logical execution limits use cleanup-capable fatal failure.
- V1 has no portable fuel or timeout semantics.
- External interruption and engine traps may bypass cleanup and always discard
  the instance.
- Successful exit performs no defensive ownership sweep.
- Both execution tiers share structured top-level failure categories.
- Runtime limits are host configuration rather than artifact data.
