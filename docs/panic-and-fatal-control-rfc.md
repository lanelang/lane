# RFC: Void-returning panic and explicit fatal execution

Status: Implemented

## Summary

Lane shall expose source-level fatal termination through the canonical Basic
interface:

```lane
module Basic.Io

import Basic.Data.Void.{ Void }

pub let panic : (String) -> Void ! Panic = builtin("%panic")
```

`Basic.Data.Void` continues to define `Void` and its eliminator as ordinary
Lane declarations:

```lane
module Basic.Data.Void

pub enum Void {}

pub fn[T] absurd(value : Void) -> T {
  match value {}
}
```

The result type, source effect, execution control, and host-visible outcome
remain separate facts:

- `Void` states that a successful call cannot produce a source value;
- `Panic` makes the possible fatal behavior visible to the type system and
  effect-aware optimization;
- `Fatal(message)` is the VM CFG and bytecode terminator with no normal
  successor;
- `Panicked(report)` is the typed outcome observed by an execution host.

Lane does not introduce a built-in bottom type, implicit bottom conversion,
Never-specific callable ABI, or result-polymorphic public panic. Expression
contexts obtain any required result explicitly through `absurd`:

```lane
fn first_or_panic(values : List[I64]) -> I64 ! Panic {
  match values {
    List::cons(value, _) => value
    List::empty => absurd[I64](panic("empty list"))
  }
}
```

The compiler recognizes `Basic.Data.Void.Void` through the same kind of fixed,
validated Basic ABI already used by tuple and list sugar and structural
derivation. No backend discovers Void by spelling, empty-enum shape, or runtime
layout.

This RFC is the authoritative implemented design.

## Motivation

The previous panic design was assembled from backend requirements instead of a
complete source-language model. It gave `%panic` the type:

```lane
(String) -> Unit ! Panic
```

and permits every built-in effect at an executable entry through a
`Builtin(_)` match. This creates two independent problems.

First, `Unit` is useful for a statement-oriented API but does not expose that
the canonical panic operation has no successful result. Code that needs a
value of another type cannot express the impossible branch through ordinary
Lane abstractions. Reintroducing a built-in Never type would solve that problem
by adding bottom elimination, but it would also require special typing,
representation, callable ABI, verification, codec, interpreter, and Wasm
rules. Lane already has a normal nominal empty type and a total eliminator in
Basic; duplicating them in the language core is unnecessary.

Second, effect flavor and execution support are different decisions. An effect
does not become executable merely because the compiler represents it with a
built-in constructor. The historical `Io`-only entry rule was a runner policy,
not a general effect theorem. Adding `Panic` required an explicit execution
policy, but the implementation widened the rule to every present and future
built-in effect instead.

The new model makes both choices explicit. Basic owns the public empty result,
the intrinsic owns fatal control, and an execution profile owns which closed
residual effects it can interpret.

## Goals

- Give panic an uninhabited successful result without a source-level bottom
  type or implicit coercion.
- Reuse the existing `Basic.Data.Void.Void` and `absurd` abstractions.
- Keep Void an ordinary nominal empty enum throughout every IR and backend.
- Keep `Panic` distinct from `Io`, recoverable exceptions, runtime failures,
  VM traps, and compiler defects.
- Make the fixed Basic ABI the sole owner of canonical Basic declaration
  identities and shape requirements.
- Make the intrinsic contract the sole owner of `%panic` parameters, result,
  effect, and fatal implementation.
- Make the selected execution profile the sole owner of executable-entry
  effect admission.
- Preserve identical fatal behavior, cleanup, messages, and typed outcomes in
  the interpreter and Wasm/JIT backends.
- Reject stale persisted contracts rather than interpreting them under the new
  source ABI.

## Non-goals

- A general source `Never` type or bottom-subtyping relation.
- Implicit conversion from `Void` to arbitrary result types.
- Treating every empty enum as a special control-flow or runtime type.
- Making `Panic` resumable or handleable by user code.
- Introducing a recoverable exception hierarchy.
- Classifying all runtime failures as Lane panics.
- Inferring terminal control from an effect annotation.
- Allowing every compiler built-in effect at every execution target.
- Making compiler backends import or inspect Basic source modules.

## Language model

### Void is ordinary nominal data

`Basic.Data.Void.Void` is an ordinary nominal enum with no constructors. Its
identity is not definitionally equal to any other empty enum. Functions may
accept it, return it, store it under generic type constructors, and mention it
in callable types:

