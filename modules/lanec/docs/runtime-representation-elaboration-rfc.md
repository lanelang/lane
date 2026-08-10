# RFC: Runtime representation elaboration and higher-kinded layout evidence

Status: Implemented

## Summary

Lane keeps `Type` as the semantic kind of ordinary values, including values
with distinct machine representations such as `I32`, `I64`, `F32`, `F64`,
references, callables, and `Unit`. It does not redefine `Type` to mean one
boxed runtime representation.

Before LoisVM lowering, one compiler-owned representation elaborator converts
every value type into a closed runtime ABI and the layout evidence needed to
operate on that ABI. Concrete types retain their natural machine
representations. A value whose representation remains abstract crosses the
seam as an erased payload accompanied by explicit layout evidence.

For an ordinary type parameter `T : Type`, the evidence describes the layout
of `T`. For a higher-kinded parameter `F : [Type] -> Type`, the evidence is a
layout constructor that maps evidence for `A` to evidence for `F[A]`. Concrete
type-lambda substitution reduces both the source type and its representation
evidence; symbolic calls preserve and forward both. No lowering phase may
guess that an unresolved type application is a reference.

Buslane remains the sole owner of source type correctness, kind checking,
type-lambda reduction, and definitional equality. LoisVM verifies only closed
execution invariants: physical representation, cleanup, ownership, callable
ABI, object shape, and the provenance and scope of layout evidence. It does
not implement a second F-omega typechecker.

## Motivation

Lane deliberately gives its numeric primitives exact end-to-end machine
semantics. `I32`, `I64`, `F32`, and `F64` are distinct members of `Type` and
lower respectively to `I32`, `I64`, `F32`, and `F64` execution
representations. In particular, F32 values are not widened through compiler,
artifact, runtime, or host boundaries. These decisions are specified by
[ADR 0124](adr/0124-utf8-string-and-byte-sequence-primitives.md) and
[ADR 0125](adr/0125-numeric-primitive-names-and-f32.md).

Ordinary generic values already expose the resulting representation
polymorphism. A function of type `[T](T) -> T` can be instantiated with a
scalar, reference, callable, or `Unit`. Lane handles this by pairing an erased
payload with a layout witness whenever `T` remains symbolic, while allowing a
concrete instantiation to use its natural representation.

The same rule is not currently complete for higher-kinded parameters. Given:

```lane
type Identity = type[T] => T
```

an unresolved application `F[A]` cannot be classified from the syntax of
`F[A]` alone:

```text
Identity[I32]  has the I32 representation
Identity[F64]  has the F64 representation
List[I32]      has a reference representation
```

A single fixed layout for `F` is insufficient, and classifying every
`Apply(Parameter(F), arguments)` as a reference is unsound. The representation
of the application is a function of the representation evidence for both the
constructor and its arguments.

The compiler also currently has more than one site that derives runtime
shapes. Callable finalization, data-schema construction, closure capture,
adapter construction, and slot classification must not independently
reconstruct the same representation decision. Representation elaboration
needs one owner and one interface.

## Goals

- Preserve `I32`, `I64`, `F32`, and `F64` as ordinary, definitionally distinct
  members of `Type` with their natural concrete execution representations.
- Give every concrete or symbolic value type one authoritative runtime ABI.
- Generalize Lane's existing erased-payload and layout-witness model to
  higher-kinded type applications.
- Make concrete elaboration and symbolic evidence passing observationally
  equivalent.
- Keep source type equality and higher-kinded type reduction out of LoisVM.
- Make callable ABIs and object member schemas consume finalized
  representation data instead of re-deriving it.
- Preserve exact ownership and cleanup information at every call, return,
  capture, projection, and data-construction seam.
- Retain a verifier strong enough to reject unsafe directly constructed or
  decoded bytecode images.

## Non-goals

- Replacing Lane's source kind `Type` with GHC-style representation-indexed
  source kinds.
- Boxing every primitive or nominal value in concrete code.
- Monomorphizing every generic definition.
- Adding runtime reflection, source type names, dynamic casts, or an `Any`
  type.
