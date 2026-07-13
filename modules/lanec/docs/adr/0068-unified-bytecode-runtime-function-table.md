# Unified bytecode and runtime function table

LoisVM uses one image-global `FunctionId` namespace for bytecode-defined functions and runtime imports. Each function-table entry is tagged as either a bytecode function body or a runtime import containing a stable runtime symbol and erased ABI descriptor, including the arity required for calls. A `FunctionId` identifies a callable target and does not imply that the target has bytecode instructions.

The bytecode section stores one nonzero selected `entry_function_id` before the function table. It must identify a no-context bytecode body with zero witness parameters, zero user parameters, and Unit result. Original export symbol and source type are omitted because link has already validated them. A runtime import cannot be the selected executable entry.

Runtime Import ABI v1 is fixed-arity and uniform-value. Its logical signature is `(RuntimeContext, VMValue...) -> VMValue`. `RuntimeContext` is an implicit borrowed host parameter providing services such as allocation and I/O; it is not a Lane argument, local-slot value, or reference-counted object. Every explicit argument uses the ordinary uniform VM representation, and every import returns exactly one owned VM value, including `Unit` for procedures.

That logical `Unit` result does not allocate a bytecode slot. A call instruction uses `None` for its optional destination when the selected target returns `Unit`; interpreter bindings may still return an internal Unit marker to their adapter, which discards it before bytecode execution continues.

V1 descriptors contain no source type, varargs marker, multiple-result shape, or per-parameter unboxed representation kind. Runtime symbols carry an ABI major version, and the loader checks symbol, version, and fixed arity before accepting a binding. Reference-bearing explicit arguments follow the callee-owned call convention; the runtime context itself does not participate in ARC.

The runtime symbol registry is the single authority for primitive argument and result kinds. `lanec` checks that registry-defined signature before type erasure, while the serialized runtime-import descriptor stores only the versioned symbol and arity. Loading checks those fields and then permits the binding to assume the trusted uniform VM operands carry the expected primitive tags. Bytecode does not duplicate the signature as a parameter-kind list.

Runtime import entries are always no-context and have no representation-witness parameters. Their serialized payload is ABI major version, user arity, and one nonempty case-sensitive ASCII symbol without NUL. The linker deduplicates entries by `(symbol, abi_major, user_arity)`. Bytecode bodies precede runtime imports in the function table; imports are sorted by symbol bytes, ABI major, then arity after deduplication.

Runtime imports are synchronous and cannot re-enter Lane program execution in v1. A binding must return before LoisVM execution continues, cannot invoke Lane callbacks, and cannot retain argument values or other VM values after returning. It owns transferred arguments and must consume or release them on both successful return and execution failure. A Wasm RuntimeContext may make a restricted nested call to a designated non-Lane runtime-service export; that service cannot invoke the selected entry, a Lane closure, or an ordinary `FunctionId` target.

The v1 host boundary accepts and returns only `Int`, `Double`, `Bool`, `String`, and `Unit`. Closures, nominal data, closure environments, function identifiers, and opaque host handles cannot cross it. `String` follows the ordinary reference-count ownership contract; the other allowed kinds are immediate values.

Dynamic String values are immutable ARC objects with `byte_length:u32` at object offset eight and ASCII bytes at offset twelve. Their total allocation size is rounded up to eight-byte alignment. Constant-pool and empty Strings use the same layout with the immortal count. Strings store no capacity, cached hash, trailing NUL, or parent-view state.

A runtime import receives an owned String VM value but reads it through the temporary borrowed pair `(string_ref + 12, byte_length)`, avoiding an input copy. The binding cannot retain that view after the synchronous call.

The generated module defines and exports its canonical memory as `"lane.memory"`. Wasmoon runtime imports access String bytes and other approved buffers through that export and the current RuntimeContext; Lane does not import a host-owned memory.

A runtime import returns String logically by asking the runtime context to create a new owned VM String from host-provided bytes. In the Wasm tier, the host import physically returns one owned `string_ref:i32`. RuntimeContext obtains that reference through the restricted `"lane.runtime.string.new":(byte_length:i32) -> string_ref:i32` service, writes the bytes through `"lane.memory"`, and validates Lane v1's ASCII invariant before returning from the import. Non-ASCII bytes or service failure report fatal runtime-import failure. Portable bytecode continues to pass one uniform String VM value.

A successful runtime import returns one owned primitive VM value. Failure is an out-of-band fatal execution error: it produces no Lane value, has no bytecode exceptional successor, and terminates the current LoisVM execution. The binding must consume or release all transferred arguments before reporting failure, after which the VM releases remaining owned frame and slot values while unwinding the aborted execution. Recoverable host outcomes must be represented through the normal primitive result, such as an `Int` or `Bool` status.

The Wasm compiled tier implements that fatal unwind with Exception Handling using `exnref`. A failing runtime-import adapter first consumes or releases all transferred arguments, then throws a private Wasm exception. Every generated frame that can hold owned values across a potentially failing call has an internal cleanup handler that releases the owners still held by that frame and rethrows. The outer execution boundary catches the private exception and reports runtime-import failure out of band. The private exception is not a Lane value, effect, exception, or bytecode exceptional edge.

