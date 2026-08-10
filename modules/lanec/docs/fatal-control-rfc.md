# RFC: Void-returning fatal control

Status: Implemented

## Summary

Lane will model source-level fatal termination as a compiler intrinsic rather
than as an ordinary host runtime import. The Basic API becomes:

```lane
module Basic.Io

import Basic.Data.Void.{ Void }

pub let panic : (String) -> Void ! Io = builtin("%panic")
```

`Void` remains the ordinary zero-constructor enum owned by Basic. Lane adds no
source-level `Never` primitive, implicit bottom conversion, bottom subtyping,
or expected-type-directed panic elaboration. Code that needs a value after a
fatal call uses the existing explicit eliminator:

```lane
import Basic.Data.Void.{ absurd }
import Basic.Io.{ panic }

fn impossible() -> I64 ! Io {
  absurd(panic("unreachable"))
}
```

The compiler derives an execution-level `Never` Result ABI when a callable's
normalized result is a nominal enum with no constructors. `Never` is a result
contract, not a source type, slot representation, layout, or runtime value.
The `%panic` intrinsic lowers to a dedicated `Fatal(message)` control
terminator. Both production backends report
`ExecutionError::Fatal(message)`, perform the existing fatal cleanup, and never
execute a continuation.

This design removes source panic from the Runtime Import ABI. It requires no
host registration, no conventional `panic` symbol, and no recognition of
`Basic.Data.Void` by module or declaration identity.

This RFC supersedes ADR 0130's statement-oriented Unit-returning extern design.
ADR 0130 remains as a short historical record and points here for the current
contract.

## Motivation

The current implementation deliberately chose a minimal contract:

```lane
pub let panic : (String) -> Unit ! Io = extern("panic")
```

The host binding never returns Unit, but Unit remains visible in the source
type and in the Runtime Import ABI. This is safe and complete for discarded
statement-position calls, yet it assigns three unrelated responsibilities to
one host-call model:

1. the source type must describe an impossible normal result;
2. compiler control flow must know that no continuation exists; and
3. the embedding must receive a structured fatal outcome.

An ordinary Runtime Import is the wrong owner for the first two facts. Runtime
Imports describe foreign functions that synchronously return one declared
direct value or fail at the trusted host boundary. Source `panic` is instead a
language-defined control operation with backend-independent behavior.

Basic already contains the appropriate source-level empty type:

```lane
pub enum Void {}

pub fn[T] absurd(value : Void) -> T {
  match value {}
}
```

Changing only the panic annotation to Void would still be incomplete. The
current extern contract accepts only direct host values, and the execution ABI
has no way to say that a callable cannot return normally. Treating Void as Unit
or Reference would manufacture a runtime representation for a value that can
never exist. Recognizing the spelling `Basic.Data.Void` would also make a
library declaration the owner of compiler control semantics.

The design therefore separates the source proof, execution contract, and
terminal outcome while connecting them at explicit compiler boundaries.

## Goals

- Give `panic` an honest source result that cannot be constructed.
- Keep `Void` as an ordinary Basic enum with the ordinary explicit `absurd`
  eliminator.
- Represent non-returning callable results explicitly in compiler and bytecode
  ABIs without inventing a Void value layout.
- Represent fatal termination as dedicated control flow rather than a failed
  source Runtime Import.
- Preserve `Io` observability and evaluation ordering.
- Preserve identical fatal messages, cleanup, and terminal instance state in
  the LoisVM interpreter and Wasm/JIT backend.
- Keep ordinary Runtime Import failures distinct from intentional source fatal
  termination.
- Support direct, first-class, indirect, captured, and forwarded uses of the
  panic callable through the same callable ABI.
- Give each derived fact exactly one owner and make later phases consume it.
- Remove the runtime symbol and host-registration convention from the Lane
  language contract.

## Non-goals

- Adding a source-level primitive `Never` type.
- Making Void definitionally equal to every type.
- Adding implicit `Void -> T` conversion or general subtyping.
- Reintroducing expected-type-directed expression elaboration.
- Making fatal termination recoverable or handleable in Lane.
- Modeling panic as an algebraic effect operation.
- Using panic to report ordinary recoverable host or library errors.
- Inferring fatality from a source name, Runtime Import symbol, module path, or
  declaration identity.
- Proving every semantically uninhabited recursive type. The initial rule is
  intentionally limited to a normalized nominal enum with zero constructors.
- Preserving compatibility with persisted artifacts that use superseded
  callable-result or terminator encodings.

## Terminology

