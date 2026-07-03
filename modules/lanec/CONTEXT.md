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

**Semantic Completion**:
A compiler-analysis completion result derived from Lane symbols, types, effects, modules, and source context.
_Avoid_: keyword snippet, editor-side text scan, LSP-only completion

**Completion Trigger**:
The user or editor event context supplied to a compiler completion query.
_Avoid_: completion kind, parser recovery mode, LSP item category

**Completion Entry**:
A semantic candidate returned by a compiler completion query before any editor protocol mapping.
_Avoid_: LSP completion item, text snippet, raw symbol

**Completion Query**:
A position-specific compiler analysis request that computes semantic completion candidates for one source location.
_Avoid_: full analysis index, precomputed completion cache, editor request handler

## Relationships

- `lanec` implements the language contract from `spec`.
- `lanec` consumes `buslane` as the semantic core target.
- `lane` and future tools should call compiler APIs instead of importing
  internal packages when possible.
- Platform services such as filesystem access belong in tools, not in the
  compiler core.
- **Semantic Completion** belongs to the **Compiler Analysis API**; LSP adapters
  only transport it as protocol-specific completion items.
- A **Completion Trigger** informs a **Semantic Completion** query but does not
  decide completion semantics outside the compiler analysis layer.
- A **Completion Entry** carries Lane semantic identity, display text, and edit
  range without depending on editor protocol fields.
- A **Completion Query** reuses compiler analysis inputs but does not require
  every ordinary **Compiler Analysis API** result to precompute completion
  scopes.
