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

**Root Source**:
The source file named directly by a single-file `lane check` or `lane run`
command.
_Avoid_: project root, module identity

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
- A **Library Input** must not explicitly name the same source identity as the
  current **Root Source**.
- Library discovery through `--lib-dir` silently excludes the current
  **Root Source** when it finds the same source identity.
- Library sources with the same source identity are treated as one **Library
  Input** by the Lane Command.
- Repeating the same non-root **Library Input** is not a user error.
- The Lane Command determines source identity for CLI input filtering with
  symlink-resolved filesystem identity, not Lane module identity.
- The Lane Command forms the library source set before invoking compiler APIs:
  collect explicit and discovered library sources, exclude the **Root Source**,
  and deduplicate by source identity.
- The Lane Command preserves the first occurrence when normalizing the library
  source set.
- Runtime behavior visible through `lane run` must follow the language contract
  in `spec`.