- Rechecking Buslane definitional equality in VM CFG or LoisVM bytecode.
- Preserving compatibility with bytecode that encodes the superseded abstract
  reference assumptions.
- Choosing speculative user-visible syntax for representation polymorphism.

## Language model

### `Type` is semantic, not representational

`Type` classifies ordinary Lane values. Membership in `Type` does not imply a
single physical width, register class, cleanup rule, or allocation strategy.
Definitionally distinct types may share a representation, and types of the
same kind may have different representations.

Examples include:

```text
Char != I32, although both use I32 + Trivial
F32  != I32, although both occupy 32 value bits
String and Bytes are distinct, although both use ByteSequence references
```

This separation is intentional. Semantic identity belongs to the type system;
execution representation belongs to representation elaboration.

### Concrete and symbolic elaboration

A concrete type is normalized at its representation-observation boundary and
elaborated to its natural ABI:

```text
I32        -> I32 + Trivial
F64        -> F64 + Trivial
Unit       -> no runtime value
String     -> I32 + OwnedRef + ByteSequenceValue
callable   -> I64 + OwnedCallable + CallableValue
```

A symbolic value type is elaborated to the erased ABI already used by Lane:

```text
T : Type   -> I64 + OwnedErased + layout(T)
```

The layout evidence controls retain, release, erase, unerase, storage, and
projection. It is runtime representation evidence, not a source type identity.
Definitionally distinct types may legitimately use the same layout evidence.

### Higher-kinded layout evidence

Representation evidence follows the source kind only as far as required to
produce layouts. Conceptually:

```text
evidence(Type)                    = Layout
evidence([K1, ..., Kn] -> Type)   =
  (evidence(K1), ..., evidence(Kn)) -> Layout
```

For the common unary case:

```text
F  : [Type] -> Type
F# : Layout -> Layout
```

The evidence for an application is therefore:

```text
layout(F[A]) = F#(layout(A))
```

Examples:

```text
Identity#(A#)    = A#
List#(A#)        = Reference(List)
ConstantI64#(A#) = I64
```

The notation describes an internal interface, not source syntax. The runtime
encoding must be an immutable, image-owned, kind- and arity-checked layout
recipe or equivalent descriptor. It must not be an arbitrary user callable,
must not inspect source type identities, and must not be forged by Lane code.

Representation evidence may itself close over other representation evidence
when a type lambda captures outer parameters. The representation elaborator
owns that closure construction. Callers see only the evidence required by the
elaborated callable ABI.

### Concrete substitution

When a higher-kinded parameter is replaced with a concrete type lambda, the
compiler performs source beta reduction in Buslane and reduces the associated
representation evidence at the representation seam.

For example:

```text
F := type[T] => T
F[I32]                 -> I32
F#(layout(I32))        -> layout(I32)
```

In a monomorphic representation context, the resulting value uses the concrete
I32 ABI. At a call or object boundary whose declaration retains a generic ABI,
the value still crosses as `OwnedErased`; the call supplies `Identity#`, and
the object stores the resulting `layout(I32)` beside that member. A later
whole-occurrence specialization may replace that complete generic boundary
with an I32-specific one, but partial shape specialization is not valid.

Such specialization is an optimization of the evidence-passing elaboration,
not an alternate semantic path. Removing it must not change observable program
behavior.

### Symbolic forwarding

When `F` remains an outer parameter, its representation evidence remains an
explicit hidden input or capture. Calls, closures, adapters, recursive
bindings, and nested generic forwarding must propagate `F`'s type substitution
and `F#` together.

No phase may reconstruct missing evidence from:

- the spelling or identity of `F`;
- the source effect corresponding to a companion;
- the fact that a value occupies an I32 slot;
- a default assumption that applied type constructors produce references; or
- the representation of a different application of the same constructor.

If neither concrete elaboration nor in-scope evidence is available, lowering
reports a structured compiler defect for missing representation evidence.

## Representation elaborator