### Void

The ordinary Basic nominal enum with zero constructors. Void is a source type
of kind `Type`. It participates in generics, aliases, containers, structural
derivation, and explicit empty-match elimination like any other nominal enum.

Void has no distinguished identity in the compiler. Any normalized nominal
enum declaration with zero constructors has the same uninhabited-result
property.

### Uninhabited result

A source callable result whose weak-head-normalized type identifies a nominal
enum declaration with an empty constructor family. This is a checked compiler
fact derived from declaration metadata.

The initial definition does not attempt recursive emptiness inference. For
example, a recursive enum with one constructor is not classified as an
uninhabited result even if no finite source expression can construct it.

### Never Result ABI

The execution contract stating that a callable has no normal return and
produces no result value. It is written `Never` in this RFC.

Never exists only in result position. It is not a `RuntimeValueKind`, cannot
describe a parameter or slot, has no layout witness, and cannot be stored in a
data object or environment.

### Fatal terminator

The compiler and bytecode control operation that consumes a String message,
has no successor, and terminates the execution with a fatal outcome. It is
written `Fatal(message)` in this RFC.

### Fatal execution outcome

The embedding-visible `ExecutionError::Fatal(message)` produced after backend
cleanup. It is intentional program termination, not a Runtime Import
resolution or invocation defect.

## Source language contract

### Basic API

Basic exposes the non-generic callable:

```lane
pub let panic : (String) -> Void ! Io = builtin("%panic")
```

The result is not polymorphic. This preserves ordinary synthesis for
`panic(message)` in statement position and does not require an expected result
type to infer a hidden type argument.

A caller that needs a different result type performs explicit empty-type
elimination:

```lane
fn require_value() -> String ! Io {
  absurd(panic("no value"))
}
```

This is the same elimination rule used for every other Void value. Panic does
not introduce an alternate coercion or typing relation.

### Effect

Panic retains the closed latent effect `Io`. Fatal termination is observable:
it changes whether later work executes and produces an embedding-visible
diagnostic. An optimizer must not delete, duplicate, merge, speculate, or
reorder a panic call as if it were pure.

`Io` does not make panic recoverable. Fatal termination is not an algebraic
operation, supplies no resume continuation, and cannot be handled by source
code.

### Closed builtin validation

`%panic` is a closed compiler intrinsic with one structural signature
contract. Its complete declaration type must satisfy all of the following:

- it is monomorphic;
- it is a function with exactly one `String` parameter;
- its normalized result identifies a nominal enum with zero constructors; and
- its latent effect is exactly `Io`.

The declaration supplies this complete type before validation. The compiler
does not choose a result from contextual expectations, overload `%panic`, or
solve a type variable from a call site.

The validator inspects declaration structure, not the symbol identity of
`Basic.Data.Void`. A renamed Basic module, another standard library, or a local
empty enum can satisfy the same intrinsic contract. If a formerly empty enum
gains a constructor, validation fails rather than silently retaining the Never
ABI.

### First-class use

Panic remains an ordinary first-class Lane callable after its declaration is
checked. It can be stored, passed, captured, selected, and forwarded:

```lane
fn invoke_abort(abort : (String) -> Void ! Io) -> Void ! Io {
  abort("stop")
}
```

Direct and indirect calls must be observationally equivalent. The compiler may
inline a known panic callable into a Fatal terminator, but correctness must not
depend on direct-call recognition.

## Uninhabited-result classification

The checked type system owns the source fact. At every callable-result
observation boundary it:

1. reduces transparent aliases and type-lambda applications to weak-head
   normal form;
2. resolves the nominal enum declaration;
3. reads the declaration's authoritative constructor family; and
4. classifies an empty family as an uninhabited result.

The classification is structural and conservative. It does not search source
text, consult Basic-specific compiler tables, infer from an absent runtime
layout, or perform a recursive fixed point over data declarations.

Only the callable's outer result is classified. These types remain inhabited
and use their ordinary representations:

```text
Array[Void]
Option[Void]
List[Void]
() -> Void
```

For example, an empty Array contains no Void element but is itself a valid
reference value. A function value returning Void is also a valid callable
value; only invoking it has no normal result.

## Compiler IR

### Checked representation

The checked intrinsic retains its exact source function type. Its intrinsic
identity records fatal control explicitly. A later phase must not recover that
identity from the declaration name or from the fact that the result is empty.

Conceptually:

```text
CheckedBuiltin =
  ...
  | Panic
```

The concrete enum and field names remain implementation details.

