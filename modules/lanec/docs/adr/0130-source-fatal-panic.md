---
status: superseded
---

# Statement-oriented source panic

This ADR recorded Lane's first Unit-returning runtime-import panic contract.
It is superseded by [compiler-owned fatal control](../fatal-control-rfc.md).

The implemented contract is compiler-owned:

```lane
pub let panic : (String) -> Unit ! Io = builtin("%panic")
```

`Unit` is the ordinary source result. `Io` owns observability and the
compiler-owned wrapper's `Fatal(message)` terminator owns non-returning control.
No bottom type, empty-enum inference, or no-return callable ABI is involved.
Neither the source operation nor its first-class callable form creates a
Runtime Import or requires host registration.

Interpreter and Wasm execution preserve the existing
`ExecutionError::Fatal(message)` public outcome and cleanup contract. Ordinary
host failures remain `ExecutionError::RuntimeImportFailure(symbol, message)`.
The module-object and linked-program schemas were advanced for the new
intrinsic and bytecode forms.
