# Lane Command

The Lane command repository owns the native user-facing command line tool.

## Language

**Lane Command**:
The unified command line surface for single-file checking, running, language
server startup, and future project workflows.
_Avoid_: compiler library, language server

**Single-File Run**:
The command behavior that checks one root Lane module with explicitly supplied
library modules and executes a selected public `() -> Unit` or `() -> Unit ! Io`
entry through LoisVM.
_Avoid_: language-level main, project execution

**Executable Explore Command**:
The `lane explore <file>:<entry> -o <report.html>` command behavior that collects the same explicit library inputs as Single-File Run, requests compiler-owned Executable IR Exploration without executing the entry, and writes one HTML Explore Report. The output path is required.
_Avoid_: artifact inspection, stdout dump, automatic browser launch, alternate compilation pipeline

**Self-Contained Explore HTML**:
The deterministic offline report written by the Executable Explore Command with all styles, behavior, safely escaped stage documents, diagnostics, and report metadata embedded in one file.
_Avoid_: CDN dependency, external asset directory, runtime execution trace, volatile timestamp

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
- `lane explore` writes a complete or Partial Explore Report through an atomic
  output replacement; a partial report does not change a compilation failure
  into a successful command status.
- Self-Contained Explore HTML uses one level of stage tabs and contains no
  environment-dependent metadata beyond identified compilation inputs.
