# Compiler optimization priorities

This document records the optimization opportunities exposed by a complete
`lane explore` report for the Basic test entry. It is a prioritized engineering
plan, not a language specification and not a set of permanent numeric budgets.
The measurements identify missing facts and transformations; future work must
re-measure the same boundaries instead of tuning limits until one snapshot
looks smaller.

## Current reproducible comparison

The comparison was recorded on 2026-08-28 from the pre-milestone Lane commit
`75e2bdd73b444493d798b555dbc603749ae65b14` and the post-transformation commit
`eeca63d24accca34a6cdc49a7cac8637ceabdf4c`. Both use pinned Basic
`807f78b4bd3106b1223c13884849b317f831e285`, the Wasmoon dependency family at
`0.12.6`, Apple Silicon running macOS 26.5.2, and MoonBit nightly 2026-08-26.
The programs were loaded from committed repository inputs with
`--lib-dir basic --no-basic`.

Explore is the owner-produced structural observation boundary. The tables come
from typed scale facts; no IR or Wasm text was searched to reconstruct counts.
The Coroutine Scheduler is unchanged by this local aggregate transformation:
it remains at 60 Physical functions, 349 Physical instructions, 414 slots, 101
Wasm functions, 8,346 Wasm instructions, and 480 Wasm locals.

| Basic metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Core-optimized functions / nodes | 146 / 3,956 | 146 / 3,956 | 0 / 0 |
| Selective-CPS functions / nodes | 286 / 4,757 | 286 / 4,757 | 0 / 0 |
| Runtime ANF functions / nodes | 254 / 7,272 | 254 / 7,263 | 0 / -9 |
| Initial VM CFG functions | 382 | 381 | -1 |
| Initial VM CFG instructions / values | 3,953 / 6,239 | 3,932 / 6,214 | -21 / -25 |
| Initial direct / indirect calls | 450 / 150 | 451 / 148 | +1 / -2 |
| Initial closures / environments | 362 / 383 | 361 / 381 | -1 / -2 |
| Physical functions / instructions | 382 / 4,594 | 381 / 4,573 | -1 / -21 |
| Physical slots | 4,045 | 4,030 | -15 |
| Physical erase / unerase operations | 330 / 149 | 327 / 146 | -3 / -3 |
| Physical retain / release operations | 372 / 286 | 372 / 286 | 0 / 0 |
| Callable ABI count | 121 | 121 | 0 |
| Wasm functions / imports | 490 / 3 | 489 / 3 | -1 / 0 |
| Wasm instructions / locals | 72,967 / 4,803 | 72,672 / 4,782 | -295 / -21 |
| Wasm table entries | 365 | 363 | -2 |
| Wasm `if` / `unreachable` instructions | 3,357 / 486 | 3,344 / 485 | -13 / -1 |

The focused public example proves the ownership boundary directly. Its two
effectful constructor payloads execute once in source order, yet the final VM
CFG has no object shape, closure, environment, or indirect call. The Basic
comparison shows the same rewrite crossing Runtime ANF and reducing physical
functions, instructions, slots, representation bridges, and final Wasm. Its
explicit retain/release counts do not move, so this milestone does not claim an
ARC optimization that it did not perform.

Three warm-process invocations at each commit produced these wall-clock ranges:

| Boundary | Scheduler before | Scheduler after | Basic before | Basic after |
| --- | ---: | ---: | ---: | ---: |
| Explore through Wasm plus report rendering | 0.04-0.05 s | 0.04-0.05 s | 0.74-0.76 s | 0.74-0.75 s |
| Complete compile, JIT load, and execution | 0.16 s | 0.16 s | 1.94-1.95 s | 1.92-2.00 s |
| Complete compile, interpreter load, and execution | 0.04 s | 0.03-0.04 s | 0.69-0.71 s | 0.69-0.71 s |

The CLI does not persist the raw Wasm produced by `run`, so these measurements
do not derive a fictional standalone JIT or execution time by subtraction.
They establish one compiler-pipeline boundary and two complete engine
boundaries. The timing ranges overlap; the demonstrated result is structural,
not a claimed throughput improvement.

