# Compiler optimization priorities

This document records the optimization opportunities exposed by a complete
`lane explore` report for the Basic test entry. It is a prioritized engineering
plan, not a language specification and not a set of permanent numeric budgets.
The measurements identify missing facts and transformations; future work must
re-measure the same boundaries instead of tuning limits until one snapshot
looks smaller.

## Current reproducible baseline

The current baseline was recorded on 2026-08-29 at Lane commit
`2d3188534de69eb485d69d72027815321ee1120a` with pinned Basic
`b4b95e1c04f785b61a65fffc2b4433f20c118a22`, the Wasmoon dependency family at
`0.12.6`, MoonBit nightly 2026-08-26, and Apple Silicon running macOS 26.5.2.
It uses two committed inputs:

```sh
lane explore examples/valid/37_coroutine_scheduler.lane:answer \
  --lib-dir ../basic --no-basic -o scheduler.html
lane explore ../basic/test/entry.lane:test_entry \
  --lib-dir ../basic --no-basic -o basic.html
```

Explore Protocol v11 is the owner-produced structural observation boundary.
All counts below are typed scale, provenance, call-resolution, and expansion
facts from the report model; rendered IR and WAT were not searched to infer
compiler facts.

| Stage | Coroutine Scheduler | Basic test entry |
| --- | ---: | ---: |
| Core optimized functions / nodes / calls | 15 / 234 / 30 | 146 / 3,956 / 631 |
| Selective-CPS functions / nodes / calls | 45 / 416 / 59 | 286 / 4,757 / 699 |
| CPS-Core optimized functions / nodes / calls | 39 / 373 / 53 | 254 / 4,252 / 658 |
| Runtime ANF functions / nodes / calls | 39 / 659 / 53 | 254 / 7,263 / 658 |
| Initial VM CFG functions / instructions / values | 60 / 307 / 562 | 381 / 3,932 / 6,214 |
| Physical functions / instructions / slots | 60 / 349 / 414 | 381 / 4,573 / 4,030 |
| Wasm functions / instructions / locals | 104 / 7,140 / 480 | 492 / 61,928 / 4,782 |
| Wasm imports / table entries | 1 / 80 | 3 / 363 |

The function growth is not owned by Wasm alone. Selective CPS triples the
scheduler's 15 Core functions to 45 before cleanup returns 39. Runtime ANF then
becomes 60 Physical functions; 20 are structural callable adapters and 13 are
handler/CPS/monadic functions. Basic similarly grows from 254 Runtime ANF
functions to 381 Physical functions, including 73 structural callable adapters
and 115 handler/CPS/monadic functions.

The remaining Physical facts are:

| Physical fact | Coroutine Scheduler | Basic test entry |
| --- | ---: | ---: |
| Direct / indirect calls | 22 / 43 | 451 / 148 |
| Exact-target calls still indirect because the environment is packed | 9 | 35 |
| Closures / environments | 48 / 50 | 361 / 381 |
| Erase / unerase | 15 / 11 | 327 / 146 |
| Retain / release | 13 / 29 | 372 / 286 |
| Callable ABIs / object shapes | 29 / 24 | 121 / 84 |
| Duplicate runtime-ABI workers | 0 | 0 |

## Where the Wasm expansion comes from

The Wasm emitter's exhaustive expansion accounting sums exactly to each
module's instruction total:

| Expansion owner | Scheduler | Basic | Basic share |
| --- | ---: | ---: | ---: |
| Physical object operations | 1,740 | 16,303 | 26.3% |
| ARC unwind | 1,148 | 9,584 | 15.5% |
| ARC frame-state maintenance | 822 | 8,184 | 13.2% |
| Physical callable operations | 695 | 5,576 | 9.0% |
| Runtime guards | 684 | 4,215 | 6.8% |
| Physical control transfer | 620 | 3,714 | 6.0% |
| CFG structuring | 185 | 3,217 | 5.2% |
| Physical ownership operations | 152 | 2,816 | 4.5% |
| Physical scalar operations | 94 | 2,340 | 3.8% |
| Physical erasure operations | 90 | 1,485 | 2.4% |
| Function ABI | 284 | 1,414 | 2.3% |
| Helper support | 196 | 1,155 | 1.9% |
| Runtime support | 355 | 767 | 1.2% |
| Byte sequence, global, cleanup, and entry work | 75 | 1,158 | 1.9% |
| **Total** | **7,140** | **61,928** | **100%** |

