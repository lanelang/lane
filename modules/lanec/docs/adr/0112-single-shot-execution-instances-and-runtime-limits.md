# Single-shot execution instances and runtime limits

> **Partially superseded.** Execution remains single-shot, but linked inputs are
> raw WebAssembly modules and host imports are supplied through WASI or the
> Wasmoon linker rather than a semantic Runtime Registry.

Lane execution separates a reusable Loaded Executable Image from a single-shot
Execution Instance. A loaded image contains a validated WebAssembly module and
resolved host bindings. Each entry invocation creates a fresh execution
instance containing the dynamic heap, mutable allocator state, runtime context,
and per-execution resource configuration.

An execution instance accepts exactly one selected-entry invocation. Completion,
runtime failure, resource exhaustion, interruption, or engine trap makes that
instance terminal. A caller runs the program again by creating another instance
from the loaded image. Separate instances may execute on different host threads,
but one instance remains thread-confined and cannot be entered concurrently or
re-entered from a runtime import.

Lane does not define a portable logical call-depth limit. A native WebAssembly
stack overflow is a non-unwinding `EngineTrap`; it provides no ARC cleanup
guarantee. Hosts that require recursion control must enforce an engine-level
stack policy rather than changing every Lane function's runtime ABI.

Execution configuration may supply `max_live_heap_bytes`. Dynamic
allocation charges the canonical Lane allocation size, including the common
header, payload, and canonical padding but excluding static image objects,
allocator-private metadata, and free blocks. Final deallocation removes the
same charge. The Wasm allocator enforces this logical live-byte counter.
Exceeding it reports
`ExecutionResourceLimit(LiveHeapBytes)` through private fatal failure.
Fragmentation, `memory.grow` failure, address-space exhaustion, or host OOM may
still fail before or independently of the logical live-byte limit.

V1 defines no bytecode fuel, instruction-count budget, deadline, or portable
timeout semantics and does not instrument every instruction. A host or Wasmoon
may interrupt execution out of band. Such interruption reports `Interrupted`,
does not guarantee ARC unwinding, and makes the execution instance terminal.
Future optional fuel support is an execution-engine facility unless Lane later
standardizes observable fuel semantics.

Private fatal failures, including runtime-import failure, logical live-heap
exhaustion, allocation failure, and ARC overflow, terminate the execution
without generated ownership unwinding. Arithmetic, conversion, unreachable,
native-stack, and external-interruption traps have the same terminal-instance
ownership rule even when they use a different physical failure mechanism.

Successful selected-entry return performs the explicit reverse-order Instance
Global cleanup defined by ADR-0113, but no defensive frame scan, heap scan, or
implicit release sweep. Compiler-inserted ARC must already establish an
ownership-empty normal exit after those roots are released. The single-shot
instance is then destroyed as a whole; this teardown is not observable Lane
destruction semantics and does not repair leaked owners or reference cycles.

The shared execution API distinguishes at least:

- `RuntimeImportFailure`, including the offending symbol when available;
- `ExecutionResourceLimit(LiveHeapBytes)`;
- `Interrupted`;
- `EngineTrap`, with backend-specific detail when available;
- `InternalRuntimeFailure` for trusted-image or runtime implementation defects.

Raw engine trap text is diagnostic detail rather than a portable semantic
subtype. A catchable unexpected host-binding exception is converted to
RuntimeImportFailure after transferred arguments are consumed or released.
Process-level aborts and unrecoverable host OOM are outside the guaranteed VM
failure contract.

Resource configuration belongs to the host invocation and is not serialized in
`.lbp`. Implementations choose defaults when the caller omits a limit. Callers
that require reproducible resource behavior must provide explicit configuration.
For each resource, `None` means unlimited, a positive configured value is the
exact budget, and a zero or negative configured value means zero budget.

## Consequences

- Loaded executable images are reusable; execution instances are single-shot.
- Every entry attempt ends the current instance, whether it succeeds or fails.
- Lane defines no portable logical call-depth limit; engine stack exhaustion is
  an `EngineTrap`.
- Dynamic allocation may be limited by canonical live Lane heap bytes.
- Logical execution limits use structured fatal failure and terminate the
  instance without recovery cleanup.
- V1 has no portable fuel or timeout semantics.
- External interruption and engine traps may bypass cleanup and always discard
  the instance.
- Successful exit releases Instance Globals but performs no defensive ownership sweep.
- Both execution tiers share structured top-level failure categories.
- Runtime limits are host configuration rather than artifact data.
