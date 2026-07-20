# Compiler driver and executable IR exploration

Lane exposes platform-neutral entry enumeration and selected-entry exploration through a `lanec/driver` package. Native `lane explore` and browser-facing `lane_wasm` use this driver. Native `lane run` remains a direct production consumer of the same module compilation, executable elaboration, and LoisVM lowering entrypoints. The driver accepts a complete in-memory source set and never performs host file-system discovery. Host adapters are responsible for collecting source inputs.

The driver supports two workflows. Artifact Entry Enumeration compiles the source set far enough to return the root module artifact's existing entries and diagnostics. It does not introduce a new entry model or classify entries on behalf of the artifact layer. Executable IR Exploration accepts one of those entries and performs a non-executing selected-entry build. Both workflows are request-based; implementations may cache internal results, but observable results must not depend on previous requests.

Normal compilation and exploration share orchestration at the stage-owning package boundaries. A read-only Compilation Observer may receive snapshots at stable semantic boundaries. The observer cannot change IR, pass selection, error recovery, or compilation results. Ordinary compilation installs no observer and therefore does not retain exploration text.

An Explore Snapshot contains a stable stage identifier, display label, compiler or backend domain, text format, human-readable text, and diagnostics. It contains rendered text rather than a typed compiler object. IR printers remain human-facing pretty printers and are not serialization formats. Before linking, snapshots display only the module that owns the selected entry; compilation still checks required dependencies and reports their diagnostics. Linking and every later stage display the complete whole-program IR consumed by the next transformation.

Explore Report Protocol version 1 contains compiler identity, root identity, the artifact-defined selected entry, overall status, diagnostics, and this fixed ordered stage sequence:

1. `syntax`: Syntax AST;
2. `resolved`: Resolved AST;
3. `checked`: Checked Source AST;
4. `buslane.module`: Buslane (Module Lowering);
5. `buslane.linked`: Buslane (Linking);
6. `buslane.effect-specialized`: Buslane (Reachable Effect Specialization);
7. `buslane.handlers-elaborated`: Buslane (Handler Elaboration);
8. `buslane.monadic`: Buslane (Monadic Transformation);
9. `buslane.selective-cps`: Buslane (Selective CPS);
10. `buslane.open-context-resolved`: Buslane (Open Context Resolution);
11. `buslane.monadic-lifted`: Buslane (Monadic Lift);
12. `buslane.core-optimized`: Buslane (Effect-Aware Core Optimization);
13. `buslane.effects-erased`: Buslane (Effect Erasure);
14. `executable`: Executable Program (Whole-Program Elaboration);
15. `anf`: ANF;
16. `vmcfg.initial`: VM CFG (Initial Lowering);
17. `loisvm.bytecode`: LoisVM Bytecode (ARC and Slot Finalization);
18. `wasm`: Wasm (LoisVM Backend Lowering).

Stage identifiers and order are protocol data distinct from display labels. Clients render unknown future stages as ordinary text tabs. The protocol does not promise a stable grammar for pretty-printed IR text.

Whole-Program Elaboration is the enclosing process that produces an Executable Program rather than a Buslane transformation stage. Exploration observes existing transformation outputs and does not split or duplicate a fused compiler pass solely to manufacture another display stage. The current VM CFG finalization therefore appears once through its resulting LoisVM bytecode, where inserted ARC operations and finalized slots are both visible.

The final backend snapshot comes from a cross-target `loisvm/wasm/compiler` package. This package owns pure LoisVM-bytecode-to-Wasm code generation. The native `loisvm/wasm` loader delegates code generation to it and retains Wasmoon loading, instantiation, and execution. Lane Wasm imports only the pure compiler package. Exploration code generation uses the checked signatures of reachable source `extern` bindings and never requires an executable host Runtime Binding. Closed compiler `builtin` intrinsics do not become host imports.

A failed compilation produces a Partial Explore Report containing every completed stage, the failing diagnostics, and unavailable status for later stages. Producing that report does not change failure into command success.

The native command is `lane explore <file>:<entry> -o <report.html>` with the same library-input semantics as `lane run`: `$LANE_HOME/basic` is loaded by default, explicit `--lib` and `--lib-dir` inputs are appended, and `--no-basic` disables the default directory. The output path is required. The command never executes the entry, writes the report through atomic replacement, does not emit the report to stdout, and does not automatically open a browser.

The native output is deterministic, self-contained offline HTML with one level of stage tabs, safely escaped IR source code, and inline styles and behavior. Each stage projects declarations, terms, functions, tables, or backend source directly; it does not render enclosing compiler objects, registries, entry or schema metadata, diagnostics, or image summaries. Those values remain available through the command outcome and compiler-owned Explore Report rather than being duplicated into the code viewer. It contains no CDN dependency or volatile timestamp. The HTML renderer uses MoonBit `StringBuilder`, `<+`, and multiline strings instead of repeated immutable string concatenation. Lane Wasm serializes the complete report model as versioned JSON; it does not reuse the native HTML renderer.

## Consequences

- Direct execution and both exploration hosts share the same stage-owning compilation entrypoints; the exploration hosts additionally share `lanec/driver` report assembly.
- Exploration cannot silently drift from production pass order or failure semantics.
- The public report protocol is stable independently of IR pretty-print syntax.
- The report contains eighteen curated semantic stages rather than every private pass.
- Pre-link presentation stays focused on the entry module while post-link presentation remains complete.
- Exploration does not require pass splitting solely for presentation.
- Pure Wasm generation becomes cross-target and independent of Wasmoon execution.
- Browser and native hosts present equivalent compiler information through different transports.
- Partial reports make intermediate failures inspectable without weakening command failure status.
