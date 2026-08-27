# Lane Compiler

This context owns compiler vocabulary from source elaboration through verified
Physical Program construction and WebAssembly emission. Host ABI and execution
terms belong to the Lane Runtime context.

## Language

### Compiler Boundaries

**Compiler Front End**:
The target-independent compiler that turns Lane source into checked semantic
artifacts.
_Avoid_: CLI tool, runtime, Basic library

**Source Elaboration**:
The single compiler operation that consumes one Parsed Module, its Module
Import Environments, a Symbol Registry, and optional previous Declaration
Identities. It owns resolution, local type inference, contextual argument
insertion, checking, Module Interface certification, exported symbol metadata,
linting, and their diagnostics. Its outcome explicitly distinguishes resolution
failure, typecheck failure, complete success, and a structured compiler defect.
_Avoid_: batch source checker, workspace source checker, initialization ordering, persistent fingerprinting

**Successful Source Elaboration**:
The inseparable source-order semantic result containing matching Resolved
Source, Checked Source, certified Module Interface, exported symbol metadata,
and warnings. Batch compilation and Semantic Workspace consume this same value.
_Avoid_: optional checked source, separately reconstructed interface, initialization-ordered source

**Checked Source**:
The source-shaped semantic representation with resolved identities, explicit
elaboration choices, and verified source types and effects.
_Avoid_: syntax AST, Buslane, inferred side table

**Pre-Buslane Contract**:
The invariants Checked Source must satisfy before Semantic Lowering, documented
in `docs/pre-buslane-contract.md`.
_Avoid_: Buslane verifier contract, backend ABI

**Semantic Lowering**:
The translation from Checked Source into Buslane.
_Avoid_: source elaboration, ANF normalization

**Buslane Value Descriptor**:
An entry, compiler-intrinsic, or runtime-import identity attached to one
Buslane `ValueId`. Its source semantic type is owned only by the enclosing
Buslane Metadata Registry. A runtime import additionally owns its erased host
signature because that is a distinct ABI fact.
_Avoid_: copied source type, inferred host signature, detached value metadata

**Whole-Program Elaboration**:
The post-link phase that validates the selected entry and makes initializer
reachability, effect-aware CPS Core, and externals explicit.
_Avoid_: module linking, target lowering

**Executable Program**:
The target-independent result of Whole-Program Elaboration containing one CPS
Core program, one selected entry, externals, and one Executable Retention Set.
Initializer bodies and source order remain owned only by the CPS Core terms;
the retained set contains identities, not copied expressions or a schedule.
_Avoid_: linked core wrapper, target artifact

**Executable Retention Set**:
The exact set of top-level ValueIds reachable from the selected entry
and all surviving eager initializers after CPS Core optimization. It includes
the entry, retained externals, functions, and initializers and is produced once
by Whole-Program Elaboration.
_Avoid_: backend occurrence analysis, initializer-only roots, copied AST

**Initializer Schedule**:
The target-owned lowering plan produced by one source-order scan of retained
Runtime ANF terms. Recursive top-level terms remain one scheduling unit.
_Avoid_: executable AST side table, reordered root array

**Linked Core Retention Root Set**:
All entry candidates admitted by the link policy, value-bearing exports, and
external values after cross-module identities have been remapped. Runtime type,
effect, and operation metadata remains intact and does not create value roots.
_Avoid_: per-module reachability, executable retention set

**Linked Core Tree Shaking**:
The exact post-link removal of private top-level definitions outside the
transitive closure of the Linked Core Retention Root Set.
_Avoid_: heuristic inlining, metadata pruning, per-module DCE

**Execution Image Lowering**:
The target-specific translation from an Executable Program through a verified
Physical Program to standard WebAssembly.
_Avoid_: semantic lowering, artifact encoding

### Source Analysis And Formatting

**Compiler Analysis API**:
The platform-neutral query surface for diagnostics, navigation, hover, semantic
tokens, inlay hints, and completion.
_Avoid_: LSP protocol adapter, filesystem workspace

**Semantic Workspace**:
The mutable owner of identified sources, module dependencies, symbol identity,
and reusable per-module semantic state.
_Avoid_: editor document store, request-local compilation

