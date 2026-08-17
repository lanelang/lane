# Lane Artifact Boundary

`Milky2018/lanec/artifact` is the sole public owner of persisted Lane artifact schemas, fingerprints, semantic validation, inspection, binary encoding and decoding, and adapters from validated artifacts to the module linker.

Compiler and CLI callers import this package instead of compiler orchestration packages or codec implementation paths. `lanec/module/compile` produces complete in-memory modules and converts them into the artifact types owned here; `lanec/module/link` consumes link objects and remains independent of persisted encoding and execution targets.

The subordinate `Milky2018/lanec/artifact/model` package contains only the three immutable value types shared with the linker: `CompilationFingerprint`, `ImportedInterfaceFingerprint`, and `ModuleImportedReference`. It exists to keep the dependency graph acyclic and is not a separate artifact API for compiler or CLI callers.

Schema versions change only when their corresponding persisted representation changes. Interface and module-object decoders validate container framing and payload syntax, but their compiler metadata remains untrusted until the compilation or linking validation boundary consumes it. Linked-program encoding and decoding are different: both pass the complete LoisVM bytecode image through the LoisVM-owned verifier, so a successful linked-program decode is already trusted for execution. Inspection follows the decoder for each artifact kind and never establishes an additional trust boundary.

Module-object entry and external descriptors persist identities and ABI facts,
not copied Buslane source types. Inspection and link certification resolve each
descriptor through the object Metadata Registry; runtime-import host signatures
are then checked against that one source type before remapping.
