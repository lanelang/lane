# Lane Wasm module and runtime-service ABI

A generated Lane Wasm module exposes one stable program entry, `"lane.entry":() -> ()`. The wrapper invokes the executable entry selected by `lane link`, whose Lane type is exactly a zero-argument function returning `Unit`. No other Lane function is exported. The module also exports canonical memory as `"lane.memory"` and may export explicitly designated non-Lane runtime services. Entry and service wrappers are direct Wasm exports outside the canonical function table and Lane callable namespace.

Runtime imports use WebAssembly module namespace `"lane.runtime.v1"`. Each import field name is the stable versioned registry symbol. The runtime symbol registry remains the authority for the primitive signature; portable bytecode stores only symbol, ABI version, and arity.

Physical host imports use natural Wasm value shapes. `Int` uses `i64`, `Double` uses `f64`, `Bool` uses `i32`, and `Unit` has no value. A String input expands to `(bytes_ptr:i32, byte_length:i32)` and is borrowed only for the synchronous import. A String result is one owned `string_ref:i32` already referring to a newly created Lane String in `"lane.memory"`.

The module exports `"lane.runtime.string.new":(byte_length:i32) -> string_ref:i32` as a restricted runtime service. When a host import must return String, Wasmoon RuntimeContext validates the host bytes, invokes this service, writes the bytes through `"lane.memory"`, and returns the resulting owned reference to the generated import adapter.

Calling a runtime service while a host import is active is not Lane program reentry. A runtime service cannot invoke `"lane.entry"`, call a Lane closure, dispatch an ordinary `FunctionId`, or suspend execution. Runtime-service helpers are outside the Lane callable namespace and cannot be packed into first-class callable values. The allocator remains non-reentrant because the service enters it only once while ordinary Lane execution is paused.

Runtime-import failure, validation failure, or runtime-service failure throws the private fatal Wasm exception. The exception may escape `"lane.entry"`; Wasmoon catches it at the execution boundary and converts it into fatal execution failure. The module does not expose this exception as Lane control flow.

Consequences:

- `"lane.entry":() -> ()` is the only exported Lane program entry.
- No ordinary Lane function is exported.
- Entry and runtime-service wrappers are not table entries or callable values.
- Runtime imports reside under `"lane.runtime.v1"` with stable registry fields.
- Primitive host values use natural Wasm scalar shapes.
- String input is pointer-length and String output is an owned `i32` reference.
- `"lane.runtime.string.new"` is a restricted non-Lane service export.
- Runtime-service nested calls cannot dispatch Lane code.
- Runtime-service helpers are outside the Lane `FunctionId` range.
- Fatal exceptions may escape the entry export for Wasmoon to convert.