**Semantic Snapshot**:
A revisioned read-only view of one Semantic Workspace used consistently by all
analysis queries.
_Avoid_: mutable cache, build artifact

**Reverse-Dependency Invalidation**:
The workspace rule that rebuilds a changed module and its transitive importers
while retaining unaffected semantic state.
_Avoid_: whole-workspace rebuild, textual dependency scan

**Last Successful Module Interface**:
Recovery state that lets importers continue using the latest valid interface of
a module whose current source cannot be parsed.
_Avoid_: stale source diagnostics, persisted artifact

**Semantic Analysis Fact**:
A compiler-produced definition, reference, hover, token, or inlay record carrying
semantic identity and source location before protocol presentation.
_Avoid_: LSP payload, editor-side inference

**Call Argument Provenance**:
Checked-call metadata identifying authored, pipeline, operator, or inserted
arguments and their semantic order.
_Avoid_: span-based call reconstruction, label heuristic

**Producer-Ordered Inlay Fact**:
An inlay fact whose presentation order is assigned during checked expression
traversal rather than inferred from source ranges or labels.
_Avoid_: span-size ordering, label tie-breaker

**Semantic Completion**:
Position-specific completion derived from the same Semantic Snapshot as other
analysis features.
_Avoid_: keyword scan, LSP-owned candidate model

**Concrete Syntax**:
The formatter-facing token, trivia, span, and grouping sidecar paired with a
parsed syntax tree.
_Avoid_: checked source, semantic AST

**Concrete Layout**:
The immutable formatter index that assigns comments and separators to concrete
token gaps.
_Avoid_: mutable render state, AST comment fields

**Trivia-Preserving Formatting**:
Canonical full-file formatting that preserves comments while maintaining syntax
round-trip equivalence and idempotence.
_Avoid_: post-render comment insertion, error recovery formatter

### Exploration

**Explore Stage**:
A stable compiler-owned observation point at a useful semantic transformation
boundary.
_Avoid_: every internal pass, mutable compiler hook

**Explore Stage Catalog**:
The single ordered protocol table that owns every Explore Stage identity, key,
title, domain, text format, and order.
_Avoid_: stage-field record, parallel stage switch, positional reconstruction

**Explore Snapshot**:
The human-readable projection recorded for one completed Explore Stage.
_Avoid_: typed IR transfer, serialization format

**Explore Function Identity**:
The stage-local identity assigned by an IR construction or function-emission
owner and consumed by both provenance and per-function scale observations.
Stages without such an identity publish aggregate scale only.
_Avoid_: traversal ordinal, array position, rendered label

**Explore Structural Scale**:
A deterministic typed aggregate produced by the sole observation analysis for
a completed IR. Public IR structure may be traversed by Explore; private stage
structure is summarized by its owner. Tree IRs expose aggregates only.
_Avoid_: public scale interface with one consumer, pretty-text parsing,
fabricated identity, metadata allocation count presented as live structure

**Explore Link Contribution**:
A linker-owned observation that attributes input and retained top terms and
value bindings to their source modules at the reachability-retention boundary.
_Avoid_: name-based attribution, cached derived fact in LinkedProgram

**Explore Report**:
The versioned result for one selected entry, containing ordered completed,
failed, or unavailable Explore Stages and diagnostics.
_Avoid_: runtime trace, compiler session

**Partial Explore Report**:
A failed Explore Report that preserves completed stages and identifies the first
failed stage without converting failure into success.
_Avoid_: fallback success report, empty diagnostics

**Compilation Observer**:
A read-only recipient of stage snapshots emitted by the canonical compiler
pipeline. When absent, the pipeline does not render or measure snapshots.
_Avoid_: compiler plugin, alternate pass manager, no-op callback that still
constructs observations

**Compiler Driver**:
The platform-neutral orchestration boundary shared by native and browser
exploration hosts.
_Avoid_: CLI command, filesystem discovery, browser transport

### Effect Elaboration

**Effect Lowering Module**:
The single compiler operation that consumes verified effect-aware Buslane and
produces verified effect-aware CPS Core. Handler elaboration, monadic
transformation, selective-CPS rewriting, and open-context resolution are
private transformations inside this owner rather than independently
constructible IR APIs.
_Avoid_: public transitional AST, pass-by-pass orchestration in executable lowering

