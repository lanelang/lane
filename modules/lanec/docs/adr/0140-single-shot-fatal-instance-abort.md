# Single-shot fatal instance abort

Lane fatal control is non-recoverable. A fatal intrinsic, runtime resource
limit, runtime-import failure, or compiler-owned runtime guard terminates the
current WebAssembly execution instance. The instance cannot be resumed or
entered again and the embedding must discard it.

The private WebAssembly exception exists only to carry a structured failure to
the Wasmoon execution boundary. It is not a Lane effect, a user-observable
exception, or an exceptional control-flow edge in Runtime ANF, VM CFG, or the
Physical Program. Generated Lane functions and the entry wrapper therefore do
not catch it. They do not maintain per-frame owner liveness, reconstruct an
unwind graph, or release Instance Globals after fatal termination.

Normal control flow retains the compiler-directed ARC contract. VM CFG ARC
insertion emits every retain, transfer, and release needed by ordinary calls,
branches, returns, and successful instance shutdown. A normal return must have
no untransferred owner, and successful entry completion releases initialized
Instance Globals in reverse order. Fatal and unreachable terminators instead
abandon the current instance's remaining owners. A runtime failure that occurs
inside an ordinary instruction has the same behavior without requiring an
implicit exceptional edge from every potentially failing operation.

This distinction is sound because the current WebAssembly target exposes no
observable Lane destructor, stack `finally` action, or host-resource finalizer
whose execution is promised during fatal termination. Deterministic resource
release must remain an explicit source operation on a normal control-flow path.
If Lane later promises observable unwinding, the responsible IR must first gain
explicit exceptional successors and cleanup scopes; the WebAssembly emitter
must not infer those semantics from physical locals.

Resource counters and allocator state need not be restored after fatal
termination. The runtime records the structured failure before throwing, and
the terminal instance remains available only long enough for the embedding to
read that outcome. A fresh execution uses a fresh instance.

This decision supersedes ADR 0074's generated frame cleanup handlers and the
failure-cleanup portions of ADR 0070, ADR 0076, ADR 0082, ADR 0086, ADR 0097,
ADR 0112, and ADR 0113.

## Consequences

- Fatal failure and successful shutdown have deliberately different ownership
  obligations.
- Generated functions contain no fatal `try_table`, frame-cleanup helper, or
  erased-owner liveness local.
- Fatal and unreachable VM CFG terminators may end with live owners; normal
  returns and tail calls may not.
- The entry wrapper releases Instance Globals only after successful execution.
- Private Wasm exceptions preserve structured failure classification without
  defining recovery semantics.
- Observable cleanup after failure requires a future explicit language and IR
  design rather than backend-local liveness reconstruction.
