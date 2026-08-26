# Lane Artifact Boundary

`Milky2018/lanec/artifact` owns Lane's persisted interface, module-object, and
linked-program schemas, including fingerprints, inspection, and binary codecs.
Compiler and command callers consume this package rather than private codec or
orchestration packages.

Interface and module-object decoding proves container framing and payload
syntax. Their semantic metadata remains untrusted until the compilation or
linking validation boundary certifies it.

A linked-program artifact contains:

- one current-schema WebAssembly module; and
- the semantic runtime-import manifest required to bind host values.

Linked artifact decoding proves framing and schema only. Before execution,
`lane_runtime/wasm` parses and validates the WebAssembly, validates its closed
Lane import surface, checks every semantic manifest entry against the exact
physical WebAssembly import type, resolves named control globals, and then
constructs the executable instance. Failure returns no partially trusted
program.

The compiler's Physical Program is not persisted and has no artifact codec.
Inspection follows the owning decoder and never creates an additional trust
boundary.
