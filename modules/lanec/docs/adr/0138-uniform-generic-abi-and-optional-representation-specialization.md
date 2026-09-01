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

Representation elaboration is one private operation inside Physical Lowering.
Its package interface is the ordinary executable-to-Physical-Program lowering
seam; conceptually the internal step is:

```text
construct_vmcfg(RuntimeAnfProgram, TargetAbi) -> VmcfgImage
```

The implementation may use private worklists, substitutions, interning tables,
callable-flow analyses, and strongly connected components. These are temporary
implementation state, not parallel outputs that consumers must understand or
verify against the program.

The resulting VM CFG contains the executable structure, one authoritative
physical contract for every runtime value, and explicit representation
adaptations. It may retain semantic type provenance while it is constructed,
but that provenance cannot become a second post-elaboration representation
policy. VM CFG finalization then owns canonical function identity, ARC,
physical slot allocation and Physical Program verification. WebAssembly
emission consumes only that verified program.

A separate Physical ANF is deliberately absent. The removed representation was
a shallow copy of Runtime ANF plus planner projections and had no verifier-owned
invariant distinct from the physical value metadata and operations already
required by VM CFG. If a future physical IR gains a genuinely independent
invariant, it requires a new architectural decision rather than reintroducing
the deleted mirror as migration scaffolding.

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
- Physical Lowering first collects closed demands and candidate-call edges from
  Runtime ANF, then solves one private immutable plan before emitting any VM CFG
  function body;
- the key is the semantic generic definition together with its complete
  canonical runtime arguments and callable ABI, modulo alpha-equivalence;
- each planned key reserves exactly one worker before body emission, and call,
  closure, and function emission can only query the completed plan;
- the generic implementation remains available for every open, indirect,
  unsupported, or recursively expanding use;
- a recursive SCC propagates a demand only when the recursive edge preserves
  the complete canonical argument vector; an edge that changes that vector
  stays generic, so recursive planning closes without fuel or size limits;
- disabling or deleting specialization changes performance only, never whether
  a valid program can be lowered or what it observes.

The specialization plan is not a public Physical ANF or a second
representation policy. It is private construction state owned by Physical
Lowering: the builder mutates its local catalogs, publishes the completed plan
to the emitter through lookup-only operations, and discards it after producing
the Physical Program.

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
3. Representation elaboration is private to the one Physical Lowering interface
   and does not expose planner, solution, recipe, or occurrence sidecars.
4. A physical value has one authoritative execution contract.
5. Semantic type provenance may be retained but cannot become a second
   representation producer.
6. Representation conversions are explicit program operations.
7. Each specialized key and each materialized structural callable adaptation
   produces at most one worker.
8. Generic nominal storage has one declaration-owned schema.
9. VM CFG, ARC-final VM CFG, physical-slot planning, the verified Physical
   Program, and Wasm remain distinct because each owns an independently
   necessary invariant.

## Consequences

- Correctness no longer requires a whole-program representation constraint
  graph or per-value specialization solution.
- Higher-kinded and CPS-generated parameters use the same generic evidence
  model as other polymorphic values. CPS identity does not create another
  representation policy.
- Optimization can be evaluated with Explore by comparing worker count,
  adapters, erase/unerase operations, and final code size, but those metrics do
  not decide semantic eligibility.
- No Physical ANF seam is retained because the removed form had no independent
  invariant beyond VM CFG physical contracts.
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
