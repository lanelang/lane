# LoisVM

LoisVM owns Lane's portable execution image, bytecode verification and
interpretation, runtime representation, host-call boundary, and bytecode-to-Wasm
contract.

## Language

### Boundaries

**LoisVM Bytecode**:
The register-style erased portable execution language consumed by LoisVM
implementations.
_Avoid_: Buslane, ANF, compiler-private VM CFG

**Bytecode Image**:
A closed executable image containing functions, globals, layouts, object shapes,
constants, callable ABIs, and a selected entry.
_Avoid_: linked semantic core, loaded runtime instance

**Verified Bytecode Image**:
A Bytecode Image accepted by the LoisVM semantic verifier as complete and
internally consistent.
_Avoid_: trusted compiler output, decoded bytes alone

**Bytecode Format Compatibility**:
The current-only bytecode contract whose persistence version is owned by the
enclosing linked-program artifact schema.
_Avoid_: independent bytecode version negotiation, legacy fallback decoder

**Loaded Executable Image**:
A reusable Verified Bytecode Image with host imports resolved and optional
backend compilation prepared.
_Avoid_: active heap, partial load result

**Execution Instance**:
The single-shot frames, heap, globals, runtime context, and limits used by one
execution attempt.
_Avoid_: loaded image, resumable failed VM

### Runtime Value Model

**Representation**:
The physical scalar form used to store or pass a bytecode value.
_Avoid_: Lane source type, semantic value category

**Cleanup Category**:
The ownership action associated with a stored value: trivial or one of the
owned reference forms.
_Avoid_: source lifetime, borrow provenance

**Semantic Value Kind**:
The bytecode category distinguishing scalars, layouts, callables, byte
sequences, data families, environments, opaque references, and erased values
even when their Representation and Cleanup Category coincide.
_Avoid_: source type, physical representation

**Value ABI**:
The complete runtime value contract formed by Representation, Cleanup Category,
and Semantic Value Kind.
_Avoid_: representation alone, source type

**Result ABI**:
The function result contract: zero-width `Unit` or one complete Value ABI.
_Avoid_: destination-owned cleanup, representation-only result

**Slot Metadata**:
The fixed Value ABI of a physical function-local slot plus any erased ownership
companion it requires.
_Avoid_: logical compiler value, mutable runtime tag

**Data Family**:
The bytecode identity shared by all constructor Object Shapes of one nominal
data boundary.
_Avoid_: constructor tag, source type identity

**Object Shape**:
The exact semantic member schema of one data constructor or closure environment.
_Avoid_: raw memory offset list, nominal source type

**Layout Recipe**:
The portable image-owned description from which a backend derives storage and
ownership behavior.
_Avoid_: source type descriptor, backend address

**Layout Witness**:
A runtime-selected Layout Recipe carried across representation-polymorphic
boundaries.
_Avoid_: source effect syntax, full runtime type object

**Checked Object Unerasure**:
The boundary that validates an erased reference against the exact Object Shape
required by its destination before establishing shape provenance.
_Avoid_: unchecked cast, projection-time shape guess

**Unified Function Table**:
The image-wide identifier space containing both bytecode bodies and runtime
imports.
_Avoid_: separate import table, source symbol table

**Instance Global**:
An immutable value initialized once per Execution Instance and rooted outside
ordinary call frames.
_Avoid_: image constant, mutable global variable

**Instance Initializer**:
The optional bytecode function that initializes Instance Globals before the
selected entry executes.
_Avoid_: source module loader, Wasm start policy

**Global Lifecycle Plan**:
The verifier-owned canonical root order, companion mapping, owned-root order,
and cleanup facts consumed by every execution tier.
_Avoid_: backend-reconstructed initialization flags, runtime metadata guess

### Calls And Closures

**Callable ABI**:
The canonical execution signature formed by layout-witness Value ABIs, user
parameter Value ABIs, and one Result ABI.
_Avoid_: source function type, arity-only signature

**Callable ABI ID**:
An image-local identity into the duplicate-free Callable ABI table used by
indirect calls.
_Avoid_: Function ID, runtime type tag

**Callable Value**:
A first-class function represented by a target function and optional owned
closure environment.
_Avoid_: source lambda, mandatory closure object

**Direct Call**:
A call whose target function is fixed by the instruction.
_Avoid_: callable-value call, source call expression

**Value Call**:
An indirect call through a Callable Value that declares the expected Callable
ABI ID.
_Avoid_: unchecked dynamic dispatch, closure unpack sequence

