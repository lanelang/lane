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

**Single-File Run**:
Compilation and execution of one selected public entry from a Root Source and
its [Library Inputs](../../CONTEXT.md).
_Avoid_: language-level `main`, project build

**Run Command Host Adapter**:
The Lane Command implementation of the canonical
`lane_runtime_v1.run_command` capability. It borrows the generated module's
request frame, launches the requested executable directly, waits for
termination, and writes the fixed response. The adapter owns OS process calls;
the ABI package owns framing and Basic owns the source-level command model.
_Avoid_: shell execution, compiler builtin, process logic in Wasmoon

**Execution Profile**:
The execution-target-owned immutable policy admitting closed residual effects
at an Executable Entry. The Lane Command profile admits `Io`, `Panic`, and
closed External Effects; the compiler consumes this policy but never chooses it.
_Avoid_: source effect semantics, compiler default, built-in wildcard admission

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
