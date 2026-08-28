# Lane Artifact Boundary

`Milky2018/lanec/artifact` owns Lane's persisted interface and module-object
schemas, including fingerprints, inspection, and binary codecs.
Compiler and command callers consume this package rather than private codec or
orchestration packages.

Interface and module-object decoding proves container framing and payload
syntax. Their semantic metadata remains untrusted until the compilation or
linking validation boundary certifies it.

Executable output is a standards-valid raw WebAssembly module, not a Lane
artifact. Before execution, `lane_runtime/wasm` parses and validates that
module, authenticates host bindings against its actual import section, resolves
named control globals, and constructs the executable instance atomically.
Failure returns no partially trusted program.

The compiler's Physical Program is not persisted and has no artifact codec.
Artifact inspection covers only Lane interface and module-object artifacts;
standard WebAssembly tooling owns executable inspection.
