# RFC: Runtime representation elaboration and higher-kinded layout evidence

Status: Implemented for the canonical generic ABI and higher-kinded evidence.
The representation-specialization architecture is defined by
[ADR-0138](adr/0138-uniform-generic-abi-and-optional-representation-specialization.md)
and implemented by ISS-431.

## Summary

Lane's source kind `Type` is semantic. Its members may use different machine
representations: `I32`, `I64`, `F32`, `F64`, references, callables, erased
generic values, and `Unit` all belong to `Type`.

Runtime representation elaboration turns verified Runtime ANF into physical VM
CFG operations and value contracts. Open generic code uses one canonical
evidence-passing ABI:
an erased payload is accompanied by the layout evidence needed to operate on
it. Higher-kinded parameters carry layout constructors. Concrete code uses its
natural ABI, and explicit structural adaptations connect concrete and generic
boundaries.

This generic elaboration is complete without whole-program specialization.
Representation specialization may clone closed concrete workers and rewrite
their calls, but it is an optional optimization. Removing it must not change
whether a valid program lowers or what the program observes.

## Semantic and physical facts

Buslane owns source type correctness, kinds, substitution, type-lambda
reduction, and definitional equality. Runtime representation elaboration owns
the selected execution contract. The Physical Program verifier checks only execution invariants:
physical representation, cleanup, ownership, callable ABI, object shape, and
layout-evidence provenance.

Definitionally distinct source types may share a physical representation:

```text
Char != I32, although both use I32 + Trivial
F32  != I32, although both occupy 32 value bits
String != Bytes, although both use ByteSequence references
```

Conversely, values of the same source kind may require different physical
representations. No later stage may infer representation from kind membership
alone.

Semantic type provenance may remain attached to a physical program for
diagnostics and verification. It is not a second representation owner. Once
elaboration selects a physical contract, VM CFG emission cannot reinterpret
that provenance to choose another contract.

## Canonical generic ABI

Concrete values use their natural physical contract:

```text
I32        -> I32 + Trivial
F64        -> F64 + Trivial
Unit       -> no runtime value
String     -> I32 + OwnedRef + ByteSequenceValue
callable   -> I64 + OwnedCallable + CallableAbiId
```

An open ordinary parameter uses an erased payload and explicit evidence:

```text
T : Type -> OwnedErased + layout(T)
```

The evidence controls retain, release, storage, erasure, unerasure, and
projection. It identifies a layout operation, not a source type. Two source
types may legitimately reuse the same layout evidence.

Generic definitions, generic nominal storage, indirect calls, and separately
compiled interfaces remain correct using this ABI. A closed instantiation is
not required for their construction or lowering.

## Higher-kinded layout evidence

Representation evidence follows the source kind only as far as required to
produce a layout:

```text
evidence(Type) = Layout
evidence([K1, ..., Kn] -> Type) =
  (evidence(K1), ..., evidence(Kn)) -> Layout
```

For a unary constructor:

```text
F  : [Type] -> Type
F# : Layout -> Layout
layout(F[A]) = F#(layout(A))
```

Examples:

```text
Identity#(A#)    = A#
List#(A#)        = Reference(List)
ConstantI64#(A#) = I64
```

A layout constructor is immutable compiler-owned evidence. It is not an
arbitrary Lane callable, cannot inspect source type identity, and cannot be
forged by source code. A constructor may capture other evidence when a type
lambda closes over outer parameters.

Concrete type-lambda substitution reduces both the semantic application and
its evidence:

```text
F := type[T] => T
F[I32]          -> I32
F#(layout(I32)) -> layout(I32)
```

Symbolic forwarding preserves the type argument and its evidence together.
Calls, closures, adapters, recursive bindings, nominal arguments, and nested
generic forwarding must propagate both. If neither a concrete reduction nor
in-scope evidence exists, lowering reports a structured compiler defect.

No phase may reconstruct missing evidence from:

- source spelling or nominal identity;
- a source effect or residual effect;
- the fact that a value occupies an I32 or reference slot;
- a default assumption that type applications produce references; or
- evidence belonging to another application of the same constructor.

## Generic nominal storage

A generic nominal declaration has one stable declaration-owned storage schema.
Representation-dependent members use the erased ABI and store the exact
applied evidence needed to retain, project, and destroy the member after the
constructing scope returns.

The construction order is:

```text
source field or capture type
-> nominal, existential, and callable substitution
-> head normalization
-> canonical generic representation elaboration
-> member contract
```

Closed source arguments do not silently create another nominal family. The
initial architecture deliberately keeps generic storage uniform. A
non-escaping allocation may later be scalar-replaced without changing nominal
family identity. Any future specialized storage scheme must be an optional,
independently removable program rewrite.

## Representation elaboration

Representation elaboration is private to Physical Lowering. The package accepts
an admitted executable program and returns a verified Physical Program;
internally it projects Runtime ANF and target ABI facts directly into VM CFG.
The Physical Program is the compiler-private input to WebAssembly emission, not
a persisted artifact or execution platform.

The constructed VM CFG contains:

- executable program structure;
- one authoritative physical contract for each runtime value;
- explicit erase, unerase, and callable-adaptation operations;
- declaration-owned object schemas;
- finalized callable contracts required by VM CFG calls; and
- enough provenance for structured compiler defects and Explore observations.