The physical failure mechanism is an execution-tier detail. The interpreter may use a runtime-error result, while a native binding may use a status plus out parameter or a failure callback. The runtime symbol registry defines that host binding contract; bytecode runtime-import descriptors do not encode a failure-channel shape.

Direct calls, callable-value calls, and tail calls use the same bytecode instructions and callee-owned ownership convention for both entry kinds. A first-class callable value is either an immediate capture-free `FunctionId` or a reference-counted closure containing a function identifier and environment. Runtime imports and other capture-free functions therefore become first-class immediate values without eta wrappers or empty closure allocation. LoisVM does not define a separate `call_runtime` instruction, `RuntimeFunctionId` namespace, or runtime-function VM value category.

`call_value` and `tail_call_value` accept either callable representation. An immediate identifier must target a function-table entry with no closure context. A capturing callable supplies the required environment for a context-requiring entry. The trusted bytecode contract establishes this relationship; the VM does not dynamically adapt a mismatched callable. Consuming an immediate identifier has no ARC effect. Consuming a capturing callable transfers its directly owned environment reference into the callee.

The loader resolves every runtime import before execution and stores the resulting callable in loaded-image state. Stable symbols and ABI descriptors are serialized; host pointers and callable objects are not. A missing or ABI-incompatible import is an image-load failure. Successful calls dispatch through the tagged entry and cached binding without per-call string or plugin lookup.

The interpreter invokes the resolved binding when a call targets a runtime import. The Wasm compiled tier emits a WebAssembly import or an adapter to one and lowers the same ordinary call through that boundary. Generated host imports use module namespace `"lane.runtime.v1"` and stable registry symbols as field names. Runtime imports therefore remain explicit host dependencies without creating a second bytecode call path.

Each Wasm runtime-import adapter exposes the same canonical Lane entry ABI as a bytecode-defined target: hidden environment first, then representation witnesses, then typed or erased user arguments. Runtime imports do not use closure environments, so the adapter expects zero. It converts that Lane entry shape to the physical host import signature obtained from the runtime symbol registry.

The Wasm backend obtains a stable runtime symbol's primitive signature from the same runtime symbol registry when constructing imports or adapters. Physical imports use natural Wasm scalar types for `Int`, `Double`, `Bool`, and `Unit`; a String argument expands to `(bytes_ptr:i32, byte_length:i32)`, and a String result is one owned `string_ref:i32`. This physical signature is not required for bytecode correctness and does not add source types or Wasm representation descriptors to portable bytecode.

Dedicated LoisVM primitives remain bytecode instructions. Arithmetic, comparison, data, closure, control-flow, and reference-count semantics do not become runtime imports merely because the current Buslane reference interpreter implements some of them through builtin plugins. Runtime imports are reserved for host/runtime capabilities that cannot be implemented as portable bytecode operations.

WASI Preview 1, the Component Model with WASI Preview 2, and JavaScript embedding integrations may be supported by Wasmoon or a deployment adapter, but they do not replace the canonical Runtime Import ABI. Lane v1 imports remain synchronous and cannot re-enter Lane program execution, Strings remain ASCII ARC objects in canonical linear memory, and JS Promise, JS String, and custom JS descriptor values do not cross the Lane boundary.

This table is unrelated to effect operation dispatch. Effects have already been lowered before bytecode, and a runtime import is an ordinary external function target rather than a handler or operation-table entry.

Consequences:

- `FunctionId` indexes tagged bytecode-body and runtime-import entries.
- The bytecode section stores one selected executable FunctionId.
- The selected entry is a zero-argument Unit bytecode body with no context or witnesses.
- All callable targets share direct, callable-value, tail-call, and ownership semantics.
- First-class runtime functions do not require eta wrappers or a second VM value kind.
- Capture-free first-class functions use immediate `FunctionId` values rather than empty closures.
- Callable-value calls move unique closure environments and retain shared ones.
- Runtime symbols resolve once at image load and are not looked up on every call.
- Runtime Import ABI v1 stores fixed arity and uses uniform VM values with one result.
- Runtime symbols carry an ABI major version checked during loading.
- The runtime symbol registry is the sole primitive-signature authority.
- Bytecode stores no per-parameter or result kind list for imports.
- Runtime imports serialize major version, user arity, and nonempty ASCII symbol.
- Runtime imports are no-context, witness-free, deduplicated, and deterministically sorted.
- Runtime context is implicit borrowed host state and is outside Lane ownership.
- Runtime imports are synchronous, cannot re-enter Lane program execution, and cannot retain VM values.
- Restricted runtime-service nested calls cannot dispatch Lane callables.
- Host-call arguments and results are restricted to Lane primitive value kinds.
- String arguments expose a zero-copy borrowed ASCII byte view for the call only.
- String results copy validated ASCII bytes into an owned VM object.
- Wasm imports use `"lane.runtime.v1"` and natural primitive signatures.
- Wasm String results use the restricted String-allocation service.
- Runtime import failure fatally aborts execution and is not catchable Lane control flow.
- Failure cleanup releases transferred arguments and remaining owned VM frames.
- Recoverable host outcomes use normal primitive return values.
- Missing or incompatible runtime imports fail before execution starts.
- Wasm lowering maps runtime-import entries to WebAssembly imports or adapters.
- VM primitives remain opcodes; host capabilities use runtime imports.
- The runtime import portion of the function table is not an effect operation table.
