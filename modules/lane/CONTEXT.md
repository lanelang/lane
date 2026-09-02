# Lane Command

The Lane Command context owns the native user-facing CLI and stdio language
server.

## Language

**Lane Command**:
The unified command surface for checking, running, exploring, and serving Lane
source.
_Avoid_: compiler library, language semantics

**Root Source**:
The source file named directly by a single-file command.
_Avoid_: project root, module identity

**Source Inspection**:
The stable JSON projection produced by `lane inspect` for one `.lane` file. It
contains the parser-owned module identity and ordered direct imports only; it
does not discover a repository or schedule a build graph.
_Avoid_: source parser in Basic.Build, compile-graph command, object-list protocol

**Single-File Run**:
Compilation and execution of one selected public entry from a Root Source and
its [Library Inputs](../../CONTEXT.md).
_Avoid_: language-level `main`, project build

**Run Command Host Adapter**:
The Lane Command implementation of the canonical
`lane_runtime_v1.run_command` capability. It borrows the generated module's
request frame, launches the requested executable directly, writes supplied
standard-input bytes, waits for termination without blocking the host thread,
and captures standard output and standard error behind a single-use output
handle. The adapter owns the async OS process call and captured output; Wasmoon
owns parked Wasm execution, the ABI package owns framing, and Basic owns the
source-level command model.
_Avoid_: shell execution, compiler builtin, process logic in Wasmoon

**Execution Profile**:
The execution-target-owned immutable policy admitting closed residual effects
at an Executable Export. The Lane Command profile admits `Io`, `Panic`, and
closed External Effects; the compiler consumes this policy but never chooses it.
It does not decide the physical WebAssembly function signature.
_Avoid_: source effect semantics, export ABI, compiler default, built-in wildcard admission

**Public Export Request**:
An explicit `Module.value:wasm_name` mapping supplied to `lane link`. The full
request list is the linked program's semantic root set; source visibility alone
does not create a WebAssembly export.
_Avoid_: implicit public export, selected executable entry

**Command Invocation ABI**:
The `() -> ()` Core WebAssembly signature currently accepted by `lane exec`.
This is a Lane Command capability, not a restriction on valid linked exports.
_Avoid_: WebAssembly Export ABI, source function type

**Executable Explore Command**:
The non-executing command that requests compiler-owned IR exploration for one
selected entry and writes an Explore Report as HTML.
_Avoid_: artifact disassembler, alternate compiler pipeline

**Self-Contained Explore HTML**:
A deterministic offline presentation of one Explore Report with all assets
embedded.
_Avoid_: runtime trace, compiler interchange format

**Lane LSP Session**:
A framed JSON-RPC session run over stdio through the public language-server
entrypoint.
_Avoid_: private handler call, editor-side compiler

**Server Termination**:
The explicit outcome distinguishing graceful shutdown and exit, premature exit,
and transport closure.
_Avoid_: unconditionally successful process status, discarded lifecycle state
