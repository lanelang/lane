# GHC-like artifact and execution layering

Lane chooses an explicit compile-link-execute artifact model closer to GHC than
to the JVM. Interfaces, module objects, linked programs, optimization metadata,
and execution images have different responsibilities and should not collapse
into one bytecode-shaped artifact boundary.

The compiler-readable interface remains the downstream compilation contract. It
records exported declarations, visible types and effects, fingerprints, and
optimization hints. Those hints may help later compilation or optimization, but
they do not change source-language meaning.

The module object remains the link-time contract. Its authoritative semantic
payload is canonical Buslane/core plus imports, exports, external origins,
fingerprints, and metadata needed for linking, verification, inspection, and
later lowering. ANF is not the artifact source of truth: it is a derived
normalization layer below Buslane that can be regenerated from core.

Whole-program optimization should run after linking imported references and
before lowering to an execution image. The optimizer should see the linked
semantic core, not only per-module bytecode. Bytecode-level optimization is
still useful, but it should be late and local: instruction selection,
peepholes, slot allocation, jump cleanup, constant-pool layout, and similar
execution-layout work.

The linked program artifact may eventually store an optimized bytecode image as
its primary execution payload. It should also keep enough semantic metadata for
entry validation, runtime effect validation, inspection, debugging, and stable
diagnostics. Embedding a Buslane/core snapshot is acceptable when it keeps
`lane inspect` and future debugging tools useful.

Module objects may store per-module bytecode only as an optional cache. Such a
cache must be invalidated by the compiler version, target, lowering options,
and core fingerprint. It must not become the cross-module semantic record, the
source of interface fingerprints, or the only representation available to the
linker.

This follows the useful part of GHC's split: interface files carry compiler
knowledge for separate compilation and cross-module optimization, while code
artifacts are execution products. Lane should not adopt the JVM class-file model
as its primary design, because JVM bytecode is the canonical distribution unit
with symbolic references resolved and optimized mostly by the runtime. Lane's
explicit fingerprints, link step, `exec`, and inspectable core artifacts fit a
static compiler pipeline better.

Consequences:

- `.lmi` is the interface and optimization-summary artifact.
- `.lmo` is the relocatable module object whose authoritative payload is
  linkable Buslane/core.
- `.lbp` is the linked program artifact; it may store final optimized bytecode
  plus entry tables, runtime effect tables, constant pools, and debug metadata.
- ANF and bytecode are lowerings from Buslane/core, not replacements for the
  canonical semantic artifact.
- The bytecode VM must be tested against the Buslane reference interpreter
  rather than defining Lane semantics first.
- `lane inspect` should primarily display semantic artifact structure and
  Buslane/core code; execution-image dumps should be clearly labeled as lowered
  code.
