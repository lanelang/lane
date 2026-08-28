# Compiler optimization priorities

This document records the optimization opportunities exposed by a complete
`lane explore` report for the Basic test entry. It is a prioritized engineering
plan, not a language specification and not a set of permanent numeric budgets.
The measurements identify missing facts and transformations; future work must
re-measure the same boundaries instead of tuning limits until one snapshot
looks smaller.

## Current reproducible baseline

The current baseline was recorded on 2026-08-28 from Lane
`75e2bdd73b444493d798b555dbc603749ae65b14`, pinned Basic
`807f78b4bd3106b1223c13884849b317f831e285`, and the Wasmoon dependency family
at `0.12.6`. The host was Apple Silicon running macOS 26.5.2 with MoonBit nightly
2026-08-26. Both programs were loaded from committed repository inputs with
`--lib-dir basic --no-basic`.

Explore is the owner-produced structural observation boundary. The tables below
come from its typed scale facts; no IR or Wasm text was searched to reconstruct
counts.

| Stage metric | Coroutine scheduler | Basic test entry |
| --- | ---: | ---: |
| Core-optimized functions | 15 | 146 |
| Core-optimized nodes | 234 | 3,956 |
| Selective-CPS functions | 45 | 286 |
| Selective-CPS nodes | 416 | 4,757 |
| Runtime ANF functions | 39 | 254 |
| Runtime ANF nodes | 659 | 7,272 |
| Initial VM CFG functions | 60 | 382 |
| Initial VM CFG instructions | 307 | 3,953 |
| Initial direct / indirect calls | 22 / 43 | 450 / 150 |
| Initial closures / environments | 48 / 50 | 362 / 383 |
| Physical functions | 60 | 382 |
| Physical instructions | 349 | 4,594 |
| Physical slots | 414 | 4,045 |
| Physical erase / unerase operations | 15 / 11 | 330 / 149 |
| Physical retain / release operations | 13 / 29 | 372 / 286 |
| Callable ABI count | 29 | 121 |
| Wasm functions / imports | 101 / 1 | 490 / 3 |
| Wasm instructions | 8,346 | 72,967 |
| Wasm locals | 480 | 4,803 |
| Wasm table entries | 80 | 365 |
| Wasm `if` / `unreachable` instructions | 389 / 74 | 3,357 / 486 |

Three warm-process command invocations produced these wall-clock ranges:

| Boundary | Coroutine scheduler | Basic test entry |
| --- | ---: | ---: |
| Explore through Wasm plus report rendering | 0.04-0.05 s | 0.74-0.76 s |
| Complete compile, JIT load, and execution | 0.16 s | 1.94-1.95 s |
| Complete compile, interpreter load, and execution | 0.04 s | 0.69-0.71 s |

The CLI does not persist the raw Wasm produced by `run`, so these measurements
do not pretend to derive a standalone JIT or execution time by subtraction.
They establish an explicit compiler-pipeline boundary and two complete engine
boundaries. Structural metrics remain the regression evidence when host or
runtime timing changes.

The current facts justify constructor propagation before another backend
rewrite. Core optimization reduces a constructor match only when the referenced
top-level definition is syntactically a constructor. A conservative static-value
summary can expose the same fact through pure binding spines, and non-escaping
aggregate replacement can then remove object, ARC, and Wasm work at the earliest
boundary that understands the source value.

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

Core optimization currently recognizes a static constructor only when the top
definition is syntactically a `Construct`. It misses closed pure initializers
whose final value lies behind a `Let` or `LetRec` spine. In the observed program,
one such value ends in a known `datacon#8` but is projected through a `match` 19
times.

`CoreAnalysis` should be the sole owner of a conservative static-value summary:

- unknown;
- literal;
- constructor with summarized payloads;
- known callable with captured substitutions.

The analysis must preserve strict evaluation and effects while looking through
closed, pure binding spines. Match reduction, field projection, known-call
analysis, and reachability then consume the same summary. This should expose
dictionary fields as known callables, eliminate repeated constructor matches,
and enable the later priorities without inventing another fact producer.

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

Extend constructor knowledge through local bindings and pure initializer
summaries. A known construct followed by projection, match, reconstruction, or a
non-escaping use should pass its fields directly. This targets the observed 225
`make_data`, 277 `borrow_field`, 61 `consume_fields`, and 196 Core matches.

### 8. Intern generated shape destructors

The current Wasm backend emits one destructor function per object shape. In the
observed image, 126 functions contain only 72 distinct rendered bodies. Intern a
structured destructor plan before function and callable-table allocation, then
map every compatible shape to the shared function. This is preferable to a
generic runtime interpreter as the first step because it reduces JIT work
without adding release-time dispatch.

### 9. Propagate erased values and witnesses as one fact

VM CFG scalar propagation deliberately excludes erased companion slots, leaving
many repeated `const_layout` operations. Model an erased payload and its layout
witness as one paired representation fact. Pair-aware constant propagation may
reuse witnesses and cancel locally inverse bridges without separating the
ownership proof from its companion.

### 10. Hoist immutable global borrows

After verification, an Instance Global is immutable until lifecycle cleanup.
Repeated borrows of the same global within a function may share one loaded
value, subject to the paired erased-witness rule. This should be expressed as a
VM CFG value fact rather than a Wasm text peephole.

### 11. Coalesce ARC operations after upstream simplification

Run ownership-aware retain/release coalescing only after callable
devirtualization and aggregate scalar replacement. Those transformations remove
the objects that cause many current ARC operations; optimizing ARC first would
spend complexity preserving temporary lowering artifacts. The ARC-final
ownership graph must prove every removed retain/release pair.

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

1. Make `CoreAnalysis` the sole owner of conservative static-value summaries
   and remove downstream syntax guessing.
2. Consume those summaries to propagate constructors and scalar-replace only
   aggregates proven not to escape.
3. Remeasure the pinned scheduler and Basic inputs at the same typed Explore
   boundaries.
4. Use the resulting facts to decide between pair-aware erased-witness
   propagation, immutable-global borrow reuse, ARC coalescing, or destructor
   interning.
5. Apply conventional CFG and Wasm cleanup only after structural work has
   removed its temporary inputs.

Each completed item must update the pinned Explore metrics and the end-to-end
Basic timing. A smaller source-level IR without a smaller executable image is
not sufficient evidence, and a faster runtime without stable image metrics does
not prove a compiler optimization.