**Tail Call**:
A direct or value call that transfers control without a return continuation in
the current frame.
_Avoid_: ordinary call followed by return, jump

**Closure Environment**:
The immutable Object Shape-backed capture record owned by a Callable Value.
_Avoid_: user parameter tuple, implicit current frame

### Ownership

**Reference-Counted Object**:
A dynamic object whose lifetime is controlled by explicit compiler-inserted
retain and release operations.
_Avoid_: tracing-GC object, unmanaged pointer

**Ownership Transfer**:
A proven last-use movement of an existing owner without incrementing its
reference count.
_Avoid_: retained copy, borrowed use

**Borrowing Read**:
A read that creates no new owner and remains valid only while an owning root is
live.
_Avoid_: retained projection, serialized lifetime

**Verifier Borrow Provenance**:
The verifier's owner root and member path for a borrowed value across moves,
projections, transfers, and control-flow joins.
_Avoid_: runtime ownership tag, source lifetime

**Callee-Owned Call ABI**:
The convention that consumes reference-bearing arguments and returns an owned
result.
_Avoid_: borrowed-argument ABI, ownership-neutral call

**Ownership-Empty Exit**:
A return or tail transfer after every current-frame owner has been released or
transferred.
_Avoid_: implicit frame scan, leaked local owner

**Image-Owned Static Object**:
An immutable object whose lifetime is owned by the Loaded Executable Image and
does not participate in dynamic reference-count changes.
_Avoid_: dynamic ARC object, independently freed constant

### Runtime Imports

**Runtime Import**:
A Unified Function Table entry naming a synchronous host operation and its
direct erased ABI.
_Avoid_: algebraic effect operation, bytecode stub

**Runtime Symbol Registry**:
The host-owned map from versioned runtime symbols to ABI descriptions and host
implementations.
_Avoid_: per-call lookup policy, source extern table

**Runtime Context**:
Borrowed execution-local host services supplied implicitly to Runtime Imports.
_Avoid_: Lane value, closure environment

**Runtime Import Contract Validation**:
The load-time comparison of each Runtime Import's complete ABI with its resolved
host binding before execution begins.
_Avoid_: source type checking, arity-only check

**Opaque Host Object**:
A host-owned value represented in Lane by a managed execution-local opaque
reference.
_Avoid_: serialized host pointer, source nominal layout

**Host Object Table**:
The Execution Instance-owned table that connects opaque Lane references to
typed host payloads and cleanup behavior.
_Avoid_: process-global registry, persistent object identity

**Runtime Import Failure**:
A fatal out-of-band host-call failure that produces no Lane value and ends the
current execution.
_Avoid_: Lane effect operation, recoverable result

### Verification And Failure

**Bytecode Verifier**:
The LoisVM-owned semantic trust boundary for identities, value shapes, call
contracts, control flow, initialization, and ownership.
_Avoid_: decoder framing, source typechecker, backend repair

**Atomic Bytecode Load**:
The all-or-nothing path from decode through verification, import binding, and
backend preparation to a Loaded Executable Image.
_Avoid_: partially published image, recoverable load state

**Execution Resource Limit**:
A configured execution bound whose exhaustion terminates the current Execution
Instance as a structured runtime failure.
_Avoid_: malformed bytecode, source effect

**Engine Trap**:
A backend failure outside portable Lane execution semantics, reported with
best-effort engine detail.
_Avoid_: Runtime Import Failure, recoverable Lane value

### Wasm Backend

**Pure Wasm Compiler**:
The cross-target lowering from a Verified Bytecode Image to a WebAssembly module
without loading or executing it.
_Avoid_: Wasmoon loader, direct Buslane-to-Wasm lowering

**Wasm Compiled Tier**:
The execution path that runs Pure Wasm Compiler output through a WebAssembly
engine.
_Avoid_: LoisVM interpreter, native code backend

**Lane Wasm Feature Profile**:
The explicit WebAssembly feature contract required by Lane-generated modules.
_Avoid_: generic WebAssembly 1.0 claim, Wasmoon-specific semantics

**Lane Wasm Module ABI**:
The external contract between generated Lane Wasm modules and their execution
host.
_Avoid_: source module exports, Component Model ABI

**Lane Wasm Internal Runtime ABI**:
The compiler-private versioned contract shared by Wasm lowering and the matching
LoisVM backend for internal runtime helpers.
_Avoid_: public Runtime Symbol Registry, user-provided import API
