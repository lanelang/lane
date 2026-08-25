# Per-value physical representation planning

Status: accepted; the sidecar implementation is being replaced by structural
Physical ANF under ISS-387.

## Context

Runtime ANF owns semantic runtime types, explicit representation evidence, and
one stable identity for every callable and allocation site. Its Callable
Instance Plan can prove semantic callable flow through parameters, results,
captures, aggregate members, recursion, and immutable globals. It cannot make
a semantic type the identity of a selected physical representation.

The same semantic data type may cross an open boundary through its uniform
declaration family and occur elsewhere in a closed specialized component. A
function may also mention several specialized families while one parameter
belongs to only one of them. Passing an ambient family array through lowering
therefore has no coherent meaning: it is neither a value representation nor a
callable contract. Selecting from that array while emitting a body creates a
second representation producer.

## Decision

After the semantic Callable Instance Plan reaches a fixed point, one traversal
builds a Representation Constraint Graph over stable runtime value ports and
canonical callable targets. One solver produces the complete Representation
Solution. The solution is then materialized with Runtime ANF as a structural,
verified Physical ANF program. VM CFG emission accepts only Physical ANF; it
does not traverse Runtime ANF beside representation side tables.

The planner assigns every runtime value port one interned Physical Value Shape.
Ports include parameters, results, bindings, call operands and results,
captures, constructor results and members, match scrutinees and binders, and
control-flow joins. A shape directly identifies Unit, a concrete scalar or
reference category, an erased representation-evidence contract, a Callable
Invocation Contract, or a Data Representation Family. No shape contains or is
selected from an ambient set of possible families.

The Callable Instance Plan remains the sole owner of semantic callable
identity, generic application, exact target alternatives, allocation flow, and
recursive semantic closure. It supplies facts to the constraint graph but does
not select families or workers. The Representation Solution is the sole owner
of non-local representation choices: specialized families, callable targets,
workers, and bridge requirements. The Physical ANF constructor combines those
choices with canonical runtime-type classification and solely owns every final
value contract carried to its verifier and to VM CFG emission.

## Physical contracts

A Callable Invocation Contract contains the exact physical shapes of hidden
representation-evidence inputs, user parameters, and the result. It is the
contract stored in callable values and data members and later projected to the
LoisVM callable ABI.

Generic implementation contracts are frozen before representation workers or
function bodies are planned. A higher-order generic contract refers to the
already planned contract of its callable-shaped parameter or result; it is not
reconstructed from Runtime ANF type syntax. Body planning only verifies and
consumes the frozen boundary. This ordering makes the generic elaboration one
real function contract rather than a type-derived default that can disagree
with callable-flow provenance.

A Function Representation Variant contains one semantic callable instance,
one Callable Invocation Contract, exact capture shapes, and the value-shape
assignment required by its body. Capture layout belongs here because two
closures may share an invocation contract while storing different environment
shapes. One canonical function-variant key produces at most one worker.

Only a function or evidence-lambda allocation in the current Runtime ANF body
may construct a Function Representation Variant from its lexical captures. A
reference to an existing callable consumes that producer's frozen invocation
and environment. It never recreates the referenced source definition at the
use site; a different consumer invocation requires an explicit callable
bridge. Producer invocation is authoritative when interpreting a callable
interface, while semantic type supplies the parameter and result meaning.

A Data Representation Family Contract contains one nominal owner and the
complete constructor tag, member-shape, and stored-evidence schema. A
declaration family is the canonical uniform fallback. A specialized family is
identified by its complete physical storage contract, not merely by source
generic arguments. This distinction is required because the same closed source
type may contain either declaration-family or specialized nested values.
Recursive fields refer to their data-family SCC identity and do not expand a
recursive type tree.

## Constraint closure

Physical planning is finite constraint solving over value ports and flow
edges. Alias, parameter, result, capture, join, construction, match, and call
edges require exact compatible shapes. A value with several consumers has one
producer shape; a consumer that needs another shape must name one explicit
planned bridge.

The supported bridges are erase, unerase, and callable adaptation. Each bridge
has one canonical source and target contract and at most one worker. There is
no implicit conversion between declaration and specialized data families. A
future structural data conversion would require its own explicit contract and
proof rather than a lowering fallback.

The canonical generic elaboration supplies a total baseline assignment. A
specialized data family or function variant is accepted only when its complete
connected component has a consistent closed assignment. Open, existential,
incompatible indirect, or unproved joined flow rejects the whole candidate and
keeps the baseline. Generic callables and declaration families therefore remain
correct independently of optimization.

Distinct open and closed components may select different physical contracts
for the same semantic source function. Each complete canonical function
contract owns at most one worker, while the generic implementation remains the
correct baseline for open flow. Cleaned whole-image function reachability, not
specialization policy, removes implementations that have no runtime consumer.

Recursive specialization uses a worklist of canonical function-variant and
data-family contracts. The callable SCC must prove that every recursive
transformation is a projection or permutation of existing binders or selects
from a finite set of closed constants. Failure keeps the complete SCC generic;
there is no depth, worker-count, function-size, frequency, score, or speculative
fallback policy.

## Phase responsibilities

- Runtime ANF owns semantic runtime types and representation evidence.
- The Callable Instance Plan owns semantic callable and allocation flow.
- The Representation Constraint Graph owns physical flow components and
  requirements; its solver owns non-local family, callable-target, worker, and
  bridge choices.
- The Physical ANF constructor owns every final value, function, and environment
  contract by combining the solution with canonical runtime classification
  once; its verifier checks those structural facts before emission.
- VM CFG emission projects verified Physical ANF into explicit values and
  instructions; it makes no representation decision.
- ARC augments VM CFG values with ownership flow without changing their
  physical shape.
- Final callable ABI construction and physical slot allocation consume the
  validated ARC-final metadata and do not reconstruct source types or
  specialization policy.

## Consequences

- CPS answer specialization remains an instance of general representation
  specialization. No CPS name or source effect participates in physical shape
  selection.
- Semantic callable identity and physical function variants remain distinct.
- Existing callable values retain their producer ABI and capture environment;
  specialization cannot rematerialize them from source provenance.
- Callable-valued data members naturally carry nested data families through
  their Callable Invocation Contract; no parallel family map is required.
- Construction and matching name one exact Data Representation Family and
  cannot accidentally share tags or shapes with another family.
- A planner defect is reported before VM CFG emission. The emitter cannot hide
  it by choosing a generic family, filtering a context, or reboxing a value.
- Physical ANF has a necessary invariant but remains compiler-private and is
  neither persisted nor paired with an independently traversed Runtime ANF
  tree.
- Source language, linked-artifact, and bytecode schemas do not change merely
  because the compiler has a stronger pre-emission representation seam.

## Rejected alternatives

Threading a family array, a type-to-family substitution, or a body-wide family
map is rejected because one semantic type may have different representations
at different value ports. Whole-program monomorphization is rejected because
generic evidence-passing semantics and separate compilation remain the
correctness baseline. A uniform boxed representation would be sound but would
discard Lane's accepted natural scalar ABI. Emission-time filtering, subset
matching, and reboxing fallbacks are rejected because they create a second
representation owner after the plan is frozen.
