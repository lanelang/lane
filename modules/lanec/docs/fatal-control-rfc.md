# Compiler-owned fatal control

Status: implemented

## Decision

Lane exposes fatal termination through the canonical Basic binding:

```lane
module Basic.Io

import Basic.Data.Void.{ Void }

pub let panic : (String) -> Void ! Panic = builtin("%panic")
```

`Void`, `Panic`, and `Fatal` own different facts:

- `Basic.Data.Void.Void` is the ordinary nominal empty result type;
- `Panic` makes possible fatal behavior visible to effect-sensitive passes;
- the verified intrinsic contract implements `%panic` as
  `Fatal(message_parameter=0)`;
- `Fatal(message)` ends VM CFG and bytecode control with no successor.

Lane has no built-in bottom type, implicit bottom conversion, no-result callable
ABI, or special representation for empty enums. A value context uses the
ordinary Basic eliminator explicitly:

```lane
absurd[I64](panic("missing integer"))
```

## Canonical Basic and intrinsic ownership

The compiler-owned Basic provider catalog names `Basic.Data.Void.Void` together
with the providers for tuple, list, and structural-derivation features. Semantic
checking resolves the provider from the explicit module closure and proves that
it is a public enum with no parameters or variants. Later phases carry its
resolved nominal identity and never rediscover Void by spelling or shape.

The intrinsic table owns the complete symbolic `%panic` contract:

```text
parameters = [String]
result = CanonicalBasicVoid
effect = Panic
implementation = Fatal(message_parameter=0)
```

Type checking materializes the resolved function type once. Buslane lowering,
module objects, linking, function planning, and LoisVM lowering carry that full
verified type rather than reconstructing it from the intrinsic name. Module
objects persist the resolved type with the intrinsic identity.

## Callable and control-flow contract

The panic wrapper uses the ordinary callable ABI derived from
`(String) -> Void ! Panic`. Its result is therefore the normal nominal-data ABI
for Void. The wrapper has no `Return`; its body ends in `Fatal(message)`.

`Fatal` is legal in a function with any declared result ABI because it produces
no value and has no successor. Direct calls, first-class calls, tail positions,
and adapters use ordinary callable machinery. There is no Never result, fake
Void value, or terminal-call opcode.

An arbitrary function carrying `Panic` may return normally. Only the verified
intrinsic contract's `Fatal` implementation permits the compiler to remove a
normal continuation; its parameter index is also the sole source of the fatal
message operand.

## Execution profiles

Entry validation consumes an explicit execution profile. The Lane CLI profile
admits `Io`, `Panic`, and closed external effects. A future built-in effect is
rejected until a profile deliberately includes it; no `Builtin(_)` admission
rule exists.

The selected entry still has shape `() -> Unit ! E`. Its result is unrelated to
panic's Void result: callers use `absurd[Unit]` when a fatal branch occurs in a
Unit context.

## Backend and persistence contract

Both interpreter and Wasm/JIT execution preserve the message, perform fatal
cleanup, skip the normal continuation, and return the typed
`ExecutionError::Fatal(message)` outcome. Runtime import failures remain a
separate typed error.

The migration advances module-interface schema 12 to 13, module-object schema
19 to 20, and linked-program schema 15 to 16. The bytecode instruction language
does not change: `Fatal` and ordinary value result ABIs already express the
required execution contract. Decoders reject the immediately preceding schema
versions.

## Optimization

Before runtime projection, `Panic` is a nonempty semantic effect. Optimizers
must preserve panic-capable evaluation. They may infer terminal control only
from the verified `%panic` contract's `Fatal` implementation, never from Void,
another empty enum, the `Panic` effect alone, a declaration name, or a runtime
symbol.

After `%panic` becomes `Fatal`, CFG analyses consume its empty successor set.

## Acceptance properties

- Basic exports exactly `(String) -> Void ! Panic`.
- Wrong parameter, result, effect, or canonical Void provider is rejected.
- `absurd[T](panic(message))` works for arbitrary result types.
- Void retains ordinary nominal-data representation.
- The panic wrapper has the ordinary Void result ABI and ends in `Fatal`.
- Direct and first-class panic calls never execute their continuation.
- `Panic` on another function does not imply terminal control.
- CLI entry admission is owned by an explicit profile.
- interpreter and Wasm/JIT expose the same typed fatal outcome.
- stale interface, object, and linked schemas are rejected.
