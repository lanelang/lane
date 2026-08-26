# Lane Compiler

This context owns compiler vocabulary from source elaboration through verified
LoisVM image production. Persisted bytecode and runtime terms belong to the
LoisVM context.

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
_Avoid_: linked core wrapper, LoisVM image

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
The target-specific translation from an Executable Program to a verified
execution image.
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
_Avoid_: effect-blind DCE, bytecode optimization

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
this boundary. Physical elaboration consumes Runtime ANF; VM CFG emission
consumes only verified Physical ANF.
_Avoid_: general Buslane ANF, effect-erased Buslane, backend node filtering

**Runtime ANF Callable Catalog**:
The complete pre-emission inventory of Runtime ANF callables. It assigns each
top-level and nested function one stable identity together with its lexical
evidence scope, owner, recursive group, captures, and allocation provenance.
LoisVM planning consumes this catalog instead of discovering functions while
emitting bodies.
_Avoid_: source value as function identity, emission-time function allocation

**Runtime Value Port**:
A stable producer, consumer, parameter, result, capture, aggregate, or join
position in one semantic callable instance to which physical shape is assigned.
_Avoid_: source type, function-wide family context

**Physical Value Shape**:
The one interned runtime representation selected for a Runtime Value Port,
including exact erased-evidence, callable-ABI, or data-family identity.
_Avoid_: Value ABI alone, candidate family set, semantic type

**Representation Constraint Graph**:
The lowering-private graph collected from Runtime ANF after semantic callable
flow reaches a fixed point. Its stable nodes are runtime value ports and
callable targets; its edges express identity flow and explicit non-local
representation requirements. Its solver owns specialized families, callable
targets, workers, and bridge requirements, but does not duplicate canonical
scalar classification on every node.
_Avoid_: callable-instance side effects, emitter query tables, source-type key

**Representation Solution**:
The complete immutable assignment of non-local representation choices produced
by solving the Representation Constraint Graph. It is an input to Physical ANF
materialization, not an IR consumed beside the original Runtime ANF tree.
_Avoid_: demand sidecar, ambient family array, emission-time choice

**LoisVM Runtime Type Arena**:
The lowering-private arena seeded from Runtime ANF's immutable type-expression
catalog. It owns expressions derived by runtime substitution and beta
reduction; no derived identity is written back into Runtime ANF.
_Avoid_: mutable Runtime ANF metadata, Buslane normalization, shared intern table

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

### VM CFG And Bytecode Production

**VM CFG**:
The compiler-private value-based control-flow graph between lower semantic IR
and LoisVM bytecode.
_Avoid_: persisted bytecode CFG, source control flow

**Canonical Pre-ARC VM CFG Image**:
The compiler-private nominal whole-image boundary produced after local
devirtualization, consuming-projection selection, simplification, borrow
preparation, and metadata validation. It owns the sole reachable and canonical
function table plus the complete old-to-canonical FunctionId relation. Function
equivalence includes semantic value metadata and canonical referenced-function
classes; equal rendered instructions with different data-family or callable
ABI facts remain distinct. The public API never exposes this value before ARC,
slot allocation, bytecode emission, and bytecode verification have completed;
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
The lowering-local structural conversion between two callable representations.
Direct invocation fuses the conversion into the call; only first-class escape
materializes an adapter function, environment, and closure.
_Avoid_: eager adapter allocation, runtime-layout-only type alignment

**Callable Adapter Recipe**:
The canonical lowering-owned identity of one materialized callable conversion,
containing its source and target runtime ABIs, physical parameter alignment,
evidence sources, concrete layout recipes, nested callable conversions, and
result operation. The recipe is interned before its adapter FunctionId is
allocated; each materialization site supplies its own captured values to the
one worker selected by that recipe.
_Avoid_: source-type spelling key, VM CFG body equivalence, call-site worker allocation

