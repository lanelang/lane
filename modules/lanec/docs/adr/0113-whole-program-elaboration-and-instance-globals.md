# Whole-program elaboration and instance globals

> The single selected-entry and initializer-entry-cleanup lifecycle described
> here is superseded by ADR-0143. Whole-Program Elaboration now consumes a
> complete requested export root set, and retained initialization executes via
> the WebAssembly start section at instance creation.

Lane inserts Whole-Program Elaboration between linked Buslane and Physical lowering. It accepts a linked program and a complete requested export set and produces one Executable Program containing closed effect-aware CPS Core, externals, certified exports, and an Initializer Retention Root Set. CPS Core terms remain the sole owner of initializer bodies and source order. Physical lowering consumes this product rather than reconstructing roots from the linked program.

The target-independent `lanec/executable` package owns Whole-Program Elaboration and the Executable Program model. Execution-image targets such as `lanec/loisvm_lowering` depend on this package. The executable package does not depend on LoisVM bytecode, VM CFG, Wasm, or another execution-image target.

The target-independent `lanec/module/link` package owns the linking algorithms and Linked Program model consumed by `lanec/executable`. Compilation orchestration depends on `lanec/module/link`, while the link package does not depend on executable elaboration, artifact encoding, or an execution-image target. The current `module/compile` LoisVM convenience methods move to the orchestration boundary so the link model no longer imports `lanec/loisvm_lowering`.

The resulting dependency direction is `module/compile -> module/link`, `executable -> module/link`, and `loisvm_lowering -> executable`. This also resolves the repeated `link_*.mbt` package-boundary smell in `module/compile` without introducing a dependency cycle.

Lane type checking requires the empty effect for top-level `let` initializers. Whole-Program Elaboration treats the selected entry as the semantic root and retains only the transitive top-level initializer dependencies reachable from that entry. Required initializers remain in linked declaration order. Unreachable pure initialization is not part of the selected executable instance, so its allocation, divergence, resource exhaustion, or fatal primitive condition is not observed by that instance.

Whole-Program Elaboration computes export-set reachability while effect and top-level binding information remain available, records only the retained initializer ValueIds, and then runs effect-aware core optimization. Each export carries its admitted Core Wasm contract. Physical lowering supplies the complete root set to occurrence analysis and scans Runtime ANF terms once in canonical term order to produce initializer steps. It does not reconstruct a second schedule or copy initializer expressions.

The Physical Program contains an ordered Instance Global table and an optional Instance Initializer `FunctionId`. A dynamic Instance Global requires an initializer. The initializer has no context, layout witnesses, user parameters, or result value. It initializes non-companion globals in table order; an `OwnedErased` owner initializes its immediately preceding companion atomically. Wasm emission installs a private wrapper as the module start function; an image without retained initialization omits it.

Each Instance Global records the same erased representation and cleanup category used by a local slot. An `OwnedErased` global has an immutable companion Instance Global containing its `LayoutId`. Bytecode can initialize a global exactly once by consuming a local owner into it and can borrow an initialized global into a local slot. Bytecode has no general global mutation, swap, or consuming global load. A later consuming or escaping use of a borrowed global value requires compiler-inserted retain-copy in the ordinary ARC insertion pipeline.

The verifier proves initialization as a canonical table-order prefix, rejects an out-of-order or duplicate initialization, proves every borrow observes an initialized prefix, and requires the complete prefix at every normal initializer return. Wasm emission consumes that proof rather than repeating per-operation guards. Failed initialization fails instantiation, so no export becomes observable. Instance Globals remain owned by the WebAssembly instance and are discarded with it; Lane does not generate a second export-return cleanup lifecycle.

Creating a WebAssembly instance materializes static state and executes the initializer through the module start section. Export calls happen only after successful instantiation. Instance Globals belong to that instance rather than the reusable loaded module and may be observed by any exported function.

The Wasm tier does not map heterogeneous Lane values to Wasm globals. It stores them in a linear-memory Instance Root Table owned by the WebAssembly instance. A private start wrapper invokes the initializer. Public export wrappers only project the admitted Core Wasm ABI and call their shared Physical function. Static image bytes, immutable allocator constants, and active data or element segments retain their declarative-instantiation role.

A scalar external used to initialize a Lane global is represented as a zero-argument runtime import invoked by the Instance Initializer. The current bytecode format restricts its result to the supported primitive host ABI; richer host-owned values require a later decision.

ADR-0114 records the historical introduction of the exact table order, GlobalId representation, metadata records, and global instruction encodings. ADR-0116 retains those fields in the sole current format while removing bytecode-local versioning.

## Consequences

- Whole-Program Elaboration becomes the single compiler seam between linking and LoisVM lowering.
- Executable Program replaces the shallow parallel-parameter lowering boundary.
- The independent `lanec/executable` package owns this seam and remains target-independent.
- The independent `lanec/module/link` package owns Linked Program construction and the link model.
- Compilation orchestration, executable elaboration, and LoisVM lowering follow a one-way dependency graph.
- Whole-Program Elaboration retains only export-set-reachable initializer dependencies.
- Executable Program stores initializer ValueIds and certified exports but no copied initializer bodies or schedule.
- Execution Image Lowering owns transitive function, external, and runtime-import reachability collection.
- Runtime ANF term order is the sole source of retained top-level initializer execution order.
- Instance Globals are immutable after one consuming initialization.
- Global reads borrow; ARC insertion owns any required retained copies.
- Initialized globals are roots outside ordinary call frames and live for the WebAssembly instance lifetime.
- Initialization failure prevents the instance and all of its exports from becoming observable.
- Wasm output uses the module start section for retained initialization.
- Public export wrappers do not own initialization or instance cleanup.
