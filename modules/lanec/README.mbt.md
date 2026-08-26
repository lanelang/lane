# Lane Compiler

`Milky2018/lanec` is the compiler library for Lane. It accepts identified
source inputs and returns structured diagnostics, module artifacts, linked
artifacts, and compiler observations. File discovery, command-line policy,
terminal output, and program execution belong to `Milky2018/lane`.

## Pipeline

```text
Lane source
  -> syntax, resolution, and type checking
  -> checked source
  -> Buslane core
  -> module artifacts and linking
  -> effect specialization and lowering
  -> executable program
  -> Runtime ANF
  -> VM CFG
  -> ARC-final VM CFG
  -> Physical Slot Plan
  -> verified Physical Program
  -> WebAssembly
```

The Physical Program is a compiler-private, non-persisted contract between
physical lowering and the WebAssembly target. It has no public codec or
independent execution engine. A linked program artifact persists exactly one
WebAssembly module plus its semantic runtime-import manifest.

WebAssembly is Lane's sole execution target. `lane run` and `lane exec` load
the same artifact and select either Wasmoon's JIT or, with `--no-jit`,
Wasmoon's WebAssembly interpreter.

## Packages

| Package | Responsibility |
| --- | --- |
| `Milky2018/lanec/compile` | High-level source checking, compilation, and linking |
| `Milky2018/lanec/module/frontend` | Explicit source inputs, imports, and module graph construction |
| `Milky2018/lanec/module/compile` | Module interfaces, objects, and fingerprints |
| `Milky2018/lanec/module/link` | Target-independent linking and linked core |
| `Milky2018/lanec/executable` | Whole-program elaboration and entry admission |
| `Milky2018/lanec/physical_lowering` | Runtime ANF and projection into VM CFG |
| `Milky2018/lanec/vmcfg` | Control flow, ARC, use-definition facts, and slot planning |
| `Milky2018/lanec/physical` | Verified physical operations, layouts, and callable ABI |
| `Milky2018/lanec/wasm_target` | Single-pass emission from a verified Physical Program to WebAssembly |
| `Milky2018/lanec/artifact` | Persisted interface, object, and linked-program schemas |
| `Milky2018/lanec/driver` | Platform-neutral entry enumeration and IR exploration |
| `Milky2018/lanec/analysis` | Semantic analysis for tools and language servers |

The root package intentionally exports no API. Import the focused package that
owns the operation you need.

## Source API

Compiler APIs never discover files implicitly. A host supplies one root
`SourceInput` and all available library inputs; module declarations and imports
determine the reachable source closure.

```mbt check
///|
test "check a Lane source file" {
  let result = @compile.check_source(
    (
      #|module Example
      #|
      #|pub fn answer() -> I64 {
      #|  42
      #|}
    ),
  )

  assert_true(result is Succeeded(_, _))
  assert_eq(result.diagnostics(), [])
}
```

`CompilationOutcome` distinguishes a successful value plus warnings from a
failed compilation plus errors. Use the module-oriented APIs when reusable
interface or object artifacts are required.

`lanec/driver` provides the shared observation boundary for native
`lane explore` and browser-facing `lane_wasm`. Its curated stages end with the
verified Physical Program and emitted WebAssembly; exploration never executes
the selected entry.

## Artifacts and trust

- Module interfaces persist imported and exported semantic contracts.
- Module objects persist checked, linkable implementation data.
- Linked-program artifacts persist WebAssembly plus a runtime-import manifest.
- Compilation fingerprints reject stale or mismatched inputs.

Artifact schemas are current-only compiler contracts, not archival formats.
Incompatible schemas are rejected and regenerated. Linked artifact loading
validates the WebAssembly module and proves that each semantic runtime import
matches the module's physical import contract before execution.

## Development

From the repository root:

```bash
moon check --target native
moon test --target native
moon info
moon fmt
```

Architecture vocabulary is owned by `CONTEXT.md` and the focused context files
under `docs/contexts/`. The WebAssembly-only target decision is recorded in
`docs/adr/0139-webassembly-only-execution-target.md`.
