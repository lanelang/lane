# Lane Compiler

`Milky2018/lanec` is the compiler implementation for the Lane programming language. It provides parsing, name resolution, type checking, module compilation, linking, effect lowering, whole-program elaboration, and lowering to portable LoisVM bytecode.

The module is designed as a compiler library. It accepts source text and identified in-memory source inputs, returns structured diagnostics and compiler artifacts, and does not own command-line parsing, host file discovery, terminal output, or program execution. Those host responsibilities belong to the separate `Milky2018/lane` command module.

## Compiler pipeline

```text
Lane source
  -> Lexer and parser
  -> Name resolution
  -> Type checking and contextual resolution
  -> Buslane module lowering
  -> Module artifacts and linking
  -> Reachable effect specialization
  -> Handler elaboration
  -> Monadic transformation
  -> Selective CPS
  -> Open-context resolution
  -> Monadic lift
  -> Residual effect erasure
  -> Executable Program (whole-program elaboration)
  -> ANF
  -> Compiler-private VM CFG
  -> Ownership analysis, ARC insertion, and slot allocation
  -> LoisVM bytecode
```

LoisVM bytecode is the execution-image boundary. The bytecode package stores only the current canonical format and has no independent version discriminator or legacy decoder. Persisted linked-program compatibility is owned by the enclosing Lane artifact schema.

## Features

- Multi-module source compilation with explicit source identities
- Structured lexer, parser, resolver, and type-checker diagnostics
- Typed module interfaces, module objects, fingerprints, and linked artifacts
- Buslane lowering for source-independent semantic processing
- Built-in `Io` effect and user-defined algebraic effects
- Selective CPS and monadic effect lowering before bytecode generation
- Whole-program entry selection and ordered top-level initialization
- Closure conversion, representation erasure, ownership analysis, and ARC insertion
- Portable LoisVM bytecode generation
- Stable compiler observation stages for native and browser IR explorers
- Source formatting and a revisioned incremental semantic workspace for LSP-oriented APIs

## Installation

Add the module to a MoonBit project:

```bash
moon add Milky2018/lanec
```

The root `Milky2018/lanec` package intentionally exports no API. Import the focused package that owns the operation you need:

```moonbit nocheck
import {
  "Milky2018/lanec/compile",
  "Milky2018/lanec/driver",
  "Milky2018/lanec/module/frontend",
}
```

## Quick start

### Check one source file

`check_source` runs the front end and returns checked source plus structured diagnostics without lowering to Buslane.

```mbt check
///|
test "check a Lane source file" {
  let result = @compile.check_source(
    (
      #|module Example
      #|
      #|pub fn answer() -> Int {
      #|  42
      #|}
    ),
  )

  assert_true(result.source is Some(_))
  assert_true(result.diagnostics.is_empty())
}
```

### Compile an explicit source set

Compiler APIs never discover files implicitly. A host supplies one root `SourceInput` and every available library input. Module declarations and imports determine which inputs are reachable.

```mbt check
///|
test "compile a multi-module Lane source set" {
  let root : @frontend.SourceInput = {
    source_id: "main.lane",
    text: (
      #|module Main
      #|import Library.{
      #|  answer
      #|}
      #|
      #|pub fn main() -> Int {
      #|  answer
      #|}
    ),
  }
  let library : @frontend.SourceInput = {
    source_id: "library.lane",
    text: (
      #|module Library
      #|
      #|pub let answer : Int = 42
    ),
  }
  let result = @compile.compile_source_inputs(root, [library])

  assert_true(result.program is Some(_))
  assert_true(result.diagnostics.is_empty())
  assert_true(
    result.entries.any(entry => {
      entry.module_path_text == "Main" && entry.name == "main"
    }),
  )
}
```

`CompileResult` contains the linked Buslane program, the external binding model required by later lowering, exported entries, and all compiler diagnostics. Use the module-oriented APIs when you need reusable interface and object artifacts instead of a directly linked program.

