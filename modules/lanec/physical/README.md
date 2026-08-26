# Physical Program

The Physical Program is the compiler-private, verifier-checked input to Lane's
WebAssembly emitter. It owns finalized slot identities, callable ABIs, runtime
value shapes, object layouts, ARC operations, globals, constants, and runtime
import declarations.

It is not a public VM, a persistence format, or an alternative execution
target. No decoder or interpreter exists for it. The linked artifact boundary
persists only standard WebAssembly bytes and the semantic runtime-import
manifest needed by an embedding host.
