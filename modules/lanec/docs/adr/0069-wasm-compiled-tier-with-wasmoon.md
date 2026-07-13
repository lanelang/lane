# Wasm compiled tier with Wasmoon

Lane uses WebAssembly, rather than MilkIR, as the compiled representation below LoisVM bytecode. The compiled pipeline is `linked Buslane/core -> LoisVM bytecode -> WebAssembly module -> WebAssembly engine`. LoisVM bytecode remains the common executable input: `loisvm/interp` executes it directly, while the Wasm backend decodes the same trusted image and lowers it to WebAssembly. The backend does not bypass bytecode by consuming compiler-private Buslane, ANF, or VM CFG representations.

Milky2018/wasmoon is Lane's default WebAssembly execution engine. Wasmoon is project-controlled and may be extended alongside Lane, including its interpreter, JIT, runtime integration, and supported WebAssembly capabilities. Lane's Wasm design therefore need not be limited by the current feature floor or rollout schedule of unrelated WebAssembly engines.

Both `lane run` and `lane exec` use the same LoisVM-bytecode-to-Wasm path by default. `lane run` performs in-memory linking and bytecode lowering before loading the generated image; `lane exec` decodes the linked `.lbp` bytecode image. Neither command uses the Buslane reference interpreter as its normal execution backend.

This decision intentionally delegates Wasm heap representation, garbage collection profile, function-reference strategy, control-flow structuring, runtime-import adapter ABI, String representation, and fatal-failure cleanup to follow-up ADRs. Previous bytecode semantics remain in force unless one of those Wasm mapping decisions requires an explicit revision. In particular, effect erasure, callable-value semantics, compiler-directed ownership, and the common-bytecode boundary are not discarded merely because the lower compiled representation changes.

LoisVM bytecode remains trusted compiler output and does not gain an independent verifier. Generated WebAssembly modules must nevertheless satisfy the validation contract of the selected WebAssembly profile before Wasmoon executes or JIT-compiles them.

Lane v1 uses an explicit WebAssembly feature profile rather than claiming plain WebAssembly 1.0 compatibility. The profile uses one canonical non-shared wasm32 linear memory. The emitter may use Multi-value, Reference Types, Typed Function References, Tail Call, Bulk Memory, Exception Handling with `exnref`, Sign-extension Operators, and Extended Constant Expressions. It excludes Stack Switching, Relaxed SIMD, Threads, Atomics, Multiple Memories, Memory64, Wasm GC, and Wasmoon-specific instructions, types, or non-standard module semantics. Wasmoon may recognize Lane code patterns, optimize runtime integration, and add JIT fast paths without changing the language accepted as Lane compiled output.

The backend remains aware of Non-trapping Float-to-int, Fixed-width SIMD, Branch Hinting, Wide Arithmetic, Custom Page Sizes, and Memory Control, but Lane v1 does not emit those features or require them for execution. Saturating conversion must wait for explicit Lane conversion semantics; SIMD and hints wait for optimization work; the remaining memory and arithmetic features are future implementation options.

Import/Export Mutable Globals, Compilation Hints, WASI Preview 1, the Component Model with WASI Preview 2, and JS BigInt-to-`i64` integration are also aware-only host or deployment options. They do not change the core module ABI. Multiple Tables and Relaxed Dead-code Validation are excluded: one `FunctionId` namespace addresses one canonical function table, and generated functions must satisfy normal strict Wasm validation.

JS Promise Integration, JS String Builtins or String References, and Custom Descriptors or JS Interop are excluded from Lane v1. They conflict respectively with synchronous runtime imports, linear-memory ASCII ARC Strings, and the absence of JS objects from the Lane value ABI.

Extended Name Sections, Custom Annotations, Rounding Variants, Half Precision, Flexible Vectors, Type Imports, and the JIT Interface are aware-only capabilities. They may inform future debugging, numeric, vector, linking, or execution work but are neither emitted nor required by Lane v1. Shared-Everything Threads, JS Primitive Builtins, and Frozen Values are excluded because they conflict with the thread-confined ARC heap, the Wasmoon-centered host boundary, or the absence of GC-managed Lane objects.

Bulk Memory operations may initialize passive data or element segments, fill allocator storage, and copy raw bytes such as String contents. They do not provide ARC semantics: reference-bearing data construction or duplication must still establish field ownership through compiler-emitted retain or transfer operations rather than raw `memory.copy`.

Consequences:

- MilkIR is not part of the Lane compiled execution pipeline.
- `.lbp` remains sufficient input for both LoisVM interpretation and Wasm compilation.
- Wasm lowering begins from decoded LoisVM bytecode, not from compiler-private IR.
- Milky2018/wasmoon is the default compiled execution engine and may evolve with Lane.
- Current third-party engine feature support does not constrain the initial Lane backend design.
- Lane v1 output uses wasm32 linear memory plus Multi-value, Reference Types, Typed Function References, Tail Call, and Bulk Memory.
- Lane v1 uses Exception Handling only for private fatal-failure cleanup and unwinding.
- Lane v1 may emit Sign-extension Operators and Extended Constant Expressions.
- Non-trapping Float-to-int, Fixed-width SIMD, Branch Hinting, Wide Arithmetic, Custom Page Sizes, and Memory Control are aware-only features in v1.
- Stack Switching and Relaxed SIMD are excluded from Lane v1 output.
- Mutable Global integration, Compilation Hints, WASI, Component Model, and JS BigInt integration are aware-only.
- Multiple Tables and Relaxed Dead-code Validation are excluded.
- JS Promise, JS String, and Custom Descriptor interop are excluded.
- Extended names, annotations, rounding, half precision, flexible vectors, type imports, and JIT interface are aware-only.
- Shared-Everything Threads, JS Primitive Builtins, and Frozen Values are excluded.
- Lane v1 excludes Memory64; heap references and packed-callable components remain 32-bit.
- Lane v1 excludes Multiple Memories; all Lane pointers address canonical memory zero.
- Lane v1 excludes Threads and Atomics; canonical memory zero is non-shared and ARC is non-atomic.
- Lane v1 output does not require Wasm GC or Wasmoon-specific opcodes or types.
- `lane run` and `lane exec` share the default Wasmoon execution path.
- WebAssembly validation remains required even though LoisVM bytecode verification is not.
- Wasm object representation, ARC versus GC, control-flow structuring, calls,
  imports, Strings, and failure cleanup are governed by the subsequent focused
  ADRs rather than this backend-selection decision.
- A future non-standard Lane-Wasmoon profile would require a separate explicit and versioned decision.
