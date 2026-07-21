# Lane IDE Tooling

This context names editor integration, language-server boundaries, and the
compiler-analysis APIs used by tools.

## Language

**IDE Tooling**:
Developer-facing editor and language-server integration built around Lane.
_Avoid_: compiler front end, build system

**Lane LSP Server**:
The native language server started by `lane lsp` for VS Code Desktop and other
LSP clients.
_Avoid_: compiler daemon, VS Code backend

**Lane VS Code Extension**:
The VS Code Desktop extension implemented under `lane_vscode` that starts,
configures, and communicates with the Lane LSP Server.
_Avoid_: compiler plugin, web extension

**LSP Executable Path**:
The VS Code setting that points the Lane VS Code Extension at a native Lane LSP
server command during v1 development.
_Avoid_: compiler path, project root

**VS Code Language Client**:
The TypeScript client layer in the Lane VS Code Extension, built with
`vscode-languageclient`, that manages VS Code's LSP client lifecycle and
document synchronization.
_Avoid_: custom JSON-RPC client, compiler API

**Compiler Analysis API**:
A target-independent `lanec` Semantic Workspace API that accepts identified
in-memory source inputs and publishes revisioned Semantic Snapshots without
performing file or process IO.
_Avoid_: LSP handler, filesystem service

**LSP Semantic Workspace Mirror**:
The Lane LSP Server state that mirrors all discovered Lane sources into one
compiler-owned Semantic Workspace. The first opened document seeds the mirror;
later opens, changes, closes, and disk restoration update individual sources.
_Avoid_: request-local analysis, completion cache, build-system compilation

**Document Snapshot**:
The current text of one open editor document as seen by the Lane LSP Server.
_Avoid_: source file on disk, parser cache

**Full Document Sync**:
The v1 LSP synchronization mode where every relevant document change replaces
the whole Document Snapshot text.
_Avoid_: incremental text edit, range patching

**Workspace Document Store**:
The Lane LSP Server state that maps open document URIs to Document Snapshots;
it overlays editor text on the broader LSP Semantic Workspace Mirror.
_Avoid_: compiler symbol table, project module graph

**Workspace Library Source**:
A `.lane` source used as an imported library input while checking the current
document. It may come from an open Document Snapshot or, if not open, from the
workspace filesystem.
_Avoid_: module object, build artifact, implicit library

**Workspace Source Seeding**:
The initial LSP filesystem scan that deduplicates open documents and on-disk
`.lane` files before replacing the compiler Semantic Workspace source set.
Subsequent editor changes do not repeat this scan.
_Avoid_: per-request source discovery, build graph, compiler-owned file IO

**Editor Diagnostic**:
A source-location diagnostic reported through LSP after converting compiler
diagnostics into editor ranges and severities.
_Avoid_: Buslane verifier error, runtime error report

**Structured Compiler Diagnostic**:
A target-independent `lanec` diagnostic carrying at least a message, optional
source span, and severity before any CLI or LSP rendering.
_Avoid_: formatted error string, LSP diagnostic

**Snapshot-Driven LSP**:
The language-server architecture where diagnostics, completion, hover,
go-to-definition, and inlay hints all query the same current Semantic Snapshot.
_Avoid_: feature-specific compiler run, mutable query result, editor-side symbol index

**LSP Protocol Layer**:
The Lane LSP Server layer that owns JSON-RPC framing, request and response
message conversion, and the minimal LSP wire types needed by v1.
_Avoid_: compiler analysis, editor feature handler

**JSON-RPC Framing Library**:
The third-party `gmlewis/jsonrpc2` package used by the LSP Protocol Layer for
JSON-RPC 2.0 messages and LSP-style `Content-Length` framing.
_Avoid_: LSP server framework, method dispatch

**Editor Intelligence**:
Editor features such as completion, hover, go-to-definition, inlay hints,
find-references, and document symbols built on Semantic Snapshot queries.
_Avoid_: diagnostics, compiler checking

**Editor Inlay Hint**:
An inline editor annotation produced by the Lane LSP Server from compiler
analysis without changing source text.
_Avoid_: formatter output, diagnostic, syntax highlight

**Type Inlay Hint**:
An Editor Inlay Hint that shows an inferred value or binder type when the source
does not already carry an explicit type annotation.
_Avoid_: hover type, required source annotation

**Parameter Name Hint**:
An Editor Inlay Hint that shows the callee parameter name at a call argument
with `name=` label text. Constructor call arguments use the same hint rule as
ordinary function call arguments.
_Avoid_: argument label syntax, named argument