### Buslane

Buslane must represent fatal control explicitly. A conceptual form is:

```text
Fatal(message : Expr)
```

The verifier requires the message to have type String, records the operation as
effectful fatal control, and gives it no normal result path. Buslane does not
encode `Basic.Data.Void` in the operation.

If the intrinsic is preserved as a first-class callable, elaboration may
materialize a compiler-owned function body whose result type is the original
empty enum and whose body terminates with Fatal. Direct and first-class uses
must consume the same derived Never callable ABI.

### ANF and VM CFG

ANF makes message evaluation explicit before fatal termination. VM CFG lowers
the operation to a terminator with no successor:

```text
evaluate message
Fatal(message_slot)
```

Calls whose callee has a Never Result ABI also terminate their current control
path. They do not allocate a destination slot or create a successor that waits
for a result.

The CFG representation may use dedicated direct and indirect never-call
terminators or one terminator parameterized by call target shape. It must not
encode a Never call as an ordinary call instruction followed by reachable
instructions.

## Callable and result ABI

The complete function result contract becomes:

```text
ResultAbi =
  Unit
  | Value(ValueAbi)
  | Never
```

The three cases mean:

- `Unit`: the function returns normally without a result slot;
- `Value`: the function returns normally with one value of the complete ABI;
- `Never`: the function cannot return normally.

Never is not interchangeable with Unit. They share zero physical result slots,
but differ in control behavior, verifier obligations, call form, optimization,
and backend lowering.

Callable ABI identity includes the complete Result ABI. A callable returning
Never cannot be dynamically invoked through an ABI expecting Unit or Value.
Direct calls, packed callables, adapters, captured functions, indirect tables,
and runtime dynamic ABI checks consume the same canonical result projection.

Function-result classification is owned by the existing compiler
representation seam. Other phases must not independently rediscover empty
enums or construct Never ABIs from source syntax.

## LoisVM bytecode

### Result encoding

LoisVM adds a distinct persisted tag for `ResultAbi::Never`. It does not encode
a representation, cleanup category, semantic value kind, layout witness, or
destination for that case.

### Fatal terminator

Bytecode adds a Fatal terminator that consumes one live owned String slot and
has no successor. It is valid only in a bytecode body; it is not a
source-visible Runtime Import.

The terminator transfers the message owner into the execution failure path.
The backend copies its UTF-8 payload into the host execution error, releases
the consumed Lane owner exactly once, and then performs the remaining fatal
frame and root cleanup. The verifier, interpreter, and Wasm backend consume
this one ownership rule; Fatal never borrows a message beyond the terminator.

### Never calls

A call to a Never callable is represented by a terminating call form. The
verifier checks:

- the direct or dynamic callee ABI result is exactly Never;
- environment, witness, parameter, and callable shapes match normally;
- the call has no destination;
- the current block has no successor after the call; and
- no Return terminator is used to claim a Never result was produced.

A function whose Result ABI is Never may end in Fatal, a Never call, or another
verified non-returning control form. Every reachable block must terminate, but
no reachable block may return normally.

### Complete-image verification

The bytecode verifier, not the decoder, owns these semantic invariants. A
directly constructed image and a decoded image receive identical checks.
Decoder logic owns only tags, framing, lengths, and version validity.

## Runtime behavior

### Interpreter

Executing Fatal decodes the String message, records
`ExecutionError::Fatal(message)`, releases the message according to the
terminator ownership contract, and unwinds through the existing cleanup-capable
fatal path. The execution instance becomes terminal and cannot be resumed or
executed again.

### Wasm and JIT

The Wasm compiler lowers Fatal through a LoisVM-internal runtime service, not a
source Runtime Import. The service records the same typed fatal outcome in the
execution failure state. Generated Wasm then transfers to the backend's
non-returning failure exit; it must not continue after the service call even if
the physical host-call ABI itself returns zero Wasm values.

The internal service symbol and transport are backend-private. They do not
appear in Lane source, Runtime Import descriptors, or the public embedding
registry.

Interpreter mode and JIT mode must produce the same message, cleanup behavior,
terminal instance state, and observable output prefix.

### Embedding and CLI

The public execution boundary continues to expose:

```text
ExecutionError::Fatal(message)
```

Lane CLI renders the dedicated panic diagnostic already established for that
typed outcome. It does not expose a Runtime Import symbol, bytecode terminator,
internal service name, backend trap, or debug constructor representation.

## Runtime Import boundary