**Effect Lowering Snapshot**:
An owner-produced read-only observation of a verified private effect-lowering
stage, containing rendered text and aggregate scale but no transitional AST.
_Avoid_: typed IR transfer, driver-owned traversal, constructible stage wrapper

**Effect Specialization Demand**:
A canonical request to retain a generic definition or create one concrete
effect-specialized instance at a reachable source definition site.
_Avoid_: rewrite-time discovery, optimizer hint

**Effect Specialization Plan**:
The immutable fixed point that owns specialization demand, declaration
retention, and source-ordered output before allocation and rewriting.
_Avoid_: second reachability analysis, mutable rewrite policy

**Monadic Effect Predicate**:
The classification that requires monadic translation for an open effect row or
one containing handleable operations.
_Avoid_: nonempty-effect test, `Io` special case

**Non-Monadic Residual Effect**:
The built-in and External portion of an effect row retained through selective
CPS until effect-sensitive optimization is complete.
_Avoid_: pure effect, handler dictionary

**Effect Context Companion**:
The explicit higher-kinded CPS parameter that carries a source effect's runtime
handler context across different answer and residual scopes. Every source
effect binder becomes this parameter plus one residual parameter at callable,
nominal, and existential binding sites; the source binder does not survive in
CPS Core.
_Avoid_: source effect syntax as layout evidence, fixed dictionary type

**Selective CPS**:
The compiler transformation that converts only computations satisfying the
Monadic Effect Predicate into answer-type continuation form.
_Avoid_: whole-program CPS, VM stack capture

**Effect-Aware Core Optimization**:
Whole-program optimization over verified Buslane before effect lowering and
again over verified CPS Core after monadic lift. At both seams `Empty` denotes
observational purity; effect information is projected away only while
constructing runtime ANF.
_Avoid_: effect-blind DCE, physical-program optimization

**Runtime ANF**:
The closed backend-lowerable ANF produced only by projecting verified,
effect-aware CPS Core through the Executable Retention Set. It owns
`RuntimeType`, `RuntimeEvidence`, retained top-level terms, and an immutable
runtime type-expression catalog; these distinguish scalar, byte-sequence,
nominal reference, data, callable, and erased representations without carrying
Buslane `Type`, `Effect`, `Kind`, `GenericArgument`, or type-lambda syntax.
Stable Buslane declaration IDs survive only as nominal symbols. Nominal runtime
arguments select construction and projection evidence, but do not define a
data value's callable ABI. Higher-kinded nominal arguments are eta-expanded at
this boundary. Every top-level and nested callable has a stable Runtime ANF
identity, lexical evidence scope, captures, and recursive-group identity.
Representation Elaboration consumes Runtime ANF.
_Avoid_: general Buslane ANF, effect-erased Buslane, backend node filtering

**Canonical Generic ABI**:
The complete evidence-passing execution contract used whenever a runtime type
remains open. Ordinary values use an erased payload plus layout evidence;
higher-kinded values use explicit layout constructors. Generic definitions and
declaration-owned nominal storage are independently lowerable through this ABI.
_Avoid_: specialization prerequisite, reference guess, closed-world layout

**Representation Elaboration**:
The private lowering operation that consumes verified Runtime ANF and target
ABI facts while constructing VM CFG. It is the sole producer of physical value
contracts and structural representation adaptations. Substitutions, evidence
recipes, adapter memoization, layout interning, and work queues remain private
to Physical Lowering; no intermediate planning sidecar
crosses the package boundary.
_Avoid_: planner catalog interface, emitter type guess, specialization policy

**Physical Value Contract**:
The authoritative execution representation of one value after Representation
Elaboration, including slot representation, cleanup, semantic runtime value
category, object or callable shape, and required layout-evidence provenance.
Semantic type provenance may coexist with this contract but cannot override it.
_Avoid_: source type identity, machine width alone, candidate contract set

**Runtime Generic Plan**:
The fixed-point fact set constructed at the CPS-Core-to-Runtime-ANF boundary
that owns which generic binders and corresponding arguments survive runtime
projection. Binder identity and formal-to-actual relationships determine the
plan; rendered names, occurrence counts, and effect spelling do not.
_Avoid_: vacuous-binder cleanup pass, downstream arity repair

