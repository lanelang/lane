# Effect erasure before bytecode

LoisVM bytecode is effect-erased. After linking and executable selection, but before ordinary ANF, compiler-private VM CFG lowering, or bytecode construction, `lanec` runs reachable effect specialization, handler elaboration, `mon-trans`, `open-resolve`, and `monadic-lift`. Their output contains no `perform`, `resume`, `handle`, abstract effect-context opening, effect parameter, latent effect, or effect-specific compiler node. LoisVM therefore requires no effect instruction, handler stack, operation table, stack capture, or effect-aware calling convention.

## Lane-specific protocol

Lane does not copy Koka's process-global evidence vector or yielding flag. The pre-bytecode compiler temporarily represents handlers through explicit immutable handler dictionaries and explicit effect-context arguments. These are compiler-private typed values, not LoisVM concepts. After lowering they are indistinguishable from ordinary data, closures, parameters, projections, and calls, and LoisVM assigns them no handler identity or special ABI position.

Every normalized effect row is treated as an ordered list of context terms. A concrete `Singleton(effect, arguments)` term has one handler-dictionary argument whose immutable fields are ordinary operation-clause callables. An abstract `Parameter(effect_parameter)` term has a compiler-generated companion type parameter and an opaque ordinary value parameter carrying the context supplied for that effect argument. Canonical `Union` rows flatten to the ordered concatenation of their terms. Empty rows require no context argument.

The companion type/value pair keeps effect-polymorphic context passing typed without introducing a universal runtime operation tag or heterogeneous lookup table. A function can forward an abstract effect context but cannot inspect it. A known operation always selects a statically known field from the dictionary for its declared concrete effect. Lexical handling substitutes the dictionary binding for that concrete effect while preserving all unrelated context terms.

Lane treats every nonempty or abstract latent effect as potentially multi-resumptive. Such a function is selectively translated to answer-type CPS:

```text
(arguments) -> A ! effects

becomes conceptually

[Answer](context_arguments..., arguments..., continuation : (A) -> Answer) -> Answer
```

Pure functions remain direct style. The generated `Answer` parameter is an ordinary type parameter and therefore uses the existing representation-erasure and layout-witness machinery when necessary. This selective CPS protocol, rather than a yielding side channel, supplies both normal continuation composition and reusable resume values.

## Compiler-private forms

The effect-erasure package may use the following temporary semantic forms. They are never serialized and are forbidden after their owning pass:

- `Invoke(operation, payloads)` denotes a statically identified operation before its dictionary field and current continuation are supplied.
- `Install(effect, clauses, body, final)` denotes a lexical deep handler after Buslane syntax elaboration but before context substitution.
- `Bind(computation, continuation)` denotes the selective continuation boundary introduced around a monadic call or branch.
- `OpenContext(source_effect, target_effect, bindings)` denotes effect subsumption before concrete context arguments are selected.
- `ContextArgument(term, value)` records one typed concrete dictionary or abstract companion context during resolution.

These forms belong to one compiler-private effect-lowering representation. Separate pass result types are not required, but each pass must reject forms that violate its input contract and its result must satisfy the next invariant.

## Reachable effect specialization contract

Input is the linked whole-program executable with a selected entry, ordered instance initializers, and runtime roots. Module artifacts remain generic Buslane; specialization is an executable-construction step and does not change the `.lmo` format.

The pass starts from executable roots and creates a callable instance for every reachable concrete tuple of kind-`Effect` arguments. It substitutes those arguments through the callable's type, latent effects, body metadata, and nested calls, then continues the worklist from the specialized body. Ordinary kind-`Type` polymorphism remains generic. Calls are rewritten to their specialized callable identities, and unreachable unspecialized effect-polymorphic callable bodies are not passed to effect lowering.

This specialization is required before selective CPS because an opaque companion context is tied to the `Answer` at which its concrete dictionary was constructed. Such a value may be forwarded at the same `Answer`, but it cannot be reused when a handler changes the local answer to `M_F<H>`. Specialization makes each reachable residual row concrete, allowing `mon-trans` to construct the relay dictionaries described below. If a reachable handler still has an abstract residual row after specialization, compilation fails at this boundary rather than generating an answer-unsafe context reuse or a runtime effect lookup.

Output is a root-reachable executable program in which every handler residual effect that crosses an answer change is concrete. Kind-`Effect` parameters may remain only in compile-time-only nominal metadata that the existing representation-erasure path removes; they cannot determine executable effect control flow or runtime context selection.