## Historical baselines

Measurements from 2026-08-11 covered the deleted semantic-runtime and bytecode
architecture. They included 702-731 physical functions, 5,933-6,453 physical
instructions, 845-876 Wasm functions, and 129,753-134,655 rendered Wasm
instructions for an earlier Basic revision. They remain useful evidence for why
callable-flow and representation specialization were introduced, but they are
not a baseline for the current raw-Wasm pipeline.

Explore Protocol v6 now provides owner-produced aggregate metrics and preserves
function provenance at identity-owning stages. Tree stages remain
aggregate-only, and ordinary compilation does not construct observations. These
metrics are evidence, not optimization policy: decisions must not depend on
observed function IDs, rendered text, machine-specific timing, or numeric growth
heuristics.

## Priority one: remove structural expansion

### 1. Summarize immutable top-level values to weak-head normal form

Delivered by ISS-410. `CoreAnalysis` is the sole producer of cycle-aware,
conservative literal and constructor head facts through pure aliases and local
`Let` spines. Known-match reduction consumes this fact rather than inspecting a
top-level definition's syntax. Effectful spines and cycles remain unknown.

Callable identity deliberately remains with the interprocedural callable-flow
owner. Adding callables to the static-head summary would duplicate a richer
fact rather than deepen this analysis.

### 2. Replace peephole devirtualization with callable-flow analysis

Delivered on 2026-08-11. VM CFG now computes one exact whole-image callable-flow
fixed point across aliases, block edges, immutable aggregate fields, globals,
known function inputs, and known function results. Environment, witness, and
ordinary argument facts cross direct and closed indirect calls. Closed singleton
facts become direct calls.
Environment ABI elimination consumes the same fact and is rejected before
rewriting when any use requires a packed callable. The implementation has no
reference-count restriction, numeric budget, profitability score, speculative
rewrite, or fallback path.

Function-table pruning is now an exact downstream consumer. After lowering, it
starts from the entry and initializer and retains the transitive closure of
direct calls, tail calls, function constants, and closure construction. It
uses no reference-count or size policy.

### 3. Specialize concrete runtime representations and cancel adapters

Truly polymorphic code needs layout witnesses and erased values. A call whose
type arguments and companion witnesses are concrete should not retain the same
runtime plumbing merely because it passed through a generic definition.

The correctness baseline is the Canonical Generic ABI from ADR-0138. Generic
functions and generic nominal storage must lower correctly when representation
specialization is disabled. Specialization is then an optional program rewrite
that is useful only when it removes concrete ABI work. It must:

- propagate the concrete layout through the specialized body;
- cancel matching erase and unerase operations;
- eliminate constant witness arguments and captures;
- canonicalize identity adapters and compose adjacent adapters;
- create at most one worker for a closed canonical ABI key;
- leave open, indirect, unsupported, and recursively expanding uses generic;
- rewrite actual definitions and calls rather than publishing planner output
  for lowering to consume; and
- remain removable without changing valid-program acceptance or behavior.

The optimization owns representation specialization. Effect specialization and
source type substitution remain separate semantic operations. Generic nominal
storage initially stays declaration-owned and uniform; non-escaping aggregates
may be scalar-replaced without introducing specialized nominal families.

Structural callable adaptation is part of representation elaboration, not
specialization. A direct invocation may fuse the conversion; only first-class
escape materializes a worker. The worker is keyed by the complete structural
source and target contracts, and function-table processing does not rediscover
its identity from emitted instructions.

Earlier implementations reduced Scheduler adapter and bridge counts but did so
through a persistent Callable Instance Plan, Representation Constraint Graph,
specialized data-family catalog, Recursive Callable Contract Graph, and
structural Physical ANF. Those measurements remain useful historical baselines;
the architecture is superseded because lowering depended on the optimization.
ISS-390 first restores independently correct generic lowering and deletes the
parallel models. ISS-363 and ISS-368 then own optional CPS-aware specialization
and its measured optimization results.