Representation elaboration is a deep compiler module at the seam between
verified Buslane types and VM CFG construction. Its interface accepts a type
in a verified metadata context and returns one complete representation result.
Callers do not separately ask for representation, cleanup, semantic value
kind, witness requirements, or result ABI.

Conceptually, the result contains:

```text
RuntimeRepresentation =
  Unit
  | Concrete(ValueAbi)
  | Erased(ValueAbi, RepresentationEvidence)
```

`ValueAbi` contains every physical fact required by later stages, including:

- slot representation;
- cleanup and ownership class;
- semantic runtime value kind;
- evidence kind and provenance when erased; and
- the exact result ABI when the value is returned.

The concrete MoonBit structure and method names are implementation details,
but the interface must return the complete decision atomically. A caller must
not be able to obtain a representation while independently deriving its
cleanup or semantic kind.

The module owns:

- weak-head or full normalization required to expose the representation;
- substitution before representation observation;
- concrete primitive and nominal classification;
- evidence construction and application;
- evidence capture requirements;
- materialization of callable parameter and result ABIs; and
- materialization of data and environment member schemas.

The module does not own source typechecking, diagnostics for invalid source
types, effect specialization policy, ARC dataflow, or bytecode verification.

## Callable ABI

Every callable ABI is derived from ABI-final operands and results. ARC
finalization may turn a borrowed input into an owned retained copy, so the ABI
must be interned only after all consume, borrow, retain, erase, and unerase
operations have selected the final operands. Subsequent physical-slot
allocation may renumber those operands or coalesce slots only when their full
`SlotMetadata` is identical; storage allocation cannot change an ABI.

Direct calls, indirect calls, tail calls, callable adapters, runtime imports,
and function returns consume the same `ValueAbi` projection. No call form may
reconstruct parameter compatibility from source type syntax.

For a symbolic higher-kinded callable, the hidden evidence inputs are part of
the callable ABI. A concrete adapter may remove evidence inputs only after
representation elaboration proves that every affected value ABI has become
concrete. Adapter capture and body lowering consume the same final
substitution and evidence environment.

## Data and environment schemas

Data and environment schemas are built from instantiated field and capture
types, never from raw declaration payload types.

The required order is:

```text
source field or capture type
-> nominal, existential, and callable substitution
-> normalization at the representation head
-> representation elaboration
-> MemberSchema
```

A concrete member records its exact representation, cleanup, and semantic
value kind. An erased member records `OwnedErased` and identifies the exact
stored evidence governing that payload. For a member of type `F[A]`, this is
the evidence for `F#(A#)`, not a fixed witness for `F` and not the witness for
some other application of `F`.

Objects store every evidence value required to retain, project, and destroy
their erased members after the constructing scope has returned. A member
schema refers to those stored evidence values by verified ordinal or an
equivalent closed identity.

Nominal data-family identity remains a semantic classification for tags and
matching. A generic declaration has one stable erased member schema: every
representation-dependent source member is stored as `OwnedErased`, and each
object stores the exact applied `LayoutValue` for that member. A specialized
shape may use concrete members only when the complete construction, match, and
projection chain is specialized together; an isolated concrete shape is not a
valid replacement for the generic schema.

## Verification responsibilities

### Buslane verifier

Buslane verifies:

- source kinds and parameter scopes;
- type application and type-lambda reduction;
- definitional equality and consumability;
- expression and pattern typing; and
- the absence of free or unknown type parameters.

Buslane is the sole proof owner for these facts.

### Representation elaboration checks

Representation elaboration rejects compiler-generated states in which:

- a type has no runtime representation when one is required;
- a symbolic type lacks in-scope evidence;
- evidence is applied at the wrong kind or arity;
- a substitution and its evidence environment disagree; or
- a requested adapter cannot preserve the source value semantics.

These are structured compiler defects, not unsupported-source diagnostics.

### LoisVM verifier

LoisVM verifies:

- every slot and result has a legal physical representation and cleanup pair;
- every owner is consumed exactly once and every borrow remains within its
  owner's lifetime;
