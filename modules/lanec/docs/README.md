# Compiler Documentation

This directory contains compiler-owned design and planning material.

- `roadmap-checklist.md`: compiler pipeline checklist.
- `pre-buslane-contract.md`: checked-source invariants and Buslane lowering boundary contract.
- `existential-types.md`: source feature design kept here because the compiler still tracks implementation tasks for it.
- `fatal-control-rfc.md`: implemented canonical Void-result, compiler-owned fatal-control design.
- `effect-directed-inlining-rfc.md`: implemented effect-directed application-reduction and inlining design.
- `runtime-representation-elaboration-rfc.md`: canonical generic ABI,
  higher-kinded layout evidence, and the representation-elaboration seam.
- `wasip1-webassembly-target-rfc.md`: accepted, not-yet-implemented migration
  from the semantic Lane host runtime to raw WASI Preview 1 WebAssembly modules
  executed by Wasmoon.
- `adr/0138-uniform-generic-abi-and-optional-representation-specialization.md`:
  accepted ownership and optimization layering for runtime representation.
- `adr/`: decisions that affect compiler representation, resolution, typechecking, source elaboration, Buslane lowering, ANF, and diagnostics.
- `contexts/`: glossary slices used by compiler work.

Normative language rules belong in the `spec` repository.
