# Compiler-owned fatal control

Status: implemented

## Decision

Lane exposes fatal termination through the compiler-owned intrinsic `%panic`:

```lane
pub let panic : (String) -> Unit ! Panic = builtin("%panic")
```

The source contract deliberately uses `Unit`, not a bottom type. `panic` is a
statement-oriented operation: it does not need to inhabit arbitrary expression
types. The compiler-provided `Panic` effect makes the call observable to
effect-sensitive compiler passes without claiming that it performs I/O. The
execution-level `Fatal(message)` terminator, rather than the source result type,
states that the intrinsic implementation has no normal successor.

These are separate facts:

- `Unit` is the ordinary source and callable result ABI;
- `Panic` prevents the call from being treated as pure or discarded;
- `Fatal` terminates execution and produces the typed fatal outcome.

Lane does not introduce a source `Never` type, bottom subtyping, implicit
bottom conversion, a no-return callable ABI, or special handling for empty
enums. A user-defined empty enum such as `Void` remains ordinary nominal data.

## Intrinsic ownership

`%panic` is listed in the compiler intrinsic table with the canonical signature
`(String) -> Unit ! Panic`. The type checker synthesizes that signature and checks
annotations through the normal builtin-signature compatibility path. Neither
the type checker nor a backend recognizes `Basic.Io.panic` by declaration name.

The intrinsic signature table is the sole owner of its source type and effect.
Buslane elaboration materializes that entry as an opaque intrinsic contract;
module objects persist only the intrinsic identity, and linking validates its
metadata type against the contract reconstructed from the table. Later phases
consume the contract rather than accepting an independently supplied intrinsic
type. The lowering phase creates a normal Unit-returning callable wrapper whose
body ends in `Fatal(message)`. Calls to the wrapper use the same direct,
first-class, tail-call, and adapter machinery as every other Unit-returning
callable.

## Control-flow contract

`Fatal(message)` is a terminator in VM CFG and LoisVM bytecode. It:

1. consumes one owned String;
2. has no CFG successor;
3. initiates fatal cleanup;
4. produces `ExecutionError::Fatal(message)`.

`Fatal` is legal in a function body with any declared result ABI because it
does not return a result. In the `%panic` wrapper that ABI is Unit. `Return`
continues to obey the declared result ABI; `Fatal` is a control-flow alternative
to returning, not a result value.

An ordinary call instruction may syntactically have a continuation when the
callee is known only through the Unit callable ABI. Invoking `%panic` never
reaches that continuation because its wrapper executes `Fatal`. This is the
same observable behavior for direct and first-class calls.

## Backend contract

The interpreter decodes the owned String, releases it, performs fatal cleanup,
and returns `ExecutionError::Fatal(message)`.

The Wasm backend calls the closed internal `FatalString` transport, releases
the String wrapper, and throws through the backend's fatal unwind path. The
embedding does not register a public `panic` Runtime Import.

Both backends must:

- preserve the exact message;
- stop before any normal continuation;
- release live owned values according to the fatal-unwind contract;
- return the same public typed execution error.

Ordinary host failures remain
`ExecutionError::RuntimeImportFailure(symbol, message)` and are never inferred
to be panic from a symbol spelling.

## Persistence

The module-object schema persists the `Panic` compiler intrinsic. The linked
program schema persists the `Fatal` bytecode terminator. `ResultAbi` remains
`Unit | Value(...)`; no persisted no-return result or special call opcode
exists.

The decoder owns framing and tag validity. The bytecode verifier owns semantic
validation, including that the Fatal operand is an owned String and that no
owned value is leaked on the terminating path.

## Optimization

Source optimization observes the `Panic` effect and must preserve the evaluation
of discarded panic calls. Runtime ANF projection removes static effect syntax
only after effect-aware optimization and lowering have preserved evaluation
order and the compiler intrinsic.
CFG optimization treats `Fatal` as a terminator with no successor.

No optimization may infer fatality from `Unit`, `Panic`, an empty enum, a source
declaration name, or a Runtime Import symbol.

## Non-goals

This RFC does not add:

- expression-polymorphic `panic`;
- a source bottom type;
- implicit coercion from fatal calls to unrelated result types;
- recoverable exceptions or handled fatal effects;
- host-defined panic registration;
- a general no-return function annotation.

If Lane later needs bottom typing or control-flow refinement, that feature must
be designed independently. It must not be reconstructed from this
statement-oriented API.

## Acceptance properties

- Basic exports exactly `(String) -> Unit ! Panic = builtin("%panic")`.
- The intrinsic synthesizes the same canonical type without an annotation.
- Wrong parameter, result, or effect annotations produce the ordinary builtin
  signature mismatch diagnostic.
- Direct and first-class calls use the ordinary Unit callable ABI.
- The compiler emits no Runtime Import for panic.
- The wrapper body ends in verified `Fatal(message)`.
- Interpreter and Wasm/JIT return `ExecutionError::Fatal(message)` and do not
  execute the continuation.
- A statement-position panic remains observable.
- Ordinary empty enums retain ordinary data representation and control flow.