### 4. Trust verified Physical Program facts in the Wasm compiler

Physical Program verification already proves global initialization order, rejects
duplicate initialization, and requires complete normal initialization. The Wasm
compiler nevertheless emits runtime checks around every global initialization
and borrow and emits a second completeness scan in the entry wrapper.

The Physical Program verifier should remain the sole owner of these static invariants.
Wasm compilation may consume a successfully verified image without repeating
them. Dynamic checks whose result depends on runtime data, such as bounds,
allocation failure, and indirect-call ABI identity, remain required.

Delivered on 2026-08-11. Successful verification now produces one canonical
`GlobalLifecyclePlan`; initializer state is a table-order prefix rather than a
set of Boolean flags. Interpreter and Wasm execution consume that plan. Wasm
`InitGlobal` and `BorrowGlobal` no longer emit initializer, duplicate,
initialized-read, or completeness guards. The linked-program schema advances
to 15 because the verifier now rejects non-canonical initialization order.

### 5. Make instance-global cleanup data-driven

Normal and exceptional cleanup currently unroll one conditional release per
global. Replace the generated linear code with a compact shared loop over the
Instance Root Table and cleanup metadata. The loop must preserve reverse
initialization order and the cleanup guarantees of ADR-0113. Removing the
redundant normal-path completeness scan and sharing cleanup should make entry
lifecycle code independent of the number of globals.

Delivered on 2026-08-11. Wasm root cells shrink from 16 bytes to 8 bytes. Each
owned root adds one packed 4-byte cleanup descriptor, while trivial roots add
none. A single 65-instruction cleanup helper and 11-instruction entry wrapper
serve both one and 64 owned roots in the structural regression. Programs with
no owned roots emit neither the helper nor cleanup exception scaffolding.

### 6. Measure profitability in lowering-relevant units

The current partial-evaluation score counts Core nodes and assigns fixed source
costs to calls, branches, and allocations. It cannot see that a small Core
expression may generate multiple closures, layout witnesses, ARC operations,
or thousands of Wasm instructions.

The semantic refactor that broadens inlining from atom-only substitution to
effect-directed application reduction is specified separately in
[Effect-directed application reduction and inlining](effect-directed-inlining-rfc.md).
That refactor keeps semantic eligibility independent from the profitability
model described here.

The Core optimizer no longer uses source-node weights or numeric work and
growth budgets. Its immutable `InlinePlan` compares complete contextually
reduced candidates, executes each accepted call site once, and replans newly
exposed calls only after cleanup. Future lowering-aware profitability may
account for:

- generated callable and environment count;
- direct versus indirect ABI;
- erased representation bridges;
- aggregate allocation and projected ownership;
- expected ARC work;
- retained versus eliminated function bodies.

Any future model must compare complete before and after plans. It must not
change semantic legality or reintroduce a traversal budget as a hidden
optimization policy.

## Priority two: remove residual allocation and ownership work

### 7. Propagate constructors and scalar-replace aggregates

Delivered by ISS-411. Core optimization now removes a local known-constructor
allocation only after one lexical traversal proves that every use is a
destructuring match, no whole value escapes, no nested function or recursive
group captures it, and no existential binder is opened. Payloads are bound at
the original constructor point, preserving strict left-to-right, exactly-once
evaluation. Unsupported uses retain the original aggregate; there is no
fallback representation and no downstream escape analysis.

The pinned Basic result is intentionally modest: one Physical function, 21
Physical instructions, 15 slots, and 295 Wasm instructions disappear. The
focused example reaches zero object shapes. This is the correct proof boundary,
not a promise that every aggregate is scalar-replaceable.

### 8. Intern generated shape destructors

This is not a current scheduled optimization. The earlier claim that 126
functions contained 72 distinct bodies came from the deleted backend and from
rendered-text comparison. The current Basic image has 84 object shapes and
attributes 18,847 Wasm instructions to object operations, but those aggregate
facts do not prove duplicate destructor semantics. A future proposal must first
add owner-produced structured destructor-plan identity and demonstrate actual
duplication; it must not infer sharing from rendered bodies.

