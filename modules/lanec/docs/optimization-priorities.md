# Compiler optimization priorities

This document records the optimization opportunities exposed by a complete
`lane explore` report for the Basic test entry. It is a prioritized engineering
plan, not a language specification and not a set of permanent numeric budgets.
The measurements identify missing facts and transformations; future work must
re-measure the same boundaries instead of tuning limits until one snapshot
looks smaller.

## Observed baseline

The measurements below came from the 2026-08-11 compiler and a local Basic
`test/entry.lane:test_entry` build with `--lib-dir . --no-basic`. The Basic
worktree contained uncommitted changes, so these values are diagnostic evidence
rather than a reproducible release baseline. A committed Basic revision must be
pinned before turning them into regression gates.

The complete run took about 8.60 seconds, while non-executing exploration
through Wasm generation took about 0.39 seconds. Approximately 95 percent of the
wall time therefore remained at the Wasmoon JIT and execution boundary. The
generated image still gave that boundary substantially more work than the
source program justified:

| Observation | Value |
| --- | ---: |
| Physical Program functions | 705 |
| Total Wasm functions, including imports and generated helpers | 851 |
| Physical functions with one explicit static reference | 602 |
| Physical functions with at most 5 operations | 344 |
| Physical functions with at most 10 operations | 523 |
| Direct calls, including tail calls | 500 |
| Indirect calls, including tail calls | 438 |
| `make_env` operations after VM CFG finalization | 650 |
| `make_closure` operations after VM CFG finalization | 646 |
| Callable table entries | 672 |
| `const_layout` operations | 981 |
| `erase_*` operations | 597 |
| `unerase_*` operations | 376 |
| `retain_copy` operations | 623 |
| `release` operations | 410 |
| Instance globals | 66 |
| Shape destructor functions | 126 |
| Distinct rendered shape destructor bodies | 72 |

## Callable-flow and adapter result

The 2026-08-11 callable-flow and deferred-adaptation implementation was
measured against clean Basic revision `8a7be0e`. The immediately preceding
compiler produced 705 Physical Program functions, 7,192 physical instructions, 438
indirect calls, 646 closures, and 650 environments. Its Wasm contained 848
functions, 144,733 instructions, 11,372 locals, and 671 table entries.

With exact callable flow and non-escaping callable-adapter fusion, the same
program produces 702 Physical Program functions, 6,453 physical instructions, 411
indirect calls, 486 closures, and 486 environments. The Wasm contains 845
functions, 134,655 instructions, 11,041 locals, and 659 table entries. Three
complete `test.sh` runs took 6.81, 6.95, and 6.66 seconds, compared with the
preceding 8.43 to 9.27 second range. Non-executing Explore took 0.40 seconds.

These results demonstrate removal of callable representation plumbing. They do
not demonstrate general generic-representation specialization: the resulting
the Physical Program still contains 601 erase and 375 unerase operations.

## Representation-specialization result

Demand-driven first-order representation workers were measured on 2026-08-11
against the same clean Basic revision `8a7be0e`. The plan deduplicates by
canonical runtime ABI, proves recursive demand closure, retains generic
fallbacks for open uses, and relies on exact whole-image reachability to remove
only physically unreachable functions.

These are historical optimization measurements, not evidence for the former
planner architecture. ADR-0138 retains the generic fallback and canonical
worker key but requires specialization to be a removable program rewrite.

Relative to the callable-flow baseline, Physical Program functions increase from
702 to 731 while instructions decrease from 6,453 to 5,933. Erase operations
fall from 601 to 440 and unerase operations from 375 to 325. Closures and
environments each fall from 486 to 456. The Wasm image increases from 845 to 876
functions, but rendered instructions decrease from 134,655 to 129,753, locals
from 11,041 to 10,623, and table entries from 659 to 633. Thus Explore exposes
the multiversioning cost rather than hiding it, while both executable code size
and representation plumbing decrease.

Three complete `test.sh` runs took 5.45, 5.47, and 5.44 seconds. Non-executing
Explore took 0.39 seconds. The preceding callable-flow baseline took 6.66 to
6.95 seconds for `test.sh` and 0.40 seconds for Explore.

Layout witnesses and erasure bridges account for 1,954 of 8,168 physical
operations, about 24 percent. The current VM CFG devirtualizer changes only 11
indirect calls to direct calls and removes only 6 of 652 initial closure
constructions and 3 of 653 initial environment constructions.

The largest three Lane functions expand to approximately 5,941, 5,248, and
2,736 rendered Wasm instructions. The generated entry lifecycle contributes
another approximately 1,809 instructions, including 66 unrolled global
completeness checks and separate normal and exceptional cleanup paths. In total,
approximately 8,168 Physical Program operations expand to 153,000 rendered Wasm
instructions.

## Priority zero: trustworthy measurement

Optimization work needs a deterministic, machine-readable feedback loop before
the numbers above become targets.

Explore Protocol v6 retains the structural observability introduced in v2 and
now delivers the first two requirements below. One observation analysis owns
reconstructible public-IR counts; the linker reports module retention
contributions, and function lineage is carried by ANF, Physical Program finalization,
and Wasm emission owners. Per-function scale is published only at
identity-owning stages; tree stages remain aggregate-only. Ordinary compilation
does not construct these observations. The remaining work starts with a pinned
clean Basic baseline.

1. Add per-stage metrics to Explore without making the human-facing IR text a
   serialization format. At minimum, record function count, operation count,
   maximum function size, direct and indirect call counts, closure and
   environment construction counts, callable table size, layout-erasure bridge
   counts, ARC counts, object-shape count, and generated helper count.
2. Preserve function provenance from Buslane values through ANF, VM CFG,
   Physical Program, and Wasm. Presentation consumes this relationship; it must not
   infer it from function order or rendered identifiers.
3. The Wasm text renderer now explicitly covers every instruction emitted by
   the Wasm emitter. Public round-trip tests parse and validate the complete text and
   preserve special floating-point constant bits.
4. Pin a clean Basic revision and record compilation, JIT, and execution time
   separately. Image-size gates must accompany the timing gate so a runtime
   change cannot hide compiler output growth.

These metrics are evidence, not policy. No optimization decision should be
defined by the observed function IDs or by machine-specific wall-clock values.

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

1. Pin a clean Basic baseline using the delivered Explore v2 metrics and
   provenance.
2. Remove duplicated global runtime checks and compact entry lifecycle cleanup.
3. Add the Core static-value summary and consume it in match and projection
   reduction.
4. Complete ISS-390 so canonical generic lowering is independently correct and
   representation specialization is removable.
5. Reintroduce closed representation workers as an optional rewrite, then add
   general structural adaptation cancellation.
6. Add constructor scalar replacement, pair-aware witness propagation, and
   immutable-global borrow reuse.
7. Coalesce residual ARC operations.
8. Intern identical shape destructor plans.
9. Apply conventional CFG and Wasm cleanup to the smaller program.

Each completed item must update the pinned Explore metrics and the end-to-end
Basic timing. A smaller source-level IR without a smaller executable image is
not sufficient evidence, and a faster runtime without stable image metrics does
not prove a compiler optimization.
