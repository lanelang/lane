---
status: accepted
---

# Statement-oriented source panic

Lane's initial fatal source operation is deliberately statement-oriented:

```lane
pub let panic : (String) -> Unit ! Io = extern("panic")
```

`Unit` is the direct runtime-import ABI result carrier, not a claim that a
conforming `panic` invocation returns normally. The host binding must terminate
the current execution by raising a runtime-import failure carrying the supplied
message. The call therefore cannot be used as a bottom value to inhabit an
arbitrary result type. A future `Never` type or polymorphic bottom operation
would be a separate language change with its own typing, control-flow, ABI, and
artifact decisions.

`Io` is required. It makes a discarded statement-position call observable and
prevents effect-sensitive optimization from deleting, duplicating, merging, or
reordering it. The compiler treats `panic` as an ordinary, structurally checked
extern declaration. It does not infer fatality from the source name or runtime
symbol and does not add a symbol-specific terminator or optimizer rule.

## Runtime and embedding contract

The public LoisVM host SDK provides `RuntimeBinding::fatal_string(symbol)`.
This constructs the ordinary ABI `(String) -> Unit` at ABI major version 1 and
an implementation that always raises `RuntimeImportFailure::Failure` with the
borrowed String as its message. An embedding chooses the symbol; the default
Lane command registers this binding as `panic` alongside `println`.

Both production backends report a failed call as
`ExecutionError::RuntimeImportFailure(symbol, message)`, mark the execution
instance terminal, and never execute its continuation. This is the existing,
sole out-of-band runtime-import failure channel. It is neither a Lane effect nor
a recoverable `Result`, and it cannot be handled by source code. Recoverable
host errors remain deferred to the explicit host-ABI design tracked separately.

Fatal runtime-import unwinding follows the existing cleanup contract. The
interpreter and Wasm backend release owned values in live Lane frames and
initialized roots as they unwind a cleanup-capable execution failure. Host
Object finalization remains best effort under abnormal termination as specified
by ADR 0001: fatal execution does not promise a sweep of every outstanding host
resource, and deterministic cleanup still requires an explicit effectful API.

## Compatibility and consequences

The linked program contains an ordinary String-to-Unit Runtime Import. No
Buslane, LoisVM bytecode, linked-artifact schema, decoder, or callable ABI
version changes. Runtime linking continues to reject missing or incompatible
bindings before execution.

This smaller contract intentionally favors an honest, complete implementation
over a partial bottom-type feature. It supports fatal statements such as
assertion failure and unreachable test paths. Code needing a value-producing
failure must model that failure with existing typed control flow rather than
pretend that `Unit` is bottom.