```lane
fn identity(value : Void) -> Void {
  value
}
```

Such functions are well typed even though safe Lane code cannot construct an
argument. The runtime representation of an ordinary Void occurrence follows
the same nominal-data rules as every other empty enum. The representation
elaborator must not classify it as Unit, Never, or a no-result ABI.

An exhaustive match on Void has no alternatives:

```lane
match value {}
```

That expression has any declared result type because the scrutinee has no
possible source inhabitant. Elaboration lowers the empty match to ordinary
unreachable control. This is the implementation of `absurd`; it is not a
Void-specific compiler intrinsic.

### Panic returns Void

The canonical source signature is exactly:

```lane
(String) -> Basic.Data.Void.Void ! Panic
```

The result describes the normal return channel. `%panic` never produces a
normal result because its implementation terminates with `Fatal(message)`.
Consequently no Void object crosses the call boundary.

The signature remains useful in every result context through explicit
elimination:

```lane
absurd[Unit](panic("assertion failed"))
absurd[I64](panic("missing integer"))
absurd[Result[A, E]](panic("corrupt invariant"))
```

This pair is expressively equivalent to an answer-polymorphic fatal operation:

```lane
fn[T] panic_as(message : String) -> T ! Panic {
  absurd[T](panic(message))
}
```

Lane chooses the explicit pair as the canonical Basic interface. It gives the
panic binding one concrete nominal result, uses existing language constructs,
and avoids unconstrained result-parameter inference at discarded call sites.

### Panic is a sealed terminal effect

`Panic` is a compiler-provided atomic effect. It is non-algebraic, has no
operation dictionary, cannot be handled or resumed by source code, and remains
in semantic effect rows until runtime projection.

`Panic` means that a computation may intentionally terminate the current Lane
execution through the canonical fatal-control facility. It does not mean that
every annotated function terminates:

```lane
fn may_panic() -> Unit ! Panic {
  ()
}
```

Function effects are upper bounds. Optimizers must preserve calls carrying
`Panic`, but they must not infer no-return control from the effect alone. Only
the verified `%panic` intrinsic contract owns the stronger terminal fact.

`Panic` is not `Io`. It does not describe console output, file access, host
imports, or another observable operation merely used to report a message.
Likewise, resource exhaustion, malformed bytecode, compiler defects, invalid
unsafe primitive operands, host binding failures, native stack exhaustion, and
direct Wasm traps are not retroactively classified as source `Panic` effects.

### Recoverable failure is separate

Recoverable failure belongs to ordinary values such as `Result[T, E]` or to a
future explicitly designed algebraic exception effect. A recoverable operation
may transfer control to a user handler that supplies a result. Panic deliberately
does neither.

The name `Panic` therefore means unrecoverable termination of the current Lane
execution, not necessarily termination of the embedding process. An embedding
receives a typed panic outcome and decides how that failed execution relates to
other executions in the host process.

## Canonical Basic ABI

### One provider catalog

Lane already defines fixed Basic ABI providers for tuple and list syntax and
for structural derivation. This RFC extends and consolidates that model rather
than creating a panic-only dependency.

One compiler-owned Basic ABI catalog shall describe the canonical declarations
needed by language features. It includes at least:

- `Basic.Data.Tuple.Tuple` and `Tuple::tuple`;
- `Basic.Data.List.List`, `List::empty`, and `List::cons`;
- `Basic.Data.Void.Void`;
- the structural-derivation declarations already required by the checker.

The catalog stores symbolic, fully qualified provider requirements. One semantic
adapter owns their complete interpretation at the module-input seam. It resolves
identities against the complete imported interface closure plus the current
module, then certifies the corresponding public declarations and shapes before
expression checking. The adapter exposes an immutable identity catalog while
resolution is being assembled and a certified semantic catalog to later
consumers; neither state may be reconstructed outside the adapter. Public type
descriptors come exclusively from the Module Interface declaration projection
and are reused by final interface construction; the ABI adapter never rebuilds
them. For Void, certification proves:

- the declaration is the canonical `Basic.Data.Void.Void` nominal type;
- it is an enum;
- it has no type parameters;
- it has no variants.

Missing or incompatible demanded providers produce one source diagnostic owned
by this adapter. Consumers receive only catalog identities or certified semantic
results; they do not repeat name lookup, shape validation, or diagnostic policy.

