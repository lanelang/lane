---
status: accepted
---

# Panic effect

Lane defines `Panic` as a compiler-provided built-in effect atom distinct from
`Io`. It marks source operations whose documented, value-dependent failure
terminates execution through compiler-owned fatal control. `Panic` is not
algebraic, cannot be handled, carries no dictionary, and remains a static
residual effect until residual-effect erasure. The corresponding execution
path ends in the verified `Fatal(message)` terminator and produces
`ExecutionError::Fatal(message)` on every backend.

`panic` has the canonical source type:

```lane
(String) -> Unit ! Panic
```

`Panic` is reserved for operations that explicitly promise source-level fatal
control. It is not inferred from a primitive's value-domain preconditions.
`%bytes_get` and `%bytes_set` therefore remain the single pure primitive API:
callers must establish an in-bounds index, and violating that precondition is
undefined Lane behavior. Recoverable bounds policy belongs to ordinary library
wrappers rather than a second compiler intrinsic family.

`Panic` does not classify arbitrary execution failure. Resource exhaustion,
malformed bytecode, compiler defects, invalid primitive operands, native stack
exhaustion, and direct Wasm traps remain execution-level failures. Conversely,
`Io` describes runtime I/O and is no longer used as a generic observability
marker for fatal source control.

This decision supersedes the `Io` source effect in the compiler-owned fatal
control RFC without changing ADR 0123's single precondition-based Bytes
primitive family. It does not change `Unit` result typing, introduce a bottom
type, or make fatal control handleable.

The new effect tag advances the Buslane codec to version 8, the
module-interface schema to version 12, and the module-object schema to version
18. The linked-program schema is unchanged because the verified bytecode model
already represents the resulting `Fatal` control flow.
