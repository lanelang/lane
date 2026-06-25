# Lane2

Lane2 is a personal programming language implemented in MoonBit.

This repository is intentionally minimal. The first milestones are to define the
language model, then grow the lexer, parser, type checker, and runtime as those
decisions become concrete.

## Workspace Layout

Relative to the workspace root:

- `docs/`: project documentation, ADRs, and informal design notes.
- `spec/`: the formal language specification and language conformance fixtures.
- `lanec/`: the Lane compiler implementation.
- `modules/lane`: developer command-line tools built around the compiler,
  including the native `lane lsp` language server subcommand.

## Development

```bash
moon check
moon test
moon fmt
moon info
```