When source symbols are lowered, the checked catalog produces a runtime
contract that carries the resolved canonical Void `TypeId`. Module-object
artifacts persist and fingerprint that contract. At the untrusted object
boundary, the same Canonical Basic ABI adapter certifies the declaration binding
and Buslane shape and returns an opaque certified contract; intrinsic validation
compares against its identity only. The linker does not reinterpret Basic module
paths, declaration names, or empty-enum shape as canonical ABI facts.

### Resolved identities cross the compiler

After validation, the compiler carries resolved declaration identities. Core
IR, module interfaces, module objects, linking, specialization, runtime
representation elaboration, VM CFG, and bytecode do not compare the strings
`"Basic.Data.Void"` or `"Void"` and do not rediscover empty enums.

The backend therefore depends on an ordinary resolved nominal type, not on the
Basic source tree. `--no-basic` compilation remains possible. A source module
that declares or consumes `%panic` must make the canonical Void provider
available through its explicit module input closure; unrelated source does
not acquire an implicit Basic dependency.

## Intrinsic contract

### Complete source contract

The intrinsic contract model must be able to reference a resolved canonical
nominal type. Adding `Void` to a primitive runtime-value enum is incorrect:
Void has nominal identity and ordinary data representation.

Conceptually, the verified `%panic` contract is:

```text
IntrinsicContract {
  name: "%panic",
  parameters: [Primitive(String)],
  result: CanonicalBasicType(Void),
  effect: Builtin(Panic),
  implementation: Fatal { message_parameter: 0 },
}
```

The Basic ABI identity catalog resolves `CanonicalBasicType(Void)`, and the
semantic adapter certifies that identity before materializing the complete
function type. The intrinsic table remains the sole owner of the contract; the
Basic source annotation is checked against it rather than becoming a second
signature producer.

### The Fatal implementation is not a result ABI

`Fatal { message_parameter: 0 }` completely describes how the compiler-owned
intrinsic is implemented: the selected parameter supplies the message to a
`Fatal` terminator. It is not a source type, effect, callable-result
representation, or public no-return annotation.

The `%panic` wrapper uses the ordinary callable ABI derived from its resolved
function type, including the ordinary nominal-data result ABI for Void. Its
body contains no `Return`; it ends with `Fatal(message)`. `Fatal` is valid in a
function with any declared result ABI because the terminator produces no
result and has no successor.

Direct calls, first-class calls, tail positions, adapters, and generic callers
continue to use ordinary callable machinery. No `CallNeverDirect`,
`CallNeverValue`, Never result tag, fake Void constant, or missing-result
fallback is introduced.

### No parallel reconstruction

Type checking, module-object validation, linking, function planning, and
lowering consume the same verified intrinsic contract. They must not
independently reconstruct String parameters, Void result, Panic effect, or
the fatal operation or its message operand. Any phase that cannot receive the
verified contract has the wrong interface.

## Executable entry and execution profiles

### Source requirements are not handlers

A selected source entry has the shape:

```text
() -> Unit ! E
```

where `E` is a closed residual effect row. Algebraic effects and open effect
parameters must be eliminated before execution. Non-algebraic residual effects
describe requirements of the execution target; their presence does not imply
that a source handler is missing.

The historical spelling `! Io` identifies one requirement. It is not a
universal effect ceiling. A source entry that may print and panic has the
honest type:

```lane
() -> Unit ! { Io, Panic }
```

Collapsing Panic into Io would lose effect orthogonality. Rejecting Panic while
the runtime implements it would make the canonical panic operation unusable at
an executable root.

### The execution profile owns admission

Each execution target owns an explicit profile describing the residual effects
it can interpret. The default Lane CLI profile supports at least:

- `Io`, through its runtime-import environment;
- `Panic`, through the compiler-owned fatal-control path.

External-effect admission follows the target's explicit host-binding policy.
A future built-in effect is rejected until a profile deliberately adds support.
The compiler must delete rules equivalent to `Builtin(_) => executable`.

Entry validation consumes the selected profile and the closed canonical effect
row. It reports every unsupported requirement structurally. Effect flavor,
built-in identity, and profile support remain distinct facts.

The lowered execution root is an effect-free runtime artifact. The profile's
interpretation is not represented as a user-visible algebraic handler and does
not introduce a root effect dictionary.

## Fatal control and execution outcomes

