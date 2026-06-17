# Lane Workspace

This repository groups the core Lane implementation modules that should evolve
together during early compiler and tooling development.

## Language

**Lane Workspace**:
The MoonBit workspace that contains the compiler, Buslane, command line tool,
and language server modules.
_Avoid_: single package, release artifact

**Module Repository Layout**:
The repository layout where each MoonBit module lives under `modules/`.
_Avoid_: `lane-tools`, root package layout

**Compiler Module**:
The `modules/lanec` MoonBit module that owns parsing, resolution, type
checking, source elaboration, and lowering.
_Avoid_: CLI tool, language server

**Buslane Module**:
The `modules/buslane` MoonBit module that owns the typed core language,
verifier, interpreter, and pretty printer.
_Avoid_: source AST, compiler front end

**Lane Command Module**:
The `modules/lane` native command module.
_Avoid_: compiler module, language server module

**Lane LSP Module**:
The `modules/lane_lsp` native language-server module.
_Avoid_: VS Code extension, compiler front end

## Relationships

- `modules/lanec` depends on `modules/buslane`.
- `modules/lane` depends on `modules/lanec` and `modules/buslane`.
- `modules/lane_lsp` depends on `modules/lanec`.
- The workspace root owns cross-module development layout only; module-specific
  design notes stay inside each module directory.