## Handler elaboration contract

Input is a reachable-effect-specialized, verified Buslane executable with normalized effect objects and explicit `Perform`, `Handle`, and `Resume` expressions. Linked operation metadata, type applications, handler tables, and the selected runtime-operation conventions are available.

Handler elaboration replaces Buslane handler syntax with `Invoke` and `Install`. Every operation alternative becomes an ordinary typed clause function taking its payloads and one resume callable. `Resume(id)` becomes an ordinary reference to that callable. A final clause remains associated with its `Install` until `mon-trans` gives it the correct outer context and continuation.

An operation clause executes under the context outside its own handler. The resume callable captures the continuation created inside the handled body, so invoking it re-enters the same deep handler. Calling the same resume callable more than once implements multi-shot resume without capturing a VM stack. The final clause executes exactly once on the handled body's ordinary result path and also uses the outer context.

Output contains no Buslane `Handle` or `Resume` expression. `Invoke` is the only remaining operation form, and `Install` is the only remaining lexical-handler form.

## `mon-trans` contract

Input is handler-elaborated effect-lowering core. Function types and call sites still carry normalized latent effects, and local continuations are not yet lifted.

`mon-trans` classifies every function or call with `Empty` effect as direct and every function or call with a concrete or abstract nonempty effect as monadic. It transforms monadic function types to the answer-type CPS shape, threads context terms in canonical order, and uses continuation builders to preserve strict left-to-right evaluation. Sequential definitions receive nested binds only around monadic computations. If any match branch is monadic, all branches join through one shared continuation. Identity continuations are eliminated.

`Invoke` becomes a call to the statically selected operation callable from the current concrete-effect dictionary, supplying payloads and the current continuation. No runtime operation identifier remains. `Install` constructs an immutable dictionary from its ordinary clause closures, substitutes that dictionary while transforming the handled body, transforms clause bodies and the final clause under the outer context, and then disappears.

The `Answer` parameter of a dictionary is the answer of the computation currently interpreted by that dictionary; it is not necessarily the enclosing function's final CPS answer. For an install whose result is `H` and whose unhandled residual row is `F`, `mon-trans` uses the Church-encoded residual computation

```text
M_F<H> = [Answer](context_arguments(F, Answer)..., continuation : (H) -> Answer) -> Answer
```

as the handled body's local answer. The installed effect dictionary is therefore instantiated as `Dictionary_E<M_F<H>>`. Each captured body continuation returns a fresh `M_F<H>`, so the clause-visible resume callable retains its source meaning `OperationResult -> H ! F`; after CPS rewriting it can run that residual computation with whichever residual contexts and continuation its call site supplies. Repeated calls rerun the immutable continuation closure and implement multi-shot resume.

Residual effects inside the handled body cannot reuse enclosing dictionaries whose answer type differs. `mon-trans` instead creates ordinary relay dictionaries at answer `M_F<H>`. A relay operation returns a suspended `M_F<H>` which, when later run, invokes the corresponding residual dictionary at the caller's actual answer type and recursively runs the captured continuation. The final clause and operation clauses are translated into the same residual computation. Once the handled body produces `M_F<H>`, the install is eliminated by running that computation with the actual outer contexts and continuation. When `F` is empty, `M_F<H>` simplifies to `H`, relay dictionaries are unnecessary, and elimination directly applies the outer continuation.

Output contains no `Invoke`, `Install`, Buslane effect expression, or source handler table. It may contain `Bind`, local continuation functions, explicit context arguments, and abstract `OpenContext` adaptations at effect-subsuming calls. All transformed function types have `Empty` latent effect, although compiler-private effect terms remain attached to context-selection plans until `open-resolve`.

## `open-resolve` contract

Input is mon-transformed core with explicit context arguments and possible `OpenContext` plans. Unlike Koka's open resolution, Lane performs no process-global evidence-vector swap and requires no restoration protocol.

The preceding `mon-trans` and selective-CPS rewrites materialize context arguments, including dictionary selection, abstract companion values, and aggregates for abstract effect parameters instantiated with concrete unions. `OpenContext` remains as a proof obligation recording the source contexts consumed by that generated call and the ambient target contexts claimed to supply them.