### Enumerate explorer entries

`lanec/driver` is the platform-neutral boundary shared by native `lane explore` and browser-facing `lane_wasm`. It accepts the same explicit source set and performs no file-system or HTML work.

```mbt check
///|
test "enumerate exported compiler entries" {
  let root : @frontend.SourceInput = {
    source_id: "main.lane",
    text: (
      #|module Main
      #|
      #|pub fn main() -> Unit {
      #|  ()
      #|}
    ),
  }
  let report = @driver.list_entries(root, [])

  assert_true(report.diagnostics.is_empty())
  guard report.entries is [entry] else { fail("expected one exported entry") }
  assert_eq(entry.module_path_text, "Main")
  assert_eq(entry.name, "main")
  assert_eq(entry.type_text, "() -> Unit")
}
```

After selecting an entry, call `driver.explore` with an `ExploreRequest`. The resulting report contains the curated stages from Syntax AST through linked and effect-lowered Buslane, Executable Program, ANF, VM CFG, LoisVM bytecode, and generated WebAssembly. Exploration compiles but never executes the entry.

## Main packages

| Package | Responsibility |
| --- | --- |
| `Milky2018/lanec/compile` | High-level source checking, source-set compilation, and linking convenience APIs |
| `Milky2018/lanec/module/frontend` | Source inputs, parsing, import reachability, and module graph construction |
| `Milky2018/lanec/module/compile` | Module interfaces, module objects, fingerprints, and compiled module sets |
| `Milky2018/lanec/module/link` | Target-independent linking and the `LinkedProgram` model |
| `Milky2018/lanec/executable` | Whole-program elaboration, effect lowering, initializers, and execution roots |
| `Milky2018/lanec/loisvm_lowering` | ANF, VM CFG, ARC/slot finalization, and LoisVM bytecode construction |
| `Milky2018/lanec/driver` | Entry enumeration and platform-neutral IR exploration reports |
| `Milky2018/lanec/analysis` | In-memory semantic analysis used by tools and language servers |
| `Milky2018/lanec/format` | Trivia-preserving Lane source formatting |
| `Milky2018/lanec/diagnostic` | Compiler diagnostics and adaptation to the generic diagnostic module |

Lower-level packages such as `lexer`, `parser`, `resolve`, `typecheck`, `checked`, `effect_lowering/core`, `effect_lowering/cps`, `anf`, and `vmcfg` expose individual compiler representations and transformations. Prefer the high-level packages unless a tool specifically needs an intermediate representation.

## Artifacts

The compiler supports separate module and linked-program artifacts:

- Module interfaces expose imported and exported semantic contracts.
- Module objects contain checked and lowered module implementation data.
- Linked-program artifacts contain one selected current-format LoisVM bytecode image.
- Compilation fingerprints detect stale or mismatched interface and object inputs.

Lane artifacts are compiler contracts rather than long-term archival formats. Incompatible schema changes are rejected and artifacts are regenerated with the matching compiler.

## Execution

`lanec` stops at execution-image production. To execute generated bytecode directly, use `Milky2018/loisvm`; to use the standard Lane command workflow, use the `lane run`, `lane compile`, `lane link`, and `lane runobj` commands from the `Milky2018/lane` module. `run` and `runobj` use Wasmoon JIT by default and accept `--no-jit` for interpreter execution.

Executable Lane entries are zero-argument functions returning `Unit`. Their effect row may be empty or contain the built-in `Io` effect. Runtime imports are resolved by the LoisVM runtime registry after compilation.

## Development

From the repository root:

```bash
moon check modules/lanec --target all --deny-warn
moon test modules/lanec --target native --deny-warn
moon test modules/lanec/README.mbt.md --target native --deny-warn
moon info modules/lanec
moon fmt
```

Architecture vocabulary is maintained in `CONTEXT.md`. Normative design decisions, including the compiler driver, executable exploration, whole-program elaboration, and current-only LoisVM bytecode contract, are recorded under `docs/adr/`.