- erased payloads are accompanied by live evidence of the required kind;
- erase, unerase, projection, capture, and return preserve evidence
  provenance;
- callable values agree with the complete callable ABI at direct and indirect
  call sites;
- data and environment instructions use the exact declared object shape;
- stored witness ordinals are in range and agree with erased members; and
- decoded images cannot forge scalar, callable, data, environment, layout, or
  erased value categories.

LoisVM does not verify source type applications, source nominal arguments, or
F-omega definitional equality. A bytecode image can be memory-safe and
well-formed without being a proof that it originated from a valid Lane source
program. If source-level authenticity is ever required at the bytecode trust
boundary, it requires a separately designed typed certificate rather than a
duplicate source typechecker inside LoisVM.

## Effect companions

Effect companions and ordinary higher-kinded type parameters currently reach
LoisVM through related but partially separate paths. They must converge on the
same representation-evidence interface whenever their applications produce
Lane values.

The static residual effect remains source semantic information and may
participate in definitional equality and effect lowering. It is not runtime
layout evidence and must not be consulted by LoisVM lowering to guess Unit,
reference, or dictionary representation.

Concrete effect-companion type lambdas elaborate normally. Symbolic effect
companions preserve their explicit representation evidence. This RFC does not
change the source-level effect ABI; it removes the remaining alternate source
of runtime representation decisions.

## Required invariants

1. Every source type fact has one owner in Buslane.
2. Every runtime representation fact has one owner in representation
   elaboration.
3. Every finalized callable occurrence has exactly one complete ABI.
4. A type substitution and its representation evidence are created,
   captured, forwarded, and consumed together.
5. Concrete and symbolic elaborations are observationally equivalent.
6. No unresolved type application is classified from raw syntax alone.
7. No source effect is used as a runtime layout witness.
8. No object schema is built from an unsubstituted field or capture type.
9. No callable ABI is built before ARC has selected its final operands, and
   physical-slot allocation preserves their complete ABI metadata.
10. LoisVM rejects missing, forged, out-of-scope, or provenance-incompatible
    evidence without reconstructing source type equality.

## Alternatives considered

### Make `Type` one boxed representation

Lane could redefine `Type` to mean a GC-managed boxed value, analogous to
GHC's ordinary lifted `Type`, and place unboxed primitives in separate
representation-indexed kinds. This would make `F : [Type] -> Type` uniformly a
reference-producing constructor.

This option is rejected for the current language. It would either box Lane's
ordinary I32, I64, F32, and F64 values or move them out of the generic kind
used by existing programs. Both choices conflict with the accepted exact-width
primitive and generic-erasure model and require a broad source-language, Basic,
FFI, artifact, and optimization redesign.

Representation-indexed source kinds remain a possible future language, but
they require a separate RFC and migration rather than an implicit backend
restriction.

### Always box unresolved higher-kinded applications

The compiler could give every unresolved `F[A]` a uniform heap box and unbox
at concrete boundaries. This is sound and simpler than higher-kinded layout
evidence, and may remain a valid implementation fallback.

It is not the primary design because Lane already has erased payloads and
layout-directed ownership for ordinary parameters. Always boxing only
higher-kinded applications would introduce a second generic representation
policy, add allocation at otherwise allocation-free forwarding boundaries,
and make first-order and higher-kinded polymorphism unnecessarily asymmetric.

### Whole-program monomorphization

Specializing every generic definition would ensure that all code-generation
types are concrete. This is sound but conflicts with separate compilation,
increases code size, and makes higher-order generic values and external module
interfaces depend on whole-program reachability. Specialization remains an
optimization over the evidence-passing semantics, not its correctness model.

### Full source types in LoisVM bytecode

LoisVM could persist source type applications, type lambdas, quantifiers, and
kind information and re-run definitional equality in the bytecode verifier.
This is rejected because it duplicates Buslane's proof responsibility,
expands the bytecode format with facts that execution does not need, and makes
the lowest-level verifier depend on the complete source type language.

