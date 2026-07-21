# Trivia-preserving source formatting

Lane source formatting will preserve line comments and authored grouping through a concrete syntax layer instead of adding comment fields to semantic syntax. The lexer owns token and gap-indexed trivia extraction. The parser returns source syntax, concrete syntax, and the layout-separator gaps it actually consumed. The formatter builds one immutable concrete-layout index and extends the existing width-sensitive pretty-printer with that view rather than using a second formatter or a post-render comment merge.

This supersedes the comment-preservation boundary in ADR 0059. Ordinary whitespace and pure blank-line-only gaps are canonicalized from syntax structure; blank lines only affect trivia rendering when they separate comment groups from adjacent syntax. `//` comments are preserved as line-comment trivia without doc-comment semantics, EOF stays in the concrete token stream as a non-printing trivia anchor, and formatting remains full-file and parse-success-only. Explicit parentheses are retained as syntax-only grouping nodes and erased by resolution.

## Considered Options

- Store comments directly on AST nodes: rejected because comments are concrete syntax trivia, not semantic syntax, and would pollute resolve, typecheck, desugar, and lowering.
- Reinsert comments after rendering: rejected because it is fragile around indentation, width-sensitive breaks, trailing comments, and blank-line grouping.
- Store leading/trailing trivia arrays directly on tokens: rejected because token gaps are stable facts while leading/trailing/detached classification is formatter policy.
- Reconstruct parentheses from precedence: rejected because equivalent semantic trees do not preserve whether grouping was authored, and comments may belong to the grouping boundary.
- Classify comments with a global token-category allow/deny list: rejected because ownership belongs to grammar separators and syntax boundaries, not to punctuation heuristics.

## Consequences

The parser domain result is an enum with parsed and failed states. A successful parsed source carries the source AST, concrete syntax sidecars, and a gap index for inserted layout separators; grammar failures may carry concrete syntax, but lexical failures do not. The formatter builds ordered comment and anchor indexes once. Grammar-aware comma, item, top-level, and struct-field separators claim their own comments, while syntax nodes claim leading, trailing, operator, delimiter, and EOF comments. Each formatting session verifies that every comment was consumed exactly once and reports an internal diagnostic instead of dropping an unconsumed comment. Formatter tests cover comment no-loss, normalized semantic equivalence, authored grouping, attachment consumption, pure blank-line canonicalization, and idempotence.
