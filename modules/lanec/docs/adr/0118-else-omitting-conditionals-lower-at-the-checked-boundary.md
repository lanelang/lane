# Else-omitting conditionals lower at the checked boundary

Lane represents an authored `if` without `else` as the ordinary source conditional with an absent else branch through Syntax, Resolved, and Desugared forms. Typechecking fixes its expected and result type to `Unit`, checks the authored then branch with a `Unit` expectation, and constructs the ordinary complete Checked `If` with a pure synthetic Unit else. The conditional's effect is therefore the union of its condition and authored then branch effects. Checked-to-Buslane lowering needs no sugar-specific branch.

This boundary preserves authored syntax for formatting and lets a dedicated semantic diagnostic point at a non-Unit then branch instead of blaming a synthetic else or reporting a generic type mismatch. When that branch mismatch already explains why the conditional cannot satisfy its surrounding expectation, the checker suppresses the derivative outer type mismatch. A well-formed Unit conditional used in a non-Unit context still receives the ordinary type mismatch on the whole conditional.

The authored conditional's location ends at the then block's closing brace. The synthetic Unit receives a zero-width location at that omitted else position and is excluded from source-facing indexes. A separate `IfWithoutElse` taxonomy and parser- or resolver-time expansion are rejected because they duplicate conditional structure or erase the provenance needed by formatting and diagnostics.

## Consequences

- Syntax, Resolved, and Desugared `If` change their `else_branch` field to an option; all consumers migrate directly, without a compatibility constructor or parallel legacy API. Checked `If` continues to require both branches.
- Formatter output preserves both an omitted else and an authored `else { () }`.
- With no else, trivia after the then block remains trailing trivia of the authored conditional; the formatter does not invent an absent-else boundary to own it.
- Syntax, Resolved, and Desugared debug output preserves omission; Checked and later IR output may expose the complete conditional with its synthetic Unit else.
- `else if` chains use ordinary recursive conditional typing; a chain ending without an else has type `Unit`.
- Existing block syntax remains unchanged: an empty then block is invalid and an explicit Unit result is written as `{ () }`.
- The parser's mandatory-final-else diagnostic is removed. No replacement terminator is introduced: ordinary layout ends an else-omitting conditional before the next item, while `else` remains a continuation that suppresses layout separation.
- A closed then block is a complete expression for tolerant parsing and LSP purposes and creates no required-else slot. A subsequently authored `else` still attaches through the ordinary grammar; this feature does not add dedicated keyword completion.
- The formal specification states both the Unit typing rule and the elaboration equation `if c { t }` to `if c { t } else { () }`.
- Delivery includes valid and invalid examples, parser, typechecker, formatter, and LSP regressions, and the corresponding formal language specification update.