Source panic produces no Runtime Import entry. Embeddings do not register a
`panic` symbol, and runtime loading cannot fail because that symbol is absent.

Ordinary extern bindings retain the existing contract and failure model:

```text
RuntimeImportFailure(symbol, message)
```

An embedding defect or host resource failure may still terminate execution,
but it remains distinct from a deliberate Fatal instruction produced by the
source program.

After migration, remove `RuntimeBinding::fatal_string` and
`RuntimeImportFailure::Fatal` if no non-source consumer remains. Do not retain
them as compatibility fallbacks or alternate panic paths.

## Optimization and control-flow laws

Fatal is effectful and non-returning:

- it is never dead merely because its result is unused;
- it cannot commute across observable operations;
- it cannot be duplicated or merged without a proof preserving message and
  evaluation count;
- expressions after it on the same path are unreachable;
- ownership cleanup is computed from a terminal edge, not a normal successor;
  and
- inlining, devirtualization, specialization, and adapter elimination must
  preserve the Never Result ABI.

A Never callable and a Unit callable are not interchangeable even when both
use zero physical result slots. Physical slot equality is not observational or
control-flow equivalence.

## Persistence and compatibility

This design changes persisted execution contracts. Every affected current-only
format receives a version bump rather than a decoder fallback:

- compiler artifacts that persist the new fatal IR form;
- linked-program artifacts that contain the resulting bytecode image; and
- the linked-program schema that owns LoisVM bytecode compatibility; its
  bytecode payload gains the Never result tag and Fatal/never-call terminator
  tags.

Encoders emit only the new canonical form. Decoders reject previous versions
with their existing structured unsupported-version errors. No decoder rewrites
a Unit-returning panic Runtime Import into Fatal, recognizes a `panic` symbol,
or guesses Never from a missing result slot.

Basic's public interface also changes from Unit to Void. Downstream source that
uses panic only as a discarded statement continues to typecheck. Source that
explicitly expects Unit must either discard the call as a statement or update
its control flow. Value-producing use must call `absurd` explicitly.

## Migration plan

1. Add black-box source tests for statement-position panic, explicit `absurd`
   elimination into multiple result types, first-class forwarding, and the
   absence of a panic Runtime Import.
2. Extend canonical callable result classification and persisted Result ABI
   with Never. Add verifier and codec tests before producing the new form.
3. Add checked, Buslane, ANF, VM CFG, and bytecode fatal control forms with one
   lowering path.
4. Implement interpreter and Wasm/JIT Fatal execution through the common typed
   `ExecutionError::Fatal` boundary.
5. Add `%panic` closed-builtin validation and cover invalid parameter, result,
   effect, and polymorphic declarations.
6. Change Basic panic to the Void-returning builtin and update its public tests
   and documentation.
7. Remove command runtime registration, source panic Runtime Import fixtures,
   `RuntimeBinding::fatal_string`, and `RuntimeImportFailure::Fatal` if they have
   no remaining consumer.
8. Bump the affected artifact schemas, including the linked-program schema
   that owns bytecode compatibility, regenerate interfaces, and update ADR
   0130 plus the built-in Io/extern host-seam ADR.
9. Run the full native, Basic, examples, CLI, interpreter, JIT, artifact,
   decoder, and integration gates.

Each step must preserve a single executable panic path. No transition may keep
both the builtin Fatal path and the source Runtime Import path as fallbacks.

## Verification plan

### Source and type checking

- The canonical Basic declaration typechecks.
- `%panic` rejects Unit, inhabited enums, primitives, wrong parameters,
  missing Io, additional effects, and polymorphic declaration types.
- A transparent alias of an empty enum is accepted after head normalization.
- A local empty enum is accepted without importing Basic.
- Adding a constructor to the result enum makes validation fail.
- `absurd(panic(message))` typechecks at two unrelated result types without
  expected-type-directed panic elaboration.

### Compiler IR and optimization

- Checked and Buslane snapshots contain Fatal rather than ExternBinding or
  Runtime Import metadata.
- Direct, first-class, forwarded, captured, and indirect calls use the same
  Never callable result.
- Code after Fatal is unreachable and absent from the final reachable CFG.
- Effect-sensitive optimization does not delete or reorder Fatal.
- No phase reconstructs Never by scanning Basic symbols or runtime imports.

### Bytecode and persistence

- Never round-trips through every persisted Result ABI position.
- Fatal and direct/indirect never-call terminators round-trip canonically.
- The verifier rejects a destination on a Never call, a normal successor, a
  Return from a Never body, a Fatal with a non-String slot, and a dynamic ABI
  mismatch.
