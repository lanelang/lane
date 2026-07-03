# Lane Pattern Matching

This context names pattern checking, exhaustiveness, and future pattern lowering
concepts.

## Language

**Core Pattern**:
A pattern form limited to wildcard, variable, literal, enum variant, or struct destructuring.
_Avoid_: guard pattern, or-pattern, as-pattern

**Checked Pattern**:
A source-level pattern whose constructors, binders, and covered type have been checked before Buslane lowering.
_Avoid_: parse pattern, decision tree

**Declaration-Order Struct Pattern**:
A checked struct pattern whose field patterns are ordered by the struct declaration.
_Avoid_: source-order struct pattern, partial record pattern

**Resolved Variant Pattern**:
A checked enum pattern that references a variant by variant symbol identity and stores payload patterns in declaration order.
_Avoid_: source variant spelling, raw tag pattern

**Qualified Variant Pattern**:
An enum variant pattern written with `Type::variant` so that bare identifiers remain variable bindings.
_Avoid_: capitalization-based pattern, leading-`::` shorthand

**Unqualified Variant Pattern**:
An enum variant pattern written as `variant(...)` when the matched enum type is already expected.
_Avoid_: bare variant identifier, leading-`::` shorthand

**Pattern Binder Uniqueness**:
The rule that a single pattern cannot bind the same value name more than once.
_Avoid_: implicit equality pattern, binder shadowing within a pattern

**Pattern Matrix**:
A semantic analysis model for match arms where rows are checked arms and columns are matched occurrences.
_Avoid_: ad hoc arm scan, runtime matcher

**Decision Tree**:
A lowered representation of pattern matching as explicit tests and branches.
_Avoid_: source pattern, checked pattern

**One-Level Core Match**:
A core match that branches only on the immediate literal, constructor, or default case for one scrutinee.
_Avoid_: nested source pattern, pattern matrix row, full decision tree

**Core Match Binder**:
The binder for the evaluated scrutinee that is available while checking or lowering one-level match alternatives.
_Avoid_: source pattern binder, duplicated scrutinee

**Core Alternative Constructor**:
The branch key of a one-level core match: default, primitive literal, or data constructor.
_Avoid_: nested source pattern

**Positional Alternative Binder**:
A core alternative binder whose meaning is determined by data-constructor payload position.
_Avoid_: source field binder, labeled payload binder

**Exhaustive Match**:
A match expression whose arms cover every possible value of the matched type.
_Avoid_: best-effort match, runtime match failure

**Useful Match Arm**:
A match arm that can be selected by at least one value not already covered by earlier arms.
_Avoid_: unreachable arm, redundant arm

**First-Match Arm Order**:
The rule that match arms are considered in source order and the first matching arm is selected.
_Avoid_: unordered pattern set, priority-free match

**Arrow Match Arm**:
A match arm written as `pattern => expression`.
_Avoid_: case arm, arrow statement

## Relationships

- Pattern matching in v1 uses **Checked Patterns**.
- **Checked Patterns** include primitive inhabitants as literal patterns.
- Enum variants in patterns use **Qualified Variant Pattern** or **Unqualified Variant Pattern** syntax.
- A payloadless **Qualified Variant Pattern** is written with an empty payload list.
- A payloadless **Unqualified Variant Pattern** is written with an empty payload list.
- Struct patterns support punning and explicit field renaming, but not rest or spread.
- Struct patterns must list all fields of the matched struct.
- Source struct and enum patterns lower to data-constructor alternatives before entering Buslane.
- A match expression must be an **Exhaustive Match**.
- Every match arm must be a **Useful Match Arm**.
- Match arm usefulness is checked over nested patterns, not only top-level patterns.
- **Pattern Binder Uniqueness** is required.
- Pattern binders may shadow outer value names and are scoped only over their match arm body.
- Match evaluation uses **First-Match Arm Order**.
- Buslane uses **One-Level Core Matches**, not nested source patterns.
- A Buslane match introduces a **Core Match Binder** for the evaluated scrutinee.
- **Core Alternative Constructors** are default, primitive literals, or Buslane data constructors.
- Data-constructor alternatives bind payloads with **Positional Alternative Binders**.
- Buslane matches are exhaustive; default alternatives are optional and must be last when present.
- Nested source patterns are compiled before entering Buslane while preserving **First-Match Arm Order**.
- **Decision Trees** are a lowered execution model, not the Buslane representation.

## Example dialogue

> **Dev:** "Can a bare identifier in a pattern mean an enum variant?"
> **Domain expert:** "No. Bare identifiers remain binders. Enum variants in patterns use `variant(...)` or `Type::variant(...)`."
