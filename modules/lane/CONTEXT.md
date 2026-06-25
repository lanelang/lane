# Lane Command

The Lane command repository owns the native user-facing command line tool.

## Language

**Lane Command**:
The unified command line surface for single-file checking, running, language
server startup, and future project workflows.
_Avoid_: compiler library, language server

**Single-File Run**:
The v1 command behavior that checks one root Lane module with explicitly
supplied library modules and prints a selected entry value.
_Avoid_: language-level main, project execution

**Library Input**:
The explicit `--lib` or `--lib-dir` source input that tells `lane` which
library modules are available to the root module.
_Avoid_: source import path, compiler-internal path

**Lane LSP Subcommand**:
The `lane lsp` command mode that runs the native JSON-RPC language server over
stdio.
_Avoid_: separate language-server executable, VS Code extension

## Relationships

- `lane` may use native filesystem and process facilities.
- `lane` should call `lanec` APIs or binaries rather than owning compiler
  semantics.
- `lane lsp` is a subcommand of the **Lane Command**, not a separate MoonBit
  module or executable.
- Runtime behavior visible through `lane run` must follow the language contract
  in `spec`.