### 9. Preserve erased payload and witness contracts across ABI boundaries

ISS-413 investigated whether the post-milestone Basic totals—327 erasures, 146
unerasures, and 2,659 Wasm instructions attributed to erasure—contained local
inverse bridges or duplicate static witnesses. A complete-contract experiment
changed neither Basic nor the coroutine scheduler. The remaining bridges cross
generic calls, aggregate storage, or dynamic callable boundaries; they are the
canonical generic ABI rather than local VM CFG redundancy.

`ValueMetadata.erased_companion` remains the payload/witness relation, erasure
instructions remain the representation-transfer owner, and ARC remains the
ownership-transfer owner. Do not add a local pair-propagation pass without new
owner-produced evidence. A future reduction must come from closed-ABI
specialization that removes the boundary itself.

### 10. Hoist immutable global borrows

This remains a possible consequence of paired erased-witness propagation, not
an active task. Current Explore facts do not count repeated same-global borrows,
so there is no owner-produced evidence that a separate global optimization is
profitable. Re-evaluate it after ISS-413 instead of opening an overlapping pass.

### 11. Coalesce ARC operations after upstream simplification

Delivered by ISS-414. The Physical Program remains the ownership-semantics
owner: Basic still contains 372 retains and 286 releases. The Wasm target now
projects verified slot metadata once into a typed Frame Cleanup Plan and shares
one complete helper for reference, callable, and erased cleanup. Per-frame
unwind code only supplies the verified slot values and liveness. It no longer
reconstructs or expands the release policy for every owning slot.

Explore now separates frame-state maintenance, per-frame unwind, and shared
cleanup support. On the pinned programs, the structural result is:

| Program | Wasm instructions before | after | ARC unwind before | after | shared cleanup |
| --- | ---: | ---: | ---: | ---: | ---: |
| Basic | 72,672 | 61,928 | 20,351 | 9,584 | 23 |
| coroutine scheduler | 8,346 | 7,140 | 2,377 | 1,148 | 23 |

The three extra direct helpers do not enter the callable table. Physical
function, instruction, slot, retain/release, and representation-bridge counts
are unchanged. This is deliberately implementation sharing at the Wasm
boundary, not an unsupported claim that ARC demands were removed.

## Priority three: conventional residual optimization

After the structural work above, apply standard sparse conditional constant
propagation, cross-block scalar constant propagation, dead branch removal, and
local Wasm canonicalization. The current image has only 46 boolean branches and
29 tag switches at Physical Program level, so these passes are unlikely to dominate the
present JIT problem.

Wasmoon lazy compilation, caching, and compiler throughput remain useful but
belong to the runtime project. Lane must first avoid requiring the runtime to
eagerly compile avoidable functions and representation plumbing.

## Recommended implementation order

ISS-410 and ISS-411 completed static-head ownership and local scalar
replacement, and ISS-412 remeasured their complete downstream result. The next
order is now evidence-driven:

1. Complete ISS-413 so erased payloads and witnesses propagate as one fact,
   then remeasure the 473 remaining representation bridges.
2. Complete ISS-414 using the resulting ARC-final program, separating ownership
   demand from unwind implementation before changing either.
3. Re-measure object, callable, global, and conventional CFG costs. Open another
   task only when an owner-produced fact demonstrates a removable structure.

The current Wasm expansion categories explain this ordering. Basic attributes
20,351 instructions to ARC/unwind, 18,847 to object operations, 7,564 to
callables, 4,215 to runtime guards, and 2,659 to erasure. Only erasure already
has a precise paired semantic fact to deepen. ARC/unwind has a verified lifetime
owner but needs finer attribution. The object and callable totals include
necessary semantics and therefore do not by themselves authorize another
rewrite.

Each completed item must update the pinned Explore metrics and the end-to-end
Basic timing. A smaller source-level IR without a smaller executable image is
not sufficient evidence, and a faster runtime without stable image metrics does
not prove a compiler optimization.