Object operations plus ARC frame state and unwind account for 52.0% of the
scheduler and 55.0% of Basic. This is the dominant boundary to study, but the
totals alone do not prove redundancy: objects require headers, shape-aware
cleanup, and ownership transfer, while fatal unwinding requires path-sensitive
live-owner state.

Wasm function count is also fully attributable. Basic's 492 defined functions
are 381 Physical bodies, 84 shape destructors, 15 runtime functions, 11 shared
helpers, and one entry wrapper; its three imports are counted separately. The
scheduler's 104 are 60 Physical bodies, 24 shape destructors, eight runtime
functions, 11 shared helpers, and one entry wrapper. Both reports have zero
unreachable Wasm support roles, so reachable-support pruning has no residual
dead family to delete.

Locals principally preserve the Physical storage plan. Basic's 4,782 locals
partition exactly into 4,030 Physical slots, 620 ARC-unwind locals, 99 CFG
locals, and 33 runtime-support locals. The scheduler splits 480 into 414, 39,
nine, and 18 respectively. Reducing locals therefore primarily means reducing
Physical live ranges and slots rather than applying a Wasm-local peephole.

Two concrete costs require different treatment:

- Callable-flow already proves 35 Basic and nine scheduler indirect calls have
  exactly one target, but their environment remains inside a packed callable.
  This is demonstrated removable dispatch work and is tracked separately by
  ISS-423; the packed callable may still be required by source semantics.
- Eleven logical call-depth instructions are emitted in every Physical body.
  They account for 4,191 of Basic's 4,215 runtime-guard instructions and 660 of
  the scheduler's 684. This is not accidental guard duplication: it implements
  the configurable execution limit in ADR-0112. Removing it requires an
  explicit execution-policy change or an engine-owned equivalent, not a local
  Wasm cleanup.

## Historical baselines

Measurements from 2026-08-11 covered the deleted semantic-runtime and bytecode
architecture. They included 702-731 physical functions, 5,933-6,453 physical
instructions, 845-876 Wasm functions, and 129,753-134,655 rendered Wasm
instructions for an earlier Basic revision. They remain useful evidence for why
callable-flow and representation specialization were introduced, but they are
not a baseline for the current raw-Wasm pipeline.

Explore Protocol v11 provides owner-produced aggregate metrics and preserves
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

This remains a possible consequence of closed-ABI specialization, not an active
task. Current Explore facts do not count repeated same-global borrows, so there
is no owner-produced evidence that a separate global optimization is
profitable.

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

ISS-410 through ISS-414 completed static-head ownership, local scalar
replacement, erased-contract analysis, and shared ARC cleanup. The next order
is evidence-driven:

1. Complete ISS-423 by consuming the existing exact-target/packed-environment
   fact at the VM CFG owner. This removes known indirect dispatch without
   changing closure escape semantics or adding a heuristic.
2. Add finer owner-produced object-operation and ARC-frame attribution before
   choosing a representation or unwind rewrite. Their aggregate size is large,
   but it mixes required semantics with potential implementation expansion.
3. Decide whether configurable logical call depth remains part of Lane's
   execution contract before changing its per-function Wasm instrumentation.

The current evidence does not authorize another representation bridge,
destructor-sharing, or ARC peephole pass. There are no duplicate runtime-ABI
workers or unreachable Wasm support roles, and the remaining bridge counts cross
real generic boundaries. New work needs a fact that identifies which specific
boundary can be removed.

Each completed item must update the pinned Explore metrics and the end-to-end
Basic timing. A smaller source-level IR without a smaller executable image is
not sufficient evidence, and a faster runtime without stable image metrics does
not prove a compiler optimization.
