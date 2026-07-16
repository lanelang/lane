# Atomic bytecode loading and resource limits

The LoisVM bytecode format uses its existing `u32le` fields as the only normative representational limits. It defines no smaller fixed maximum for function count, body length, slot count, block count, instruction count, String length, or other counted tables. The compiler must reject any artifact component, count, length, offset, or identifier that cannot be represented by its format field.

Decoding performs checked arithmetic for every length addition, offset update, count multiplication, and slice calculation. Before allocating storage from a declared count, the decoder proves that the remaining enclosing slice can contain at least the minimum encoded size of those records. These requirements enforce safe framing and do not constitute CFG, type, data-flow, call-shape, or ownership verification.

An implementation may impose lower memory, item-count, body-size, compilation-time, or other resource limits. Such limits are implementation policy: they are not serialized in `.lbp`, negotiated by the bytecode, or required to match across hosts. Exceeding one is a ResourceLimit load failure rather than malformed encoding.

Loading proceeds in this order:

1. completely decode the bytecode section and consume all framing;
2. perform the established local metadata checks;
3. resolve every runtime import through the runtime symbol registry;
4. construct the interpreter execution image or compile the Wasm module;
5. publish the complete reusable loaded executable image.

Runtime import resolution begins only after the complete section has decoded successfully. Resolution may query and bind the runtime registry but may not execute Lane code, invoke Lane closures, re-enter Lane execution, or produce Lane-observable effects.

Runtime-import symbols and String-pool bytes are validated as ASCII during decoding. Invalid bytes, NUL in a runtime symbol, malformed framing, and illegal local encodings are MalformedEncoding failures before import resolution.

Loading is atomic. Any failure discards all partially decoded tables, resolved bindings, temporary compiler state, partial Wasm modules, and unpublished execution-image resources. A retry starts from the original artifact and registry state; it does not reuse partial bindings or compiled state left by the failed attempt. Successful loading publishes a reusable image or instance factory; each selected-entry invocation later creates its own single-shot execution instance.

The load API distinguishes at least MalformedEncoding, UnresolvedImport, AbiMismatch, ResourceLimit, and BackendCompileFailure. MalformedEncoding diagnostics carry a byte offset relative to the LoisVM bytecode section. Runtime-import failures carry the offending symbol. Source locations are not required because executable bytecode need not retain source metadata.

A structurally valid trusted image may still fail to load because of unavailable imports, implementation resource policy, or backend compilation failure. No entry function executes and no loaded executable image becomes visible until every loading phase succeeds.

Consequences:

- The portable schema avoids arbitrary resource ceilings below `u32` capacity.
- Checked framing arithmetic remains mandatory despite trusted semantic bytecode.
- Implementations may reject valid images that exceed local resources.
- Resource policy does not alter schema compatibility.
- Complete decoding precedes runtime import resolution.
- Import resolution cannot execute or re-enter Lane code.
- ASCII violations fail during decoding.
- Failed loads publish no partial image or instance.
- Retries do not inherit partial state from failed loads.
- Load failures have stable high-level categories and useful bytecode-relative diagnostics.