`Fatal(message)` remains a terminator in VM CFG and the Physical Program. It:

1. consumes one owned String;
2. has no CFG successor;
3. initiates the specified fatal cleanup;
4. produces a typed panic outcome.

The execution interface distinguishes intentional Lane panic from other
failure classes. Conceptually:

```text
ExecutionOutcome =
  | Returned
  | Panicked(PanicReport)
  | RuntimeFailed(RuntimeFailure)
```

`PanicReport` owns the source panic message and may later carry stable source
location or Lane stack information. `RuntimeFailure` retains typed host-link,
runtime-import, resource, engine, and trap failures. A command adapter may map
these outcomes to diagnostics and process statuses, but it must not flatten
them into constructor debug text or infer one class from a message or symbol.

The Wasm interpreter and JIT may use different internal unwind
mechanisms, but they must agree on:

- the exact panic message;
- the absence of a normal continuation;
- owned-value cleanup guarantees;
- the public typed outcome;
- command diagnostic and exit-status policy.

## Optimization contract

Before runtime effect projection, `Panic` is an ordinary nonempty semantic
effect. Therefore effect-aware optimization must not delete, duplicate, merge,
or reorder a panic-capable call as if it were total.

Only the `%panic` intrinsic contract's `Fatal` implementation permits a pass to
replace a call's normal continuation with fatal control. The following are
insufficient evidence:

- result type `Void`;
- any other empty enum;
- effect `Panic` on an arbitrary callable;
- source declaration name `panic`;
- runtime-import symbol spelling;
- function body result ABI.

After `%panic` has become `Fatal`, CFG analyses consume the terminator's normal
successor set, which is empty. Runtime projection may then remove source effect
syntax without erasing the emitted control-flow fact.

## Persistence and compatibility

Changing `%panic` from Unit to canonical Void changes its public source ABI,
module-interface fingerprints, module-object metadata, linked callable result
ABI, and Basic gitlink. Old and new declarations must never be treated as the
same contract merely because both implementations terminate with Fatal.

Implementation must audit every persisted compatibility owner:

- the Basic module-interface and module-object schema must reject the old
  Unit-returning intrinsic contract;
- linked artifacts must reject any persisted intrinsic or entry contract that
  their compatibility promise can no longer validate;
- the compiler-private Physical Program does not require a new Fatal form solely
  because the wrapper's ordinary result ABI changes, but the enclosing linked
  schema must advance if its persisted Wasm and manifest contract changes;
- textual inspection and canonical rendering must display the resolved Void
  result without inventing a primitive Void representation.

Exact version numbers belong to the implementation change, where the current
schema values and compatibility promises can be audited together. A migration
must never preserve an old number and rely on downstream type mismatch to
discover the semantic incompatibility.

## Diagnostics

Diagnostics must preserve the distinction between user input, provider ABI,
and compiler defects:

- a missing import or missing canonical Basic provider is a source/module
  dependency error;
- an incompatible `Basic.Data.Void.Void` declaration is an invalid Basic ABI
  diagnostic with the violated requirement;
- a `%panic` annotation using Unit, another nominal empty enum, the wrong
  parameter, or the wrong effect is an intrinsic signature mismatch;
- an unsupported closed entry effect is an execution-profile diagnostic;
- a verified intrinsic contract that changes or disappears in a later phase is
  a structured compiler defect;
- an invalid compiler-constructed Fatal instruction is a Physical Program
  verification failure.

No later phase may downgrade these failures into an unsupported-program string
or guess the original cause from rendered detail.

## Migration plan

1. Establish one resolved Basic ABI catalog and migrate existing tuple, list,
   Void, and structural-derivation provider lookup to consume it.
2. Extend the canonical intrinsic contract so its result can reference the
   resolved Basic Void declaration and its fatal implementation names the
   message parameter explicitly.
3. Change semantic checking and builtin synthesis to produce exactly
   `(String) -> Void ! Panic` from that contract.
4. Change Basic.Io to import Void and expose the new signature. Push the Basic
   commit before updating Lane's gitlink so CI can fetch the exact object.
5. Make linking, specialization, function planning, and lowering consume the
   verified contract without reconstructing its fields.
6. Emit the ordinary Void-result callable wrapper ending in Fatal and verify
   direct, first-class, adapter, and tail-position uses.
7. Introduce explicit execution profiles, migrate CLI entry validation, and
   remove wildcard built-in admission.
