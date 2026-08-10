---
status: superseded
---

# Statement-oriented source panic

This ADR recorded Lane's first, Unit-returning runtime-import panic contract.
It is superseded by [Void-returning fatal control](../fatal-control-rfc.md).

The implemented contract is compiler-owned:

```lane
pub let panic : (String) -> Void ! Io = builtin("%panic")
```

`Void` remains an ordinary empty enum and callers use its explicit `absurd`
eliminator when another source result is required. The execution ABI derives a
result-only `Never` contract for empty-enum callable results, and `%panic`
materializes a compiler-owned callable whose body ends in `Fatal(message)`.
Neither the source operation nor its first-class callable form creates a
Runtime Import or requires host registration.

Interpreter and Wasm execution preserve the existing
`ExecutionError::Fatal(message)` public outcome and cleanup contract. Ordinary
host failures remain `ExecutionError::RuntimeImportFailure(symbol, message)`.
The module-object and linked-program schemas were advanced for the new
intrinsic and bytecode forms.
