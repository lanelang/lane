# WebAssembly ABI

This package owns target ABI contracts shared by Physical Lowering, Physical
Program verification, and WebAssembly emission.

## Language

**Core Wasm Import Contract**:
The module name, field name, exact core value types, and required boundary
adaptation for one imported function. The Physical Program stores this fact;
the emitter only materializes it.
_Avoid_: source extern type, semantic runtime-import descriptor

**WASI Preview 1 Catalog**:
The canonical identities and core function types of the Preview 1 operations
Lane currently emits. Adding a standardized operation extends this catalog
rather than restating its signature in a consumer.
_Avoid_: Wasmoon callback registration, Basic function type