**Effect-Directed Application Reduction**:
The Core optimization operation that reduces one materialized application by
substituting definitionally aligned `Empty` arguments and binding nonempty or
representation-adapting arguments once in observable order.
_Avoid_: atom-only beta reduction, effect-name special case, local ANF copy

**Runtime Effect Projection**:
The one-way removal of residual effect syntax while verified CPS Core is
lowered directly into Runtime ANF. It never produces an ordinary Buslane
program in which `Empty` means missing information.
_Avoid_: residual-effect erasure pass, source-effect layout inference

### VM CFG And Physical Program Production

**VM CFG**:
The compiler-private value-based control-flow graph between lower semantic IR
and the Physical Program.
_Avoid_: persisted execution format, source control flow

**Canonical Pre-ARC VM CFG Image**:
The compiler-private nominal whole-image boundary produced after local
devirtualization, consuming-projection selection, simplification, borrow
preparation, and metadata validation. It owns the sole reachable and canonical
function table plus the complete old-to-canonical FunctionId relation. Function
equivalence includes semantic value metadata and canonical referenced-function
classes; equal rendered instructions with different data-family or callable
ABI facts remain distinct. The public API never exposes this value before ARC,
slot allocation, physical emission, and Physical Program verification have completed;
the completed finalization only exposes its pre-ARC image as observation data.
_Avoid_: pre-cleanup reachability, lowering-owned function-table policy,
pretty-text identity, caller-mutable prepared image

**VM CFG Use-Definition Analysis**:
The authoritative checked index of every VM CFG value definition and use,
including whole-CFG counts, per-block counts, and instruction/terminator flow
facts. Construction rejects a second definition of any `ValueId` and preserves
both definition sites in the structured compiler defect. Consumers derive
policy from this index instead of rescanning VM CFG blocks.
_Avoid_: slot history, source reference graph, consumer-owned use counts

**VM CFG Callable-Flow Analysis**:
The authoritative whole-image fixed point for callable alternatives,
environments, aggregate members, immutable globals, and known function results.
Devirtualization and environment-ABI planning consume this fact directly.
_Avoid_: instruction-adjacency pattern, reference-count eligibility, rewrite fallback

**Deferred Callable Adaptation**:
The Structural Representation Adaptation between two callable contracts.
The complete structural physical contract is the private key used to share an
escaping worker; each materialization supplies its own callable and evidence
captures. Direct invocation consumes the same contract and may fuse conversion
into the call without materializing a worker.
_Avoid_: consumer-visible recipe catalog, runtime-layout-only alignment,
second direct-call adaptation path

**Callable Invocation Contract**:
The exact Physical Value Contracts of a callable's evidence inputs, user
parameters, and result, independent of the closure environment that implements
it. Generic callables obtain this contract from the Canonical Generic ABI;
specialization may produce another closed contract without invalidating the
generic implementation.
_Avoid_: CallableValue layout, source function type, capture schema,
type-derived fallback ABI

**Physical Callable ABI Graph**:
The physical ABI owner's finite nominal graph for recursive Callable Invocation
Contracts. It describes executable call compatibility only. Semantic callable
flow, binder scope, specialization demand, and worker selection do not enter
its identity.
_Avoid_: recursive structural ABI tree, callable-instance graph, source binder identity

**Structural Representation Adaptation**:
The explicit conversion of one value from a complete source Physical Value
Contract to a complete target contract. Identity needs no operation; current
non-identity operations are erase, unerase, and callable adaptation. The
elaborator owns construction; VM CFG and its value metadata are the first IR
that stores the resulting physical operation and contract.
_Avoid_: transition sidecar, source-type spelling, layout-only equality,
emission fallback

**Physical Lowering Provenance**:
The immutable source and transformation origins attached to emitted physical
functions and explicit adaptation operations. Explore consumes this provenance
without turning scale metrics into semantic facts or requiring a second model
of the lowered program.
_Avoid_: planner sidecar, rendered-label identity, scale metric as semantic fact

