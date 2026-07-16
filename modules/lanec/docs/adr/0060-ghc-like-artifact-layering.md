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

The linked program artifact stores the final optimized bytecode image. The
selected entry and runtime-import descriptors are stored only inside the
image's unified `FunctionId` table rather than duplicated by the outer artifact
payload. They are not effect-operation dispatch data. Ordinary linked artifacts do not embed
linked Buslane/core or source debug metadata; semantic inspection remains
available through module objects, while future debug support must use an
explicit separate artifact section or mode.

The same LoisVM bytecode image is also the compiled execution backend input.
That backend decodes bytecode, lowers it into a WebAssembly module, and executes
the module with a WebAssembly engine. Milky2018/wasmoon is Lane's default engine
and may be extended alongside Lane. The backend does not bypass bytecode by
consuming a `lanec`-internal Buslane or ANF representation. This keeps `.lbp`
sufficient for either interpreted or compiled execution without embedding
compiler core IR.

Lane v1 module objects do not store per-module bytecode. If link performance
later justifies a bytecode cache, that cache must remain outside the
authoritative `.lmo` and `.lbp` contracts and be invalidated by the compiler
version, target, lowering options, and core fingerprint. It must not become the
cross-module semantic record or the source of interface fingerprints.

This follows the useful part of GHC's split: interface files carry compiler
knowledge for separate compilation and cross-module optimization, while code
artifacts are execution products. Lane should not adopt the JVM class-file model
as its primary design, because JVM bytecode is the canonical distribution unit
with symbolic references resolved and optimized mostly by the runtime. Lane's
explicit fingerprints, link step, `runobj`, and inspectable core artifacts fit a
static compiler pipeline better.

Consequences:

- `.lmi` is the interface and optimization-summary artifact.
- `.lmo` is the relocatable module object whose authoritative payload is
  linkable Buslane/core.
- `.lbp` is the executable-only linked program artifact containing final
  optimized bytecode, which itself contains the selected entry and
  execution-required runtime tables.
- All LoisVM bytecode lowering happens after `.lmo` linking and whole-program
  core optimization.
- Compiled execution lowers the `.lbp` LoisVM bytecode image into WebAssembly
  rather than introducing a parallel executable lowering from Buslane or ANF.
- Milky2018/wasmoon is the default WebAssembly engine. Lane may extend its
  interpreter, JIT, runtime integration, and supported WebAssembly capabilities
  instead of limiting the backend to the current feature floor of unrelated
  engines.
- ANF and bytecode are lowerings from Buslane/core, not replacements for the
  canonical semantic artifact.
- The bytecode VM must be tested against the Buslane reference interpreter
  rather than defining Lane semantics first.
- `lane inspect` displays semantic structure and Buslane/core for module objects;
  linked `.lbp` artifacts instead display clearly labeled canonical LoisVM
  disassembly because they contain no semantic core.
