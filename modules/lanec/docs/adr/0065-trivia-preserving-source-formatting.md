# Trivia-preserving source formatting

Lane source formatting will preserve line comments and comment-associated grouping gaps through a concrete syntax layer instead of adding comment fields to the semantic AST. The lexer owns token and gap-indexed trivia extraction, parser success returns a parsed source payload containing syntax plus concrete syntax, and the formatter extends the existing width-sensitive pretty-printer with a trivia view rather than using a second formatter or post-render comment merge.

This supersedes the comment-preservation boundary in ADR 0059. Ordinary whitespace and pure blank-line-only gaps are canonicalized from syntax structure; blank lines only affect trivia rendering when they separate comment groups from adjacent syntax. `//` comments are preserved as line-comment trivia without doc-comment semantics, EOF stays in the concrete token stream as a non-printing trivia anchor, and formatting remains full-file and parse-success-only.

## Considered Options

- Store comments directly on AST nodes: rejected because comments are concrete syntax trivia, not semantic syntax, and would pollute resolve, typecheck, desugar, and lowering.
- Reinsert comments after rendering: rejected because it is fragile around indentation, width-sensitive breaks, trailing comments, and blank-line grouping.
- Store leading/trailing trivia arrays directly on tokens: rejected because token gaps are stable facts while leading/trailing/detached classification is formatter policy.

## Consequences

The parser domain result is an enum with parsed and failed states. A successful parsed source carries both the syntax AST and concrete syntax sidecars; grammar failures may carry concrete syntax, but lexical failures do not. Every comment receives one consumable leading, trailing, boundary, delimiter, or EOF attachment. Delimiter matching uses the concrete token stream rather than broad AST ranges, and formatter failure reports an internal diagnostic instead of dropping an unconsumed comment. Formatter tests cover comment no-loss, normalized syntax equivalence, attachment consumption, pure blank-line canonicalization, and idempotence.