**Physical ANF**:
The compiler-private structural IR materialized from Runtime ANF and one
Representation Solution. Its constructor is the sole owner of the final
Physical Value Contract at every call, construction, match, binding, capture,
allocation, join, and function boundary: it combines solved non-local choices
with canonical runtime-type classification exactly once. Its verifier proves
the complete physical contract before VM CFG emission.
_Avoid_: unchanged Runtime ANF plus sidecars, site-key lookup, emitter fallback

**Callable Instance Plan**:
The typed Runtime ANF fixed point over callable identities, evidence
applications, aliases, parameters, results, finite allocation sites, aggregate
members, and recursive groups. It owns only semantic flow and supplies those
facts to the Representation Constraint Graph; it never selects physical
families, workers, bridges, or final function reachability.
_Avoid_: recursively nested aggregate fact, first-seen recursion, emission-time demand

**Callable Invocation Contract**:
The exact Physical Value Shapes of a callable's evidence inputs, user
parameters, and result, independent of the closure environment that implements
it. The Representation Solution freezes every generic implementation
contract before planning workers or function bodies; higher-order contracts
refer to those frozen facts rather than reconstructing an ABI from Runtime ANF
type syntax. Body planning verifies the contract and cannot replace it.
_Avoid_: CallableValue layout, source function type, capture schema,
type-derived fallback ABI

**Recursive Callable Contract Graph**:
The lowering-owned finite graph of Callable Invocation Contracts. Callable
positions refer to graph identities instead of recursively embedding another
contract. Reservation and completion construct recursive demand SCCs; a
partition-refinement verifier canonicalizes bisimilar nodes while preserving
stable aliases for provenance. Open or structurally expanding demand retains
the generic implementation rather than inventing an unbounded worker family.
Contract identities canonicalize only physical ABI; each recursive worker
edge separately rebases alpha-renamed residual evidence onto the worker's
verified binder scope.
_Avoid_: recursive ABI tree, depth cutoff, recursion fallback, post-freeze ID
reindexing, free evidence identity as graph structure

**Representation Transition**:
The canonical source-contract, target-contract, and operation-kind identity for
one non-identity physical flow. Physical ANF bridge planning and callable
adapter value-flow planning are its only producers; VM CFG emission consumes
the attached transition and may not reclassify it from emitted opcodes.
_Avoid_: source-type spelling, layout-only equality, Explore opcode inference

**Representation Transition Occurrence**:
A VM CFG emission event that consumes one Physical ANF transition site. The
emitter owns its stable per-function event ordinal, transition, boundary,
binding, optional collection ordinal, and exact produced-or-consumed VM CFG
value anchor; repeated equal sites remain repeated events. VM CFG cleanup may
remove an event only by removing its anchored operation. When structurally
equal functions merge, their surviving anchored transition streams must agree,
one representative stream survives, and its origins become the union of the
merged functions. Final verification matches each surviving erase/unerase
event to the corresponding typed VM CFG operation.
_Avoid_: planner-visit set, diagnostic string site, source-binding merge key,
kind-only instruction count, post-cleanup event inference

**LoisVM Lowering Provenance**:
The immutable observation sidecar exported with initial VM CFG and final
bytecode: canonical function origins, the Recursive Callable Contract Graph,
Representation Transitions, and their occurrences. Explore consumes this
sidecar directly and never reconstructs these facts from labels, function
positions, or instructions.
_Avoid_: scale metric as semantic fact, renderer-owned ABI relation

**Callable Producer Contract**:
The Physical ANF fact attached to one callable-producing atom. A function or
evidence-lambda allocation may construct the selected implementation with the
captures in its lexical environment. A reference to an existing callable must
retain that value's frozen invocation and environment; it cannot recreate the
source definition under a different representation. A consumer that requires
another invocation names an explicit callable bridge.
_Avoid_: rematerializing a callable reference from its source function,
semantic-target-derived producer ABI, capture reconstruction at a use site