Resolution canonicalizes the source and target effect rows after type/effect substitution, proves that every source context term is present in the target row, and only then removes the marker. Missing source contexts are a compiler error rather than a runtime lookup. Lexically nested handlers of the same concrete effect need no mask search: the earlier symbolic selection chose the nearest dictionary, and the outer binding is captured by the generated clause closures.

Output contains no `OpenContext`, effect-row comparison, runtime effect tag, dynamic dictionary search, or effect-context restoration operation. Original kind-`Effect` parameters and latent effects have no remaining semantic use; only ordinary companion type/value parameters and ordinary dictionary values needed by generated code remain.

## `monadic-lift` contract

Input is open-resolved selective CPS with local bind continuations. All context passing is already explicit ordinary typed data flow.

`monadic-lift` validates the open-resolved compiler-private program and converts every generated local continuation into an ordinary Buslane function or type abstraction. It is the boundary from effect-lowering IR to ordinary effect-free Buslane; it does not introduce a second explicit closure/environment representation before ANF. Continuations are not split into Koka-style yielding and inline variants because Lane has no global yielding side channel: the direct fast path is the unchanged pure-function ABI, while every monadic path is explicit CPS.

The existing ANF-to-LoisVM lowering remains the single owner of physical closure lifting. It computes each ordinary nested function's free value bindings and free runtime type parameters, records generic layout-witness captures, creates environment shapes, and emits `MakeEnv`/`MakeClosure`. Keeping capture analysis there avoids duplicate environments and keeps closure representation, ownership, and ARC insertion aligned for source closures and generated continuations.

The lifted resume closure is reusable. Repeated calls are ordinary non-linear closure uses and therefore become retain-copy or borrow/transfer decisions during later VM CFG ownership analysis. A continuation closure captures the inner handler dictionaries needed to resume deeply; an operation-clause closure captures only the outer context in which the clause body executes. A generated handler dictionary never strongly captures itself, preventing an ARC cycle by construction.

Output is ordinary effect-free Buslane accepted by the ordinary ANF lowerer. It contains only ordinary functions, callable context abstractions over kind `Type`, data, projections, calls, matches, and control flow. Compiler-private bind nodes, source latent effects, and context plans are absent. Kind-`Effect` arguments that occur only in nominal data applications or hidden existential witnesses remain as compile-time metadata and are erased by the existing data-layout path; they are never converted into runtime context companions or layout witnesses. Free references in local functions are intentional inputs to the existing closure-lifting stage.

## Outer runtime operations

The selected entry's validated residual runtime effects seed root handler dictionaries before `mon-trans`. Each root operation callable invokes one synthetic ordinary external function with the stable runtime symbol and then continues through its supplied continuation. The v1 host boundary still accepts only synchronous primitive parameters and results, cannot retain Lane values, and cannot re-enter Lane execution.

The synthetic operation identity is used only to select the dictionary field and runtime symbol during compilation. Bytecode contains the external function call but no Buslane `OperationId`, handler record, effect row, or runtime-operation table. Generic runtime operations remain outside the primitive host ABI; source-generic handlers are compiled through ordinary companion context arguments instead.

## Boundary and failures

VM CFG lowering treats every residual effect-lowering form, kind-`Effect` parameter, or nonempty latent effect as a compiler-pipeline error rather than lowering it opportunistically. The LoisVM interpreter and Wasm tier consume exactly the same effect-erased bytecode and implement no independent source-effect semantics.

Consequences:

- Effect semantics belong to pre-bytecode compiler lowering rather than LoisVM.
- Reachable effect specialization follows linking and executable selection, then precedes handler elaboration, `mon-trans`, `open-resolve`, and `monadic-lift`.
- Lane uses explicit compiler-private dictionaries and selective answer-type CPS, not a global evidence vector.
- Pure functions preserve their existing direct ABI.
- Reachable concrete effect instantiations are specialized while ordinary type polymorphism remains generic.
- Remaining effect-polymorphic forwarding may use ordinary companion type/value parameters only when the context stays at the same `Answer`.
- Deep reinstallation follows from continuation capture; multi-shot resume is an ordinary reusable closure.
- LoisVM needs no `perform`, `resume`, `handle`, yield-state, or handler-context instruction.
- LoisVM function metadata has no distinguished handler-context or continuation field.
- External runtime effects appear as resolved ordinary primitive runtime calls.
- Continuation and dictionary objects use the ordinary closure, data, representation-erasure, and ARC contracts.