- Directly constructed and decoded invalid images receive the same verifier
  diagnostics.
- Old artifact and bytecode versions are rejected; no compatibility rewrite is
  attempted.

### Execution

- Interpreter and Wasm/JIT return exactly `ExecutionError::Fatal(message)`.
- Neither backend executes the continuation after direct or indirect panic.
- Owned locals, captures, roots, and the message follow the specified fatal
  cleanup contract.
- The CLI prints the dedicated panic report without LoisVM constructors,
  internal symbols, or backend trap text.
- Loading and running panic requires no public Runtime Registry binding.
- Ordinary failing Runtime Imports still report their symbol and remain
  distinguishable from Fatal.

## Alternatives considered

### Keep the Unit-returning extern

This is the current safe minimum, but its source result and control behavior do
not agree. It also makes a conventional runtime symbol part of a language-level
operation and hides non-returning control behind a generic import-failure path.

### Make the extern return Basic.Data.Void

Changing only the source annotation leaves the host and callable ABIs unable to
express non-returning behavior. Hard-coding the Basic declaration identity
would reverse the compiler/library dependency and reject equivalent local empty
enums. Mapping Void to Unit or Reference would invent a value representation.

### Add a source primitive Never

A primitive Never can model bottom directly, but it adds a special source type,
questions about generic layout evidence, and either an implicit bottom
conversion or explicit elimination parallel to the existing Void eliminator.
Lane already has a sufficient ordinary empty type, so the source primitive is
unnecessary once execution Never is kept result-only.

### Give panic a polymorphic result

`[T](String) -> T ! Io` is a conventional bottom signature, but a discarded
statement call leaves `T` unconstrained unless inference uses contextual
expectations or the caller supplies an explicit argument. It also requires a
special polymorphic intrinsic for an operation that produces no value. The
non-generic Void result plus explicit `absurd` is more predictable.

### Implicitly coerce Void to every type

This improves ergonomics but introduces a new type-compatibility relation and
makes ordinary expression checking context-sensitive. Explicit `absurd`
already states the proof and works uniformly for every Void-producing
expression.

### Infer that every empty-enum extern is fatal

The result type proves that normal return is impossible, but it does not make
an ordinary foreign declaration the appropriate owner of Lane fatal control.
Such a rule would still route the language operation through public host
registration and conflate deliberate source termination with embedding
failure. A future host ABI may add explicit non-returning imports separately.

### Model panic as an algebraic Abort effect

An algebraic effect is handleable and supplies effect-system control semantics.
The operation specified here is intentionally unhandleable and terminates the
execution instance. Recoverable exceptions or abort handlers are separate
language features.

## Acceptance criteria

- Basic exposes exactly `(String) -> Void ! Io = builtin("%panic")`.
- Source Void remains an ordinary zero-constructor enum with explicit `absurd`;
  there is no source Never primitive or implicit bottom conversion.
- The compiler validates `%panic` structurally without recognizing a Basic
  module, declaration identity, value name, or host symbol.
- Canonical callable results include Unit, Value, and Never, with one owner for
  their projection.
- Never is result-only and never receives slot, layout, cleanup, or value-kind
  metadata.
- Fatal and Never calls are terminal CFG and bytecode operations with no normal
  successor or result destination.
- Direct and first-class panic calls are observationally equivalent.
- Interpreter and Wasm/JIT return the same typed Fatal outcome and perform the
  specified cleanup.
- Source panic produces no Runtime Import and requires no embedding
  registration.
- The legacy runtime-import panic path and unused compatibility helpers are
  deleted rather than retained as fallbacks.
- Persisted schemas are versioned explicitly and malformed Never/Fatal programs
  are rejected by the verifier.
- ADR 0130 and the system-wide built-in Io/extern seam ADR are updated when the
  implementation replaces the current contract.
- Black-box source, artifact, executable, CLI, interpreter, JIT, and integration
  tests cover the complete contract.

## Consequences

The source language gains a truthful panic result without gaining a special
bottom type or implicit typing rule. Basic owns the user-facing empty type;
the checked compiler owns uninhabited-result classification; callable ABI owns
the Never execution contract; control-flow IR owns Fatal; and the runtime owns
the final typed execution outcome.

The implementation is larger than changing one library annotation because it
removes a false abstraction rather than extending it. Once complete, the
language and VM become simpler to explain: panic is fatal control, Runtime
Imports are foreign calls, Void is an empty source type, and Never is only the
absence of a normal callable result.
