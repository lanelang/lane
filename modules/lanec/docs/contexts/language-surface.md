# Lane Language Surface

This context names the source-level syntax and declaration concepts visible to
Lane programmers before semantic lowering.

## Language

**Top-Level Definition**:
A named definition that may introduce a type, function, or immutable value at the outermost program scope.
_Avoid_: statement, entrypoint, main function

**Immutable Value Definition**:
A binding that gives a name to a value without permitting reassignment.
_Avoid_: variable, mutable binding

**Offered Value Definition**:
A value definition that defines a named value and immediately adds it to the contextual offer environment.
_Avoid_: anonymous offer, open binding, standalone offer form, implicit library entry

**Recursive Definition Group**:
A set of top-level functions or types that may refer to one another regardless of textual order.
_Avoid_: forward declarations, hoisted statements

**Ordered Top-Level Value Scope**:
The rule that top-level immutable values may refer only to earlier available values.
_Avoid_: recursive top-level values, forward top-level value reference

**Strict Evaluation**:
The rule that an expression is evaluated when it is reached, and function arguments are evaluated before the function body runs.
_Avoid_: eager mode, non-lazy evaluation

**Keyword-Delimited Top Level**:
Top-level definitions are separated by their defining keywords rather than semicolons or MoonBit block separators.
_Avoid_: `///|` separator, semicolon-delimited top level

**MoonBit-Like Syntax**:
Lane surface syntax that follows MoonBit's expression-oriented style while excluding mutable bindings and assignment.
_Avoid_: custom syntax from scratch, MoonBit compatibility

**Type Annotation Spacing**:
The rule that a colon between a value or field name and a type is written with whitespace on both sides.
_Avoid_: compact type annotation, struct-literal field assignment

**Explicit Named Function Signature**:
A named function boundary that states every parameter type and the result type.
_Avoid_: inferred named function signature

**Generic Named Function**:
A named function whose explicit type parameter list follows `fn` and precedes the function name.
_Avoid_: name-attached type parameters

**Block Function Body**:
A function body written as a block expression rather than with an equals-sign expression body.
_Avoid_: equals body, expression-bodied function

**Arrow Return Type**:
A function result type written with `->` after the parameter list.
_Avoid_: colon return type

**Block Expression**:
A scoped expression containing local value or function bindings followed by a final value expression.
_Avoid_: statement block, local type scope

**Conditional Expression**:
An `if` expression with both then and else branches, where both branches have the same type.
_Avoid_: statement if, optional else

**Sequential Local Binding**:
A local binding that is visible only to later items in the same block.
_Avoid_: let-in expression, simultaneous local binding

**Sequential Local Function**:
A named local function that may call itself, is visible only to later items in the same block, and is not part of a forward-referenced group.
_Avoid_: local recursive group, local forward declaration

**Sequential Unit Expression**:
A block-local expression followed by an explicit or **Layout Semicolon**, required to have type `Unit`, and evaluated before the following local item or final expression.
_Avoid_: statement, unchecked result discard, general sequence operator

**Layout Semicolon**:
A zero-width `;` inserted between newline-delimited items before parsing when the previous token can end an item, the next token can start one, and the newline is outside parentheses and brackets. Newlines before operators, closing delimiters, continuation punctuation, `else`, `with`, or `final` do not insert a separator.
_Avoid_: parser recovery, newline AST node, unconditional line terminator

**Uncurried Function**:
A function that accepts its parameters as one call shape and is not automatically transformed into nested one-argument functions.
_Avoid_: curried function, automatic partial application

**First-Class Function Value**:
A function that can be stored, passed, returned, and called as a value.
_Avoid_: top-level-only function, method

**Struct Type**:
A nominal type defined by a fixed set of named fields.
_Avoid_: record type, anonymous record

**Enum Type**:
A nominal type defined by a closed set of named variants.
_Avoid_: sum type, tagged union

**Qualified Struct Literal**:
A struct value constructed with its struct type name followed by `::{ ... }`.
_Avoid_: anonymous record literal, unqualified struct literal

**Struct Field Punning**:
A struct literal shorthand where a field name alone means `field: field`.
_Avoid_: spread update, default field

**Struct Pattern Punning**:
A struct pattern shorthand where a field name alone binds that field to a variable with the same name.
_Avoid_: rest pattern, spread pattern

**Field Access**:
Reading a named field from a struct value with dot syntax.
_Avoid_: field update, copy update

**Selector Lowering**:
The compiler lowering that turns source field access into a generated Buslane function call.
_Avoid_: source-visible selector, Buslane field primitive

**Qualified Variant**:
An enum variant referred to through its enum type name using `Type::variant`.
_Avoid_: globally unique variant, dotted variant

**Unqualified Variant**:
An enum variant referred to by its variant name alone when that name resolves without ambiguity.
_Avoid_: mandatory qualified variant, inferred later variant

**Payloadless Variant Value**:
An enum variant without payload that is used as a value without call parentheses.
_Avoid_: zero-argument variant call

**Pipeline Expression**:
An expression `value |> call` that rewrites by passing `value` as the first argument to the call.
_Avoid_: core pipeline node, method call, placeholder pipeline

**Trailing Comma**:
An optional final comma in a comma-separated syntax list.
_Avoid_: comma-sensitive list ending

**Primitive Inhabitant**:
A value belonging to a primitive type, such as an integer literal, boolean literal, string literal, or `()`.
_Avoid_: enum variant, nominal constructor

## Relationships

- A Lane source file contains **Top-Level Definitions**, not an executable entrypoint.
- Top-level functions and types may form a **Recursive Definition Group**.
- Top-level immutable values follow **Ordered Top-Level Value Scope**.
- A top-level **Immutable Value Definition** must include an explicit type annotation.
- A function uses an **Explicit Named Function Signature**, **Arrow Return Type**, and **Block Function Body**.
- A **Block Expression** may contain **Sequential Local Bindings**, **Sequential Local Functions**, and **Sequential Unit Expressions** followed by exactly one final expression.
- Local value names may shadow earlier value names; ordinary value bindings in the same scope must have distinct names.
- Lane functions are **Uncurried Functions** and may still be **First-Class Function Values**.
- Enum variants in expressions may be **Qualified Variants** or unambiguous **Unqualified Variants**.
- **Field Access** is source syntax and lowers through **Selector Lowering** before Buslane.
- A **Pipeline Expression** is source syntax and does not survive into Buslane or ANF.

## Example dialogue

> **Dev:** "Can a top-level value refer to a later value?"
> **Domain expert:** "No. Top-level functions and types can be recursive, but top-level values obey **Ordered Top-Level Value Scope**."