**Function Representation Variant**:
One semantic callable instance paired with one Callable Invocation Contract,
exact capture shapes, and the physical assignments required by its body.
_Avoid_: semantic callable instance, ABI-only worker key

**Callable Materialization Contract**:
The allocation-site-owned tuple of semantic callable target, selected generic
or worker implementation, Callable Invocation Contract, and capture flows.
Physical planning produces it once; VM CFG emission may only materialize that
record and cannot reselect an implementation from the use site.
_Avoid_: worker boolean, emission-time ABI reconstruction

**Representation Bridge**:
An explicit planned conversion between two Physical Value Shapes, currently
erase, unerase, or callable adaptation.
_Avoid_: emission fallback, implicit data-family reboxing

**Representation Worker**:
A concrete-ABI implementation of a generic function that consumes no
first-order layout witnesses and introduces no erased-value bridges at its
planned direct call sites. Each complete canonical physical function contract
owns at most one worker. The generic implementation remains available for open
or incompatible components; cleaned whole-image reachability removes any
implementation that is not actually referenced.
_Avoid_: source-local selection, code-size score, pre-cleanup reachability

**Recursive Representation Demand SCC**:
An exact strongly connected component of representation-worker demands linked
through first-class callable parameters, results, captures, or stored members.
Because a Callable Invocation Contract is structural and has no recursive name,
the planner emits no worker for a recursive demand component, and every
first-class edge targeting it retains the generic invocation contract. Acyclic
targets may use worker contracts only when the worker preserves one physical
slot per logical callable parameter; scalar-expanded workers remain direct-call
contracts. Each callable allocation freezes its implementation, invocation ABI,
and capture contract together, and emission consumes that single fact.
_Avoid_: DFS-order seed ABI, structural contract expansion,
recursive callable worker ABI, implementation/ABI reselection during emission

**Nominal Data Representation Family**:
The declaration-owned uniform fallback storage ABI for one nominal data type.
It is the canonical generic choice for every open, existential,
recursive-expanding, unproved joined, or incompatible use.
_Avoid_: allocation-local object shape under the declaration family,
runtime-ABI-only family key, hidden-binder specialization

**Specialized Data Representation Family**:
A Representation Solution identity owning one nominal owner's complete
constructor tag, member-shape, and stored-evidence contract. Its identity
includes nested physical shapes, not only closed source arguments.
_Avoid_: per-allocation family, body-wide type guess, partial constructor family,
emission-time family discovery, reboxing fallback

**Closed Aggregate Scalar Replacement Plan**:
The immutable proof that one aggregate allocation does not escape and that
every reachable consumer has exact allocation identity. The plan forwards
payload facts directly to those consumers and removes the allocation; it never
changes the nominal family's storage ABI. An open, escaping, or ambiguous use
keeps the ordinary allocation unchanged.
_Avoid_: alternate object shape under one family, optimistic escape assumption,
emission-time scalar replacement discovery

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
_Avoid_: source borrow checker, bytecode verifier

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
_Avoid_: an unverified `FunctionBody`, final LoisVM bytecode

**Physical Slot Plan**:
The validated mapping from an ARC-Final VM CFG to compatible physical LoisVM
slots. The plan owns the verified body it maps and is produced before bytecode
construction.
_Avoid_: post-bytecode slot rewrite, Wasm local plan

**Bytecode Emission**:
The one-pass projection of finalized VM CFG through a Physical Slot Plan into
LoisVM bytecode.
_Avoid_: allocation pass, emitted-opcode remapping

**Finalized Callable ABI**:
The canonical callable shape derived from finalized slot metadata and interned
once for functions, runtime imports, and indirect call sites.
_Avoid_: source-type reconstruction, verifier repair

**Bytecode Finalization**:
The boundary that produces a complete LoisVM image only after ownership,
physical-slot, callable-ABI, and bytecode verification succeed.
_Avoid_: partially valid image, backend-specific repair
