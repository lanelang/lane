# Lane Compiler

The Lane compiler repository owns parsing, resolution, type checking, source
elaboration, and lowering from Lane source into Buslane and ANF.

## Language

**Compiler Front End**:
The target-independent MoonBit implementation that accepts source text and
produces checked semantic artifacts.
_Avoid_: CLI tool, LSP server, Basic library

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

**Compiler Diagnostic Adapter**:
A compiler-owned translation from Lane compiler diagnostics into generic diagnostic infrastructure.
_Avoid_: terminal renderer, LSP diagnostic, command report

**Source-Aware Diagnostic Rendering**:
Diagnostic presentation that combines a compiler diagnostic with its source text before rendering source locations and guidance.
_Avoid_: compact diagnostic pretty print, debug diagnostic output, command report

**Width-Sensitive Formatting**:
Formatter output that uses syntax-aware pretty-printing breakpoints to prefer lines within a configured width while allowing indivisible source atoms to exceed it.
_Avoid_: hard line wrapping, post-render text wrapping, token splitting

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

**Unused Local Value Binding**:
A value binder introduced inside an executable expression body that has no resolved `ValueSymbolId` reference within its lexical scope after source elaboration.
_Avoid_: unused private declaration, unused type parameter, unused import, unreachable code

**Checked Value-Use Analysis**:
A source-elaboration follow-up analysis over checked AST that records local value binders and resolved `ValueSymbolId` references with their definition-body origin.
_Avoid_: type scope, lexical scope tree, dead-code elimination, textual name scan

**Intentionally Ignored Local Binding**:
A named local value binder whose source name starts with `_`; unused-local-value warnings do not fire for these binders.
_Avoid_: wildcard pattern, dead binding, generated temporary

## Relationships

- `lanec` implements the language contract from `spec`.
- `lanec` consumes `buslane` as the semantic core target.
- `lane` and future tools should call compiler APIs instead of importing
  internal packages when possible.
- Platform services such as filesystem access belong in tools, not in the
  compiler core.
- A **Compiler Diagnostic Adapter** may depend on **Diagnostic Infrastructure**
  but must not own terminal, JSON-RPC, or editor presentation.
- **Source-Aware Diagnostic Rendering** is the only user-facing presentation
  path for compiler and formatter source diagnostics.
- **Width-Sensitive Formatting** belongs to compiler syntax pretty-printing,
  not to command-line post-processing.
- **Width-Sensitive Formatting** applies first to syntax-owned list and head
  structures; it does not split source atoms such as identifiers, module paths,
  comments, or string literals.
- **Semantic Completion** belongs to the **Compiler Analysis API**; LSP adapters
  only transport it as protocol-specific completion items.
- A **Completion Trigger** informs a **Semantic Completion** query but does not
  decide completion semantics outside the compiler analysis layer.
- A **Completion Entry** carries Lane semantic identity, display text, and edit
  range without depending on editor protocol fields.
- A **Completion Query** reuses compiler analysis inputs but does not require
  every ordinary **Compiler Analysis API** result to precompute completion
  scopes.
- An **Unused Local Value Binding** warning is a compiler semantic diagnostic,
  not a control-flow reachability analysis or an API export check.
- **Checked Value-Use Analysis** may be reused by future optimization work, but
  warning policy such as underscore suppression must stay outside the reusable
  use-collection core.
- **Checked Value-Use Analysis** is a symbol identity graph over resolved
  binders and references; reference origin identifies the local binder whose
  definition body contains the reference, when any, so self-recursive and
  mutually recursive local definitions can be distinguished from external uses.
  It should not grow a lexical scope tree unless a separate source-tooling
  problem explicitly requires one.
- An **Intentionally Ignored Local Binding** is still a normal resolved value
  binding when referenced; the leading `_` only suppresses unused-local-value
  warnings.
