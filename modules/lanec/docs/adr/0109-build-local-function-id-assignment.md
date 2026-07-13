# Build-local FunctionId assignment

LoisVM FunctionId values are dense execution-image identifiers, not stable module identities or persistent ABI symbols. The linker assigns them only after whole-program reachability, optimization, closure lifting, and final bytecode-body formation have completed.

Bytecode bodies receive FunctionIds from their order in the final deterministic body list. Runtime imports remain deduplicated, sorted by their established canonical tuple, and appended after every body. The complete table therefore occupies the contiguous range `1..function_count`.

Determinism is build-local: the same compiler version, exact linked inputs, compilation options, and selected entry must produce the same final body list and FunctionId assignment. Function insertion or removal, optimization changes, compiler upgrades, and other changes to the final body list may renumber any FunctionId. Runtime-import IDs may also shift when the body count changes.

The selected executable entry remains an explicit `entry_function_id:u32le` and is not forced to FunctionId 1. FunctionId values are not observable in Lane, exported as stable symbols, stored in `.lmo` module ABI, or suitable for persistence across linked artifacts.

The linker performs no call-graph canonical labeling, graph-isomorphism normalization, body-hash ordering, stable anonymous-function naming contract, sparse identifier allocation, or hash-derived FunctionId assignment. Those mechanisms would constrain optimization and closure lifting while providing no Lane-semantic benefit.

Consequences:

- FunctionId remains a compact dense table index.
- Identical builds remain byte-for-byte reproducible.
- Compiler or optimization changes may renumber functions freely.
- The selected entry is explicit and may have any valid FunctionId.
- Runtime imports remain sorted after all bytecode bodies.
- FunctionId is not a cross-build or module ABI identity.
- Linkers need no canonical call-graph labeling or stable anonymous naming scheme.