**Representation Specialization**:
An optional rewrite that clones one generic definition for each closed direct
evidence-application ABI and rewrites those calls to the interned worker. Its
candidate facts, substitutions, recursion ancestry, and worker table are
private to Physical Lowering. Callable flow through first-class values belongs
to VM CFG Callable-Flow Analysis. Deleting the rewrite preserves valid-program
lowering and observable behavior through the Canonical Generic ABI.
_Avoid_: correctness boundary, consumer-visible demand plan, mandatory monomorphization

**Generic Nominal Data Schema**:
The declaration-owned uniform storage ABI for a generic nominal data type.
Representation-dependent members use the Canonical Generic ABI and carry the
evidence required for storage, projection, and destruction. Closed arguments
do not create another nominal family as part of ordinary lowering.
_Avoid_: allocation-local family, specialized storage prerequisite, ambient family set

**Closed Aggregate Scalar Replacement**:
An optional escape-proven rewrite that forwards one allocation's fields to all
known consumers and removes the allocation without changing nominal family
identity. Ambiguous or escaping values keep the ordinary object.
_Avoid_: alternate nominal schema, optimistic escape assumption, lowering fallback

**Erased Callable Position ABI**:
The invocation contract declared by a callable-shaped erased position or by a
lowering-owned canonical callable placeholder. It governs both erasure and
unerasure; an opaque source type parameter does not gain such a contract from
its eventual substitution.
_Avoid_: deriving the payload ABI independently from the concrete value

**VM CFG Liveness Analysis**:
The value-flow analysis derived from VM CFG definitions, uses, and successors.
_Avoid_: ownership policy, reference count

**Runtime Ownership Analysis**:
The VM CFG analysis that classifies reference-bearing uses as borrows, retained
copies, releases, or ownership transfers.
_Avoid_: source borrow checker, Physical Program verifier

**ARC Insertion**:
The VM CFG transformation that materializes ownership decisions as retain,
release, and transfer operations.
_Avoid_: runtime ARC optimization, implicit slot behavior

**ARC-Final VM CFG**:
The private, verifier-proven VM CFG state whose control-flow edges, unique SSA
definitions, borrow roots, and owned lifetimes satisfy the contract required by
physical-slot planning. It carries its checked Use-Definition Analysis for the
slot planner to consume directly. Ownership threading creates fresh block
parameter values and rewrites each block to its local SSA version.
_Avoid_: an unverified `FunctionBody`, final Physical Program

**Physical Slot Plan**:
The validated mapping from an ARC-Final VM CFG to compatible physical slots.
The plan owns the verified body it maps and is produced before Physical Program
construction.
_Avoid_: post-emission slot rewrite, Wasm local plan

**Physical Emission**:
The one-pass projection of finalized VM CFG through a Physical Slot Plan into
the Physical Program.
_Avoid_: allocation pass, emitted-opcode remapping

**Finalized Callable ABI**:
The canonical callable shape derived from finalized slot metadata and interned
once for functions, runtime imports, and indirect call sites.
_Avoid_: source-type reconstruction, verifier repair

**Physical Program Finalization**:
The boundary that produces a complete Physical Program only after ownership,
physical-slot, callable-ABI, and semantic verification succeed. The WebAssembly
emitter is its only consumer.
_Avoid_: partially valid program, persisted VM image, backend-specific repair

**Wasm Expansion Accounting**:
The Wasm emission owner's exact attribution of every emitted instruction and
local to function ABI setup, physical storage, a physical opcode family,
control flow, runtime guards, ARC unwinding, runtime imports, runtime support,
helpers, or entry lifecycle. Each emitted defined function must account for its
complete code and locals before it enters the Wasm module. Explore aggregates
these owned facts; it does not infer them from rendered WAT.
_Avoid_: WAT parsing, sampled costs, heuristic attribution

**Callable ABI Guard Helper**:
The single private Wasm helper that validates the dynamic callable-table target
and complete Callable ABI compatibility before an indirect call transfers any
owner. Its compatibility matrix is produced from the finalized callable ABI
catalog. Call sites provide the packed callable and expected ABI identity; they
do not reproduce the guard policy.
_Avoid_: per-call inlined ABI policy, Wasm value-type equality
