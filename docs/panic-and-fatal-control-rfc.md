# Platform-owned panic and compiler-owned abort

Status: implemented

This RFC supersedes the earlier compiler-owned, message-carrying panic design.

## Decision

The compiler exposes one private terminal primitive to Basic:

```lane
pub let abort : () -> Void ! Panic = builtin("%abort")
```

The canonical Basic library defines the user-facing operation:

```lane
pub fn panic(message : String) -> Void ! { Io, Panic } {
  write_standard_error(message)
  wasi_proc_exit(1)
  abort()
}
```

The two effects own distinct observable facts:

- `Io` records that the implementation writes the diagnostic to an external
  stream;
- `Panic` records that evaluation may terminate the execution irrecoverably.

`Panic` remains non-algebraic and cannot be handled. `Void` remains an ordinary
canonical Basic empty enum and is eliminated explicitly with `absurd` when a
caller needs another result type.

## Ownership boundaries

The intrinsic ABI table is the sole owner of `%abort`:

```text
parameters = []
result = CanonicalBasicVoid
effect = Panic
implementation = Fatal
```

The compiler does not own a panic message, standard-error descriptor, exit
status, WASI import, or platform failure presentation. The selected platform
library owns those policies. The shipped WASIP1 Basic implementation writes to
file descriptor 2 and requests process exit status 1.

VM CFG and the Physical Program retain a fieldless `Fatal` terminator so that
intentional terminal control remains distinct from compiler-proven unreachable
code. The WebAssembly emitter lowers `Fatal` directly to `unreachable`; it
introduces no import, frame, helper, global, or private exception.

The fallback `%abort()` after `proc_exit` is required by the static type of the
WASIP1 import. A conforming host does not return from `proc_exit`; if a broken
or alternative host does, the program still cannot continue past `panic`.

## Consequences

- `panic` has type `(String) -> Void ! { Io, Panic }`.
- A function carrying only `Panic` is not assumed to perform I/O.
- A function carrying `Panic` is not assumed to terminate on every execution.
- Only the verified `%abort` intrinsic contract creates `Fatal`.
- Alternative platform libraries may choose a different diagnostic and
  termination policy without changing the compiler.
- Direct use of `%abort` produces a WebAssembly trap; the shipped Basic `panic`
  normally produces WASIP1 process exit after writing its message.
- Module-object schema 28 records the changed intrinsic identity and shape;
  stale schema 27 objects are rejected.

## Acceptance properties

- Wrong `%abort` parameter, result, effect, or canonical Void annotations are
  rejected by intrinsic validation.
- Direct and first-class `%abort` calls use the ordinary Void result ABI and do
  not execute a continuation.
- The compiler emits no WASI dependency solely because `Fatal` is reachable.
- The shipped Basic panic writes to standard error, requests exit status 1, and
  cannot return.
- Statement-position panic evaluation remains observable because its effect is
  nonempty.
