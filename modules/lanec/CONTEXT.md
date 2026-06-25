# Lane Compiler

The Lane compiler repository owns parsing, resolution, type checking, source
elaboration, and lowering from Lane source into Buslane and ANF.

## Language

**Compiler Front End**:
The target-independent MoonBit implementation that accepts source text and
produces checked semantic artifacts.
_Avoid_: CLI tool, LSP server, standard library

**Source Elaboration**:
The compiler phase that resolves names, typechecks source constructs, supplies
contextual arguments, and produces checked source.
_Avoid_: pure parser, Buslane verifier

**Semantic Lowering**:
The boundary that translates checked source into Buslane.
_Avoid_: source desugaring, ANF normalization

**Compiler Analysis API**:
An in-memory API used by tools and LSP code without owning file IO or process
IO.
_Avoid_: native command implementation, editor extension

## Relationships

- `lanec` implements the language contract from `spec`.
- `lanec` consumes `buslane` as the semantic core target.
- `lane` and future tools should call compiler APIs instead of importing
  internal packages when possible.
- Platform services such as filesystem access belong in tools, not in the
  compiler core.