The module may internally use normalization caches, substitutions, evidence
environments, callable-flow analyses, interning tables, work queues, and SCCs.
These are implementation details. It does not expose a representation-demand
plan, constraint graph, solution, adapter-recipe catalog, or occurrence
sidecar that another module must keep synchronized with the program.

VM CFG finalization validates and canonicalizes this physical image before ARC,
slot allocation, Physical Program construction, and verification. A separate
Physical ANF is not retained: the removed form duplicated the same executable
structure and contracts without owning another necessary invariant.

## Structural adaptation

One structural operation adapts a value between physical contracts:

```text
adapt(source_contract, target_contract, value)
```

- Equal contracts require no operation.
- Concrete-to-erased and erased-to-concrete crossings insert explicit erase or
  unerase operations using the authoritative evidence.
- Callable contracts are adapted contravariantly in parameters and covariantly
  in results.
- A future directly invoked callable adaptation may fuse into the call only by
  consuming the same complete structural recipe.
- A first-class escape materializes one canonical worker for the complete
  source and target callable contracts; each occurrence supplies its own
  captures.

Physical slot equality alone is insufficient. Equal-width values with
different ownership, object shape, callable ABI, or semantic adaptation
requirements are not interchangeable.

Recursive callable contracts form one finite nominal graph owned by
representation elaboration. A node is reserved before nested callable
positions are elaborated, and coinductive graph equivalence owns invocation
compatibility, structural adaptation, and worker sharing. A second ABI-only
graph would duplicate the same recursive fact. Semantic callable flow, source
binder scope, specialization demand, and worker selection remain outside this
graph.

## Optional representation specialization

Specialization is an optimization over the canonical generic program:

1. Before emitting VM CFG bodies, collect closed calls and generic-candidate
   call edges from Runtime ANF.
2. Use the semantic generic definition and complete canonical runtime arguments
   and callable ABI as the specialization key. Alpha-equivalent arguments share
   one key.
3. Solve the finite demand graph. A recursive SCC propagates only stable edges
   that preserve the complete argument vector; a changing recursive edge uses
   the generic implementation.
4. Reserve exactly one worker for every selected key and publish the completed
   private plan.
5. Emit calls, closures, generic functions, and workers by querying that plan.
   Emission cannot add demands, select fallback, or create another worker.
6. Run ordinary cleanup to remove dead evidence and adaptations.

The generic implementation remains available for open, indirect, unsupported,
or recursively expanding uses. A recursive call may reuse a stable existing
key. A transformation that keeps generating new keys stays generic. This is a
termination rule for an optional rewrite, not a global representation proof
required by lowering.

Specialization does not produce a second representation policy. The worker is
checked against the same physical contracts and explicit adaptation operation
as generic elaboration. Disabling the pass affects only generated code.
The completed plan is private construction state rather than a public IR seam;
after construction it exposes only lookup and is discarded with the lowering
operation.

## Verification responsibilities

Buslane verifies source kinds, binders, application, definitional equality,
expression typing, and absence of free parameters.

Representation elaboration rejects compiler-generated states in which:

- a required value lacks a physical contract;
- symbolic data lacks in-scope layout evidence;
- evidence has the wrong kind, arity, or provenance;
- a substitution and evidence environment disagree; or
- structural adaptation cannot preserve the complete source and target
  contracts.

The Physical Program verifier checks representation and cleanup pairs, ownership and
borrow lifetime, callable ABI compatibility, object shape, layout-evidence
scope, and compiler-internal program invariants. It does not reimplement
Buslane type equality.

## Effect companions

An effect companion is an ordinary higher-kinded representation input after
selective CPS. Its static residual effect remains semantic information and is
not runtime layout evidence. Concrete companions reduce normally; symbolic
companions forward explicit layout-constructor evidence. CPS names and source
effect spelling never participate in representation selection.

## Required invariants

1. The canonical generic ABI can lower every valid Runtime ANF program without
   representation specialization.
2. Every source type fact has one semantic owner.
3. Every runtime value has one authoritative physical contract.
4. Type substitutions and representation evidence are forwarded together.
5. Concrete and symbolic generic elaborations are observationally equivalent.
6. Generic nominal storage has one declaration-owned schema.
7. Every physical conversion is explicit.
8. VM CFG construction is the sole destination of elaborated physical
   contracts; finalization does not reselect them from semantic types.
9. Removing specialization changes performance only.

## Persistence

The source language does not change. Persisted schema versions change only
when the encoded physical contracts or instructions change. Compiler-private
planning structures are not persisted and therefore cannot justify a schema
change by themselves.

## Verification plan

Black-box source programs are the primary evidence. They cover:

- concrete and symbolic identity constructors over all scalar ABIs;
- higher-kinded forwarding in parameters, results, captures, and nominal data;
- generic nominal values constructed in one scope and consumed in another;
- direct, indirect, recursive, adapted, and escaping callables;
- effect companions under different answer and residual scopes;
- interpreter, Wasm interpreter, and JIT agreement; and
- the complete corpus through the canonical generic path without a
  specialization prerequisite.

White-box tests are reserved for evidence scope, canonical ABI interning,
adapter structural identity, and VM CFG verifier invariants that cannot be
observed through a source program.

Explore records code size, callable-adapter workers, erase/unerase operations,
and indirect calls. These metrics evaluate optimization quality; they never
decide whether a valid program is accepted. ISS-363 owns any future comparison
against an independently removable specialization rewrite.