**Implicit Argument Hint**:
An Editor Inlay Hint that shows an automatically supplied contextual argument
selected through Lane's `auto` parameter and `offer` value mechanism, using
`name=offer` label text.
_Avoid_: default argument, hidden import

**Desktop Native LSP**:
The v1 deployment model where the Lane VS Code Extension runs on VS Code
Desktop and launches `lane lsp`.
_Avoid_: VS Code Web extension, WASM language server

## Relationships

- **IDE Tooling** is part of the Tools Project, not the Compiler Project.
- The **Lane LSP Server** may use host IO, JSON-RPC, stdio, document URIs, and
  workspace state.
- The **Compiler Analysis API** must remain target-independent and must not own
  host file IO, process management, or LSP transport.
- The **Lane VS Code Extension** is responsible for locating `lane`, launching
  `lane lsp`, and restarting the **Lane LSP Server**.
- During v1 development, the **Lane VS Code Extension** primarily uses the
  configured **LSP Executable Path** and may fall back to repository-local
  development locations.
- The **Lane VS Code Extension** uses a **VS Code Language Client** rather than
  a custom JSON-RPC client.
- The first supported deployment target is **Desktop Native LSP**.
- The Lane LSP Server maintains one **LSP Semantic Workspace Mirror** and does
  not rebuild the module graph for individual requests.
- All implemented editor features use the same current compiler Semantic
  Snapshot through the **Snapshot-Driven LSP** boundary.
- The **LSP Protocol Layer** uses the **JSON-RPC Framing Library** for wire
  framing and keeps Lane-specific method dispatch in the Lane LSP Server.
- **Editor Intelligence** is a protocol projection of compiler Semantic
  Snapshot queries, not a second semantic implementation.
- **Editor Inlay Hints** include **Type Inlay Hints**, **Parameter Name Hints**,
  and **Implicit Argument Hints**.
- **Editor Inlay Hints** are derived from target-independent compiler-analysis
  entries; the Lane LSP Server only converts them into LSP responses.
- The Lane LSP Server produces all supported **Editor Inlay Hints** by default;
  editor clients and user settings decide whether to render them.
- Source-form operator calls do not produce **Parameter Name Hints**, but may
  still produce **Implicit Argument Hints** for auto arguments supplied through
  contextual resolution.
- **Document Snapshots** are passed to `lanec` as in-memory source text and
  override matching on-disk **Workspace Library Sources**.
- **Workspace Source Seeding** performs the filesystem scan once; later full
  document changes update one source in the compiler Semantic Workspace.
- v1 **Document Snapshots** are maintained through **Full Document Sync**.
- **Editor Diagnostics** are derived from **Structured Compiler Diagnostics**;
  they do not define separate language semantics.
- CLI output and LSP output render the same **Structured Compiler Diagnostics**
  through different presentation layers.
- **Command Reports** cover CLI-only failures such as bad arguments, host IO,
  artifact loading, runtime entry selection, and internal command invariants.
  They are not source diagnostics and must not invent source labels when no
  source span exists.

## Example dialogue

> **Dev:** "Should `lanec` read files for LSP diagnostics?"
> **Domain expert:** "No. The **Lane LSP Server** owns files and document
> snapshots; `lanec` exposes a **Compiler Analysis API** over in-memory input."

> **Dev:** "Does v1 need to support VS Code Web?"
> **Domain expert:** "No. v1 uses **Desktop Native LSP**."

> **Dev:** "May completion rebuild semantic state independently from hover?"
> **Domain expert:** "No. Both query the same current compiler Semantic
> Snapshot through the **Snapshot-Driven LSP** boundary."

> **Dev:** "Should the LSP derive build rules from the workspace?"
> **Domain expert:** "No. **Workspace Source Seeding** mirrors editor sources;
> it is not build-system compilation."

> **Dev:** "Should the LSP parse compiler diagnostic strings to recover ranges?"
> **Domain expert:** "No. `lanec` produces **Structured Compiler Diagnostics**."

> **Dev:** "Does the JSON-RPC dependency define Lane LSP behavior?"
> **Domain expert:** "No. The **JSON-RPC Framing Library** handles wire
> framing; Lane method handling belongs to the **Lane LSP Server**."

> **Dev:** "Should the VS Code extension implement its own JSON-RPC client?"
> **Domain expert:** "No. It uses the **VS Code Language Client**."

> **Dev:** "Does v1 need incremental text-document edits?"
> **Domain expert:** "No. v1 uses **Full Document Sync**."
