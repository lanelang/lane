# Lane LSP

The Lane LSP repository owns the native language-server executable used by
editor clients.

## Language

**Lane LSP Server**:
The native JSON-RPC language server that turns editor documents into compiler
analysis requests and returns LSP diagnostics.
_Avoid_: VS Code extension, compiler front end

**Compiler Analysis Boundary**:
The API boundary where the LSP server calls `lanec` without owning language
semantics.
_Avoid_: duplicate parser, duplicate typechecker

**Stdio Transport**:
The v1 process transport used by editor clients to communicate with the LSP
server.
_Avoid_: web extension transport, compiler CLI

## Relationships

- `lane_lsp` depends on `lanec` for language analysis.
- `lane_lsp` should not duplicate compiler diagnostics or semantic rules.
- `lane_vscode` starts and configures this server.
