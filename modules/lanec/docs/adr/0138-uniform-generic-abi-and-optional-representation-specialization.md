# Uniform generic ABI and optional representation specialization

Status: accepted; implementation tracked by ISS-390.

## Context

Lane's generic calling convention passes an erased value together with the
layout evidence required to retain, release, store, and recover that value.
Higher-kinded parameters pass layout constructors. This evidence-passing ABI
is sufficient to lower open generic code without knowing its future concrete
instantiations.

The representation-specialization implementation nevertheless made complete
whole-program physical planning a prerequisite for VM CFG construction. It
materialized semantic callable-flow facts, representation demands, constraint
solutions, data-family variants, callable-contract graphs, adapter recipes,
and a second physical program before emission. These values were mostly
different projections of the same program. Each projection then needed a
verifier to prove that it still agreed with the others.

That architecture confused an optimization with the correctness model. It
also interpreted "one fact has one producer" as "every derived observation is
a persistent compiler model." A derived observation may instead be computed
inside the module that owns the authoritative input and consumed immediately.

## Decision

The canonical generic ABI is Lane's correctness baseline. Every well-formed
Runtime ANF program can be lowered through that ABI without representation
specialization.

- A concrete value uses its canonical natural ABI.
- An open `T : Type` value uses the erased payload ABI and explicit `layout(T)`
  evidence.
- An open higher-kinded application uses the in-scope layout constructor and
  argument evidence.
- Generic nominal storage uses its declaration-owned uniform schema. A
  representation-dependent member is stored through the erased ABI together
  with the evidence required to operate on it.
- Missing evidence is a structured compiler defect. No stage guesses a layout
  from source spelling, an effect, or an outer machine representation.

Representation elaboration is one deep module. Its external interface is
conceptually:

```text
elaborate(RuntimeAnfProgram, TargetAbi) -> VerifiedPhysicalProgram
```

The implementation may use private worklists, substitutions, interning tables,
callable-flow analyses, and strongly connected components. These are temporary
implementation state, not parallel outputs that consumers must understand or
verify against the program.

The resulting physical program contains the executable structure, one
authoritative physical contract for every runtime value, and explicit
representation adaptations. It may retain semantic type provenance for
diagnostics and verification. Such provenance cannot be used after elaboration
to choose a different physical contract. VM CFG emission consumes the verified
physical program mechanically.

Representation adaptation is a structural operation owned by the elaborator:

```text
adapt(source_contract, target_contract, value)
```

Equal contracts require no operation. Concrete/erased mismatches insert the
corresponding erase or unerase operation. Callable mismatches construct a
wrapper from the complete source and target callable contracts. A directly
invoked wrapper may be fused into the call; a first-class escape materializes
one canonical worker for the structural source/target pair. Call sites supply
their own captures. Adapter identity is not rediscovered from emitted VM CFG.

Representation specialization is an optional program rewrite over this
correct generic model:

- a closed canonical runtime-ABI key may create one concrete worker;
- the pass rewrites actual definitions and calls rather than publishing a
  representation-demand model for later lowering;
- the generic implementation remains available for every open, indirect,
  unsupported, or recursively expanding use;
- a recursive call may reuse an already selected stable key; a transformation
  that produces an unbounded sequence of keys stays generic;
- disabling or deleting specialization changes performance only, never whether
  a valid program can be lowered or what it observes.

The initial implementation does not specialize nominal storage families.
Generic containers retain their uniform declaration schema. Non-escaping
aggregates may be scalar-replaced without introducing another nominal family.
A future storage specialization must be an independently removable program
rewrite with an observable benefit; it must not become a prerequisite for
generic lowering.

Callable ABI interning remains a necessary execution invariant. Recursive
callable ABIs may therefore use nominal identities in the physical ABI owner.
That graph describes executable call compatibility only; it does not carry
semantic callable flow, specialization demand, source binder scopes, or
per-call representation choices.

## Required properties

1. Removing representation specialization leaves a correct compiler.
2. Generic lowering does not depend on a reachable closed instantiation.
3. Representation elaboration has one external interface and does not expose
   planner, solution, recipe, or occurrence sidecars.
4. A physical value has one authoritative execution contract.
5. Semantic type provenance may be retained but cannot become a second
   representation producer.
6. Representation conversions are explicit program operations.
7. Each specialized key and each materialized structural callable adaptation
   produces at most one worker.
8. Generic nominal storage has one declaration-owned schema.
9. VM CFG, ARC-final VM CFG, physical-slot planning, bytecode, and Wasm remain
   distinct because each owns an independently necessary invariant.

## Consequences

- Correctness no longer requires a whole-program representation constraint
  graph or per-value specialization solution.
- Higher-kinded and CPS-generated parameters use the same generic evidence
  model as other polymorphic values. CPS identity does not create another
  representation policy.
- Optimization can be evaluated with Explore by comparing worker count,
  adapters, erase/unerase operations, and final code size, but those metrics do
  not decide semantic eligibility.
- The physical-program seam is justified only by its closed execution
  invariant. If it merely mirrors Runtime ANF plus sidecars, it must be
  deepened or removed.
- Existing planner/catalog/graph implementations are migration code, not the
  accepted architecture. ISS-390 replaces them instead of layering another
  compatibility path over them.

## Rejected alternatives

### Whole-program physical planning as a correctness requirement

Rejected because open generic code already has a complete evidence-passing
ABI. Making lowering depend on a solved closed-world demand graph couples
correctness to an optimization and multiplies representations of one program.

### Treat every derived fact as a persistent owner

Rejected. The owner of an authoritative type, callable ABI, or physical
contract may derive local observations inside its implementation. Persistence
is justified only when another module needs the fact through a stable
interface.

### Specialize every generic definition

Rejected because separate compilation, higher-order values, open recursion,
and code size require a stable generic implementation.

### Use semantic type equality as physical identity

Rejected because definitionally distinct types may share an ABI and one
semantic generic definition may have generic and specialized implementations.
Semantic provenance is useful, but the selected physical contract remains
authoritative after elaboration.