A small layout-evidence calculus is not a second F-omega language: it can only
describe and apply runtime layouts and is verified by kind, arity, scope, and
provenance.

### Treat every unresolved application as a reference

This is rejected as unsound. `Identity[I32]`, `Identity[F32]`, and similar
legal type-lambda applications directly contradict the assumption.

## Persistence and compatibility

Layout-constructor evidence and complete callable evidence ABIs change the
persistent bytecode selected by linked-program schema version 12. Any later
change to callable ABI metadata, member-schema evidence identity, or semantic
value kinds must advance that enclosing schema again. The decoder rejects the
immediately preceding version. Old entries in build caches are rebuilt; there
is no compatibility decoder that guesses missing evidence.

Buslane and module artifact versions change only if their persisted structures
change. The source language and public module dependency model do not change.
Build systems need only include the normal artifact-format version and compiler
semantic fingerprint in cache validity.

## Implementation outline

1. Correct callable finalization so every call-site ABI is built from final
   materialized slots after ARC ownership operations.
2. Correct data-schema construction so it consumes fully substituted and
   normalized field types.
3. Introduce the single representation-elaboration interface and migrate
   slots, results, calls, adapters, captures, data members, and environment
   members to it.
4. Define immutable image-owned higher-kinded layout evidence and its checked
   application operation.
5. Propagate type substitutions and evidence through generic calls, closures,
   adapters, recursive groups, and nested forwarding as one environment.
6. Store exact applied evidence for erased object members and projections.
7. Replace the general `AbstractReferenceValue(parameter)` assumption with
   closed concrete shapes or explicit erased evidence provenance.
8. Update LoisVM verification, interpreter execution, Wasm lowering,
   disassembly, canonical encoding, decoding, and the bytecode schema version.
9. Delete superseded representation inference paths and verify that no source
   effect or raw type syntax participates in runtime layout selection.

Each step must leave its owned IR verifiable. Temporary compatibility paths
that preserve both old and new representation owners are not permitted.

## Verification plan

Black-box source examples are the primary regression surface. They must cover:

- concrete `Identity[I32]`, `Identity[F32]`, `Identity[I64]`, and
  `Identity[F64]` values;
- a symbolic `[F : [Type] -> Type, A]` forwarding chain;
- `F[A]` in callable parameters and results;
- `F[A]` stored in structs, enum payloads, recursive nominal data, and closure
  environments;
- nested applications such as `F[G[A]]`;
- a type lambda that captures an outer type parameter;
- a reference-producing constructor such as `List` beside
  representation-varying `Identity`;
- direct, indirect, adapted, captured, recursive, and tail calls;
- equivalent results in the LoisVM interpreter, Wasm interpreter, and JIT;
  and
- exact I32/F32 bit preservation through erase and unerase.

Invalid or white-box verifier tests must cover states that source programs
cannot construct reasonably:

- missing in-scope evidence;
- wrong evidence kind or arity;
- substitution/evidence disagreement;
- an erased member naming the wrong stored witness;
- a callable value paired with the wrong evidence ABI;
- forged reference, data, environment, callable, and layout categories; and
- every failure returning no partially generated or executable image.

The repository gate is `moon test --target native`, followed by the complete
valid and invalid examples integration gate. Snapshot tests should inspect
small complete representation results rather than searching instruction arrays
or reconstructing layout-ID storage conventions.

## Consequences

- Lane preserves its existing source-level numeric and generic orthogonality.
- Concrete scalar and reference code keeps natural machine ABIs.
- Symbolic polymorphism pays an explicit evidence cost that specialization can
  remove.
- Higher-kinded forwarding becomes compositional instead of relying on
  reference guesses or whole-program specialization.
- Representation logic moves behind one deep interface, reducing duplicated
  decisions across lowering modules.
- LoisVM remains a strong execution-safety trust boundary without becoming a
  second source typechecker.
- The bytecode format and build caches require a deliberate versioned
  migration when the design is implemented.
