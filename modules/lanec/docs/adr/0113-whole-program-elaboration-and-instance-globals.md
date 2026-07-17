# Whole-program elaboration and instance globals

Lane inserts Whole-Program Elaboration between linked Buslane and LoisVM execution-image lowering. It accepts a linked program and selected entry and produces one Executable Program that owns the complete top-level initialization plan, lowered core, externals, effect companions, and explicit Execution Root Set. LoisVM lowering consumes this product rather than the linked program, entry, and external map as parallel inputs.

The target-independent `lanec/executable` package owns Whole-Program Elaboration and the Executable Program model. Execution-image targets such as `lanec/loisvm_lowering` depend on this package. The executable package does not depend on LoisVM bytecode, VM CFG, Wasm, or another execution-image target.

The target-independent `lanec/module/link` package owns the linking algorithms and Linked Program model consumed by `lanec/executable`. Compilation orchestration depends on `lanec/module/link`, while the link package does not depend on executable elaboration, artifact encoding, or an execution-image target. The current `module/compile` LoisVM convenience methods move to the orchestration boundary so the link model no longer imports `lanec/loisvm_lowering`.

The resulting dependency direction is `module/compile -> module/link`, `executable -> module/link`, and `loisvm_lowering -> executable`. This also resolves the repeated `link_*.mbt` package-boundary smell in `module/compile` without introducing a dependency cycle.

Lane type checking requires the empty effect for top-level `let` initializers. Whole-Program Elaboration treats the selected entry as the semantic root and retains only the transitive top-level initializer dependencies reachable from that entry. Required initializers remain in linked declaration order. Unreachable pure initialization is not part of the selected executable instance, so its allocation, divergence, resource exhaustion, or fatal primitive condition is not observed by that instance.

Whole-Program Elaboration computes selected-entry reachability while effect and top-level binding information remain available, records the retained initializers as ordered execution roots, and then runs effect-aware core optimization. Execution Image Reachability Collection belongs to the subsequent lowering pipeline. It traverses those roots and retains only the functions, externals, and runtime imports needed by them. This keeps startup semantics in the Buslane-level Executable Program while leaving code-generation selection with the execution-image target.

LoisVM bytecode contains an ordered Instance Global table and an optional Instance Initializer `FunctionId`. A dynamic Instance Global requires an initializer. The initializer is a bytecode body with no context, layout witnesses, user parameters, or result value. Execution runs it exactly once before the selected entry; an image without dynamic globals may omit it.

Each Instance Global records the same erased representation and cleanup category used by a local slot. An `OwnedErased` global has an immutable companion Instance Global containing its `LayoutId`. Bytecode can initialize a global exactly once by consuming a local owner into it and can borrow an initialized global into a local slot. Bytecode has no general global mutation, swap, or consuming global load. A later consuming or escaping use of a borrowed global value requires compiler-inserted retain-copy in the ordinary ARC insertion pipeline.

Every execution instance tracks which globals have been initialized. Reading an uninitialized global, initializing one twice, or returning normally from an initializer that did not initialize every required global is an InternalRuntimeFailure under the trusted-image contract. If initialization fails, the selected entry is not called. Initialized globals are released in reverse initialization order on normal completion and on cleanup-capable initialization or entry failure. Cooperative cancellation must reach the same cleanup boundary; a non-unwinding engine interruption retains the weaker cleanup guarantee defined by ADR-0112 and still makes the instance terminal.

Creating an execution instance allocates only uninitialized per-instance state. Its single execution attempt runs initializer, selected entry, and global cleanup under one RuntimeContext and one set of cancellation, call-depth, and live-heap limits. Instance globals therefore belong to the Single-Shot Execution Instance rather than the reusable Loaded Executable Image.

The Wasm tier does not map heterogeneous Lane values to Wasm globals and does not add a Wasm start function. It stores globals in a linear-memory Instance Root Table owned by the execution instance. The exported `"lane.entry"` wrapper performs initializer invocation, selected-entry invocation, and cleanup. Static image bytes, immutable allocator constants, and active data or element segments retain their existing declarative-instantiation role.

A scalar external used to initialize a Lane global is represented as a zero-argument runtime import invoked by the Instance Initializer. The current bytecode format restricts its result to the supported primitive host ABI; richer host-owned values require a later decision.

ADR-0114 records the historical introduction of the exact table order, GlobalId representation, metadata records, and global instruction encodings. ADR-0116 retains those fields in the sole current format while removing bytecode-local versioning.

## Consequences

- Whole-Program Elaboration becomes the single compiler seam between linking and LoisVM lowering.
- Executable Program replaces the shallow parallel-parameter lowering boundary.
- The independent `lanec/executable` package owns this seam and remains target-independent.
- The independent `lanec/module/link` package owns Linked Program construction and the link model.
- Compilation orchestration, executable elaboration, and LoisVM lowering follow a one-way dependency graph.
- Whole-Program Elaboration retains only selected-entry-reachable initializer dependencies.
- Execution Image Lowering owns transitive function, external, and runtime-import reachability collection.
- Retained top-level initializers preserve declaration-order execution.
- Instance Globals are immutable after one consuming initialization.
- Global reads borrow; ARC insertion owns any required retained copies.
- Initialized globals are roots outside ordinary call frames and are released in reverse initialization order.
- Initialization failure prevents selected-entry execution.
- Interpreter and Wasm execution share one initializer-entry-cleanup lifecycle.
- Wasm output keeps declarative instantiation and has no start function.
- LoisVM bytecode carries globals and the optional initializer in every current-format image.
