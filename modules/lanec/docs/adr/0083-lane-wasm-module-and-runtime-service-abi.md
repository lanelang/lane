# Lane Wasm module and runtime-service ABI

> **Superseded.** The WASI Preview 1 WebAssembly Target RFC replaces this
> public ABI with `_start`, `memory`, WASI Preview 1, and direct core Wasm
> imports. No runtime-service capability export remains.

A generated Lane Wasm module exposes one stable program entry, `"lane.entry":() -> ()`. The wrapper invokes the executable entry selected by `lane link`, whose Lane type is exactly a zero-argument function returning `Unit`. No other Lane function is exported. The module also exports canonical memory as `"lane.memory"` and may export explicitly designated non-Lane runtime services. Entry and service wrappers are direct Wasm exports outside the canonical function table and Lane callable namespace.

Runtime imports use WebAssembly module namespace `"lane.runtime.v1"`. Each import field name is the stable versioned registry symbol. Portable bytecode stores the symbol, ABI major, and complete direct-value parameter and result kinds; runtime loading validates that signature against the registry before Wasm compilation or execution.

Physical host imports use natural Wasm value shapes. `Int` uses `i64`, `Double` uses `f64`, `Bool` uses `i32`, and `Unit` has no value. A String input expands to `(bytes_ptr:i32, byte_length:i32)` and is borrowed only for the synchronous import. A String result is one owned `string_ref:i32` already referring to a newly created Lane String in `"lane.memory"`. `Opaque` uses a backend-private generational handle shape resolved through the execution instance's Host Object Table; the source language and portable descriptor do not fix that physical shape.

Runtime services are artifact capabilities, not unconditional exports. The shared Lane Wasm ABI catalog maps each service to its name, physical function type, and the retained user or internal Runtime Import results that require it. Wasm emission derives the capability set from retained imports, proves that each service has its required nonzero static layout, and exports only that set. Wasmoon derives the same set from the validated import contracts, rejects missing, extra, or mistyped service exports, and resolves their function indices once while loading.

`"lane.runtime.string.new":(byte_length:i32) -> string_ref:i32` is present when a retained user Runtime Import returns String or a retained internal import produces a String, such as deterministic F32/F64 formatting. When a host import returns String, Wasmoon RuntimeContext validates the host bytes, invokes this service, writes the bytes through `"lane.memory"`, and returns the resulting owned reference to the generated import adapter. String parameters and ordinary in-module String operations do not by themselves export the service.

`"lane.runtime.host_object.new":(token:i64) -> opaque_ref:i32` is present when a retained Runtime Import returns Opaque. Opaque parameters do not by themselves export the construction service. Both services are omitted from scalar-only modules.

Calling a runtime service while a host import is active is not Lane program reentry. A runtime service cannot invoke `"lane.entry"`, call a Lane closure, dispatch an ordinary `FunctionId`, or suspend execution. Runtime-service helpers are outside the Lane callable namespace and cannot be packed into first-class callable values. The allocator remains non-reentrant because the service enters it only once while ordinary Lane execution is paused.

Runtime-import failure, validation failure, or runtime-service failure throws the private fatal Wasm exception. The exception may escape `"lane.entry"`; Wasmoon catches it at the execution boundary and converts it into fatal execution failure. The module does not expose this exception as Lane control flow.

Consequences:

- `"lane.entry":() -> ()` is the only exported Lane program entry.
- No ordinary Lane function is exported.
- Entry and runtime-service wrappers are not table entries or callable values.
- Runtime imports reside under `"lane.runtime.v1"` with stable registry fields.
- Primitive host values use natural Wasm scalar shapes, while `Opaque` uses a backend-private handle shape.
- String input is pointer-length and String output is an owned `i32` reference.
- Runtime-service capability is derived canonically from retained host-import result contracts rather than persisted as duplicate artifact metadata.
- `"lane.runtime.string.new"` and `"lane.runtime.host_object.new"` are restricted non-Lane service exports only when their capabilities are present.
- Every exported service has the physical type declared by the shared ABI catalog and a certified nonzero static layout.
- Runtime-service nested calls cannot dispatch Lane code.
- Runtime-service helpers are outside the Lane `FunctionId` range.
- Fatal exceptions may escape the entry export for Wasmoon to convert.
