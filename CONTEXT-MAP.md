# Context Map

Lane uses separate glossaries for source language, compiler, tooling, and
runtime concepts. Each term has one owning context.

## Contexts

- [Lane Workspace](CONTEXT.md) — source-language modules, compilation artifacts,
  and repository-wide workflow terms.
- [Buslane](modules/buslane/CONTEXT.md) — the typed semantic core and its type,
  effect, verification, and text model.
- [Bytecodec](modules/bytecodec/CONTEXT.md) — domain-neutral binary reading and
  writing primitives.
- [Lane Command](modules/lane/CONTEXT.md) — native CLI and stdio language-server
  behavior.
- [Lane Wasm](modules/lane_wasm/CONTEXT.md) — browser transport for compiler IR
  exploration.
- [Lane Compiler](modules/lanec/CONTEXT.md) — source elaboration, compiler
  analysis, effect lowering, VM CFG, and execution-image production.
- [Lane Module Subsystem](modules/lanec/module/CONTEXT.md) — module package
  boundaries inside `lanec`.
- [LoisVM](modules/loisvm/CONTEXT.md) — portable bytecode, verification, runtime
  representation, host calls, and bytecode-to-Wasm execution.

## Relationships

- The Lane Compiler elaborates Lane source into Buslane and lowers executable
  Buslane programs through VM CFG into verified LoisVM bytecode.
- The Lane Command and Lane Wasm are hosts of compiler APIs; neither owns
  compiler semantics.
- Lane artifacts and LoisVM codecs use Bytecodec primitives while retaining
  ownership of their domain schemas and validation.
- Source-language and artifact terms belong to Lane Workspace; compiler-only
  transformations belong to Lane Compiler; persisted execution and runtime
  terms belong to LoisVM.
- Use **MoonBit module** or **MoonBit package** for repository packaging and
  **Module** for a Lane source-language namespace.