8. Advance affected persisted schemas and reject superseded contracts.
9. Update ADRs, context documentation, examples, diagnostics, and the existing
   fatal-control RFC to reflect the implemented design.

Each step must leave the compiler buildable. Temporary dual contracts,
result-shape fallback, name-based Void discovery, and silent acceptance of both
Unit and Void are forbidden.

## Verification

Black-box tests are the default evidence. The completed implementation must
cover at least:

- Basic exports exactly `(String) -> Void ! Panic`;
- `absurd[I64](panic(message))` typechecks in an I64 branch;
- statement and Unit contexts work through explicit `absurd[Unit]` where a
  Unit result is required;
- Unit, another empty enum, a non-String parameter, or another effect is
  rejected as the `%panic` declaration contract;
- missing and inhabited canonical Void providers receive their owned
  diagnostics;
- ordinary user empty enums remain nominally distinct and retain ordinary data
  representation;
- a pure function cannot call panic without carrying `Panic`;
- discarded panic evaluation survives semantic optimization;
- an arbitrary function annotated `! Panic` may return normally and is not
  rewritten as terminal;
- entries with `{ Io, Panic }` run under the CLI profile;
- unsupported residual effects are rejected by that profile;
- interpreter and Wasm/JIT return the same typed panic outcome and never run
  the continuation;
- module interfaces, module objects, linked artifacts, inspection text, and
  schema rejection follow the new contract;
- `--no-basic` compilation remains valid for source that does not use a
  canonical Basic-dependent feature.

Focused white-box tests are justified only for private facts that cannot be
observed through a public compiler or execution interface. They should prove
the complete verified intrinsic contract, the resolved canonical Void identity,
the Void-result wrapper ending in Fatal, and the absence of a normal CFG
successor. They must not lock incidental TypeId, FunctionId, SlotId, block
order, or instruction-table positions.

## Rejected alternatives

### Keep Unit as the canonical result

`Unit ! Panic` is type safe but intentionally loses the uninhabited successful
result. It forces fatal branches into statement-oriented source structure even
though Basic already provides the normal empty-type abstraction.

### Add a built-in Never type

Never would require a new language-wide bottom-elimination rule and dedicated
decisions in type inference, callable ABI, representation, codecs, verifier,
interpreter, and Wasm. That machinery is not justified when ordinary Void and
`absurd` already express the required source program.

### Expose answer-polymorphic panic directly

`[T](String) -> T ! Panic` is sound and corresponds to the usual exception
typing found in effect languages. The Void interface can derive it as
`absurd(panic(message))` while keeping the canonical public binding monomorphic
and result conversion explicit. Lane therefore does not require unconstrained
result inference or generic callable representation for the Basic panic value.

### Accept any empty enum as the intrinsic result

Structural emptiness is not nominal identity. Searching for an empty enum at a
use site would create multiple possible contracts and repeat inhabitation logic
across phases. The fixed Basic ABI selects exactly one canonical Void.

### Treat Void as a primitive runtime kind

Void is an ordinary Basic declaration used by generic data and structural
derivation. Giving it a primitive runtime kind would split its semantic and
representation ownership and recreate the former empty-enum/Never defect.

### Collapse Panic into Io

Fatal termination is not input/output. Collapsing the effects would make APIs
less precise and preserve the historical entry restriction by sacrificing
orthogonality.

### Make Panic a user handler effect

A resumable or recoverable operation has a different cleanup, continuation,
entry, and outcome contract. Lane can add such an exception abstraction
separately; it must not silently change fatal panic into recoverable control.

### Admit every built-in effect at entries

Compiler representation does not imply runtime support. Wildcard admission
would silently expand whenever a new built-in effect is added. An explicit
execution profile is the stable owner of target support.

## Supersession

This RFC supersedes the Unit-result portions of:

- `modules/lanec/docs/fatal-control-rfc.md`;
- `modules/lanec/docs/adr/0130-source-fatal-panic.md`;
- `modules/lanec/docs/adr/0131-panic-effect.md`;
- `docs/adr/0001-built-in-io-externs-and-host-seams.md`.

It also supersedes the `Io`-only entry wording in
`modules/lanec/docs/adr/0067-effect-erasure-before-bytecode.md` and the current
implementation rule that admits every built-in effect. The unaffected
ownership, cleanup, backend-parity, and typed-outcome decisions in those
documents remain in force.
